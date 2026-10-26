"""Examensvorbereitung (docs/32-examensvorbereitung.md): Bundesland-Profile,
Universitaeten, Kurs-Decks, Landesrecht-Sichtbarkeit und Cockpit."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace

import pytest

from app.config import REPO_ROOT
from app.services import examen
from app.services.content import BUNDESLAND_CODES, load_content
from app.services.planner import PHASE_ENDSPURT, PHASE_GRUNDLAGEN

GUTACHTEN = (
    "A koennte gegen B einen Anspruch auf Zahlung des Kaufpreises aus § 433 Abs. 2 BGB "
    "haben. Dazu muesste ein wirksamer Kaufvertrag vorliegen. Ein Kaufvertrag kommt durch "
    "Angebot und Annahme zustande, §§ 145 ff. BGB. Hier hat A dem B die Sache zum Preis "
    "angeboten und B hat angenommen. Somit liegt ein Kaufvertrag vor. Der Anspruch ist "
    "entstanden. Folglich hat A gegen B einen Anspruch aus § 433 Abs. 2 BGB."
)


# --------------------------------------------------------------------------- #
# Content
# --------------------------------------------------------------------------- #


def test_alle_16_bundeslaender_haben_ein_profil_und_zwei_landesrecht_themen():
    bundle = load_content(REPO_ROOT / "content")
    assert bundle.ok, bundle.errors
    assert {b["code"] for b in bundle.bundeslaender} == BUNDESLAND_CODES
    landesrecht = {t["slug"] for t in bundle.topics if t.get("bundesland")}
    for code in BUNDESLAND_CODES:
        assert f"{code.lower()}-polizei-ordnungsrecht" in landesrecht
        assert f"{code.lower()}-landesrecht-allgemein" in landesrecht
    assert len(bundle.universitaeten) >= 40
    assert len(bundle.kurse) >= 15
    # Jede Universitaet hat einen Kursplan mit Examenskursen.
    examenskurse = {k["slug"] for k in bundle.kurse if k.get("examenskurs")}
    for uni in bundle.universitaeten:
        kurse = {e["kurs"] for e in uni["kurse"]}
        assert examenskurse <= kurse, uni["slug"]


def test_klausurverteilung_muss_zur_anzahl_passen(tmp_path: Path):
    (tmp_path / "x.yaml").write_text(
        """
bundesland:
  code: BY
  name: Bayern
  stand: "2026-09"
  quellen: ["JAPO"]
  klausuren:
    anzahl: 6
    verteilung: {zivilrecht: 3, strafrecht: 1, oeffentliches-recht: 1}
""",
        encoding="utf-8",
    )
    bundle = load_content(tmp_path)
    assert any("ergibt nicht klausuren.anzahl" in e for e in bundle.errors)


def test_unbekanntes_bundesland_an_thema_kurs_und_universitaet_ist_ein_fehler(tmp_path: Path):
    (tmp_path / "t.yaml").write_text(
        """
topic:
  slug: xx-thema
  area: oeffentliches-recht
  title: Test
  bundesland: XX
  stand: "2026-09"
""",
        encoding="utf-8",
    )
    (tmp_path / "u.yaml").write_text(
        """
universitaet:
  slug: uni-test
  name: Testuni
  bundesland: BY
  stand: "2026-09"
  quellen: ["Test"]
  kurse:
    - kurs: gibt-es-nicht
""",
        encoding="utf-8",
    )
    (tmp_path / "k.yaml").write_text(
        """
kurs:
  slug: kurs-test
  title: Kurs
  area: zivilrecht
  stand: "2026-09"
  quellen: ["Test"]
  topic_slugs: [unbekanntes-thema]
""",
        encoding="utf-8",
    )
    bundle = load_content(tmp_path)
    fehler = "\n".join(bundle.errors)
    assert "unbekanntes Bundesland 'XX'" in fehler
    assert "kein Profil fuer Bundesland 'BY'" in fehler
    assert "unbekannter Kurs 'gibt-es-nicht'" in fehler
    assert "unbekanntes Thema 'unbekanntes-thema'" in fehler


def test_leeres_deck_ist_kein_kurs(tmp_path: Path):
    (tmp_path / "k.yaml").write_text(
        """
kurs:
  slug: kurs-leer
  title: Kurs
  area: zivilrecht
  stand: "2026-09"
  quellen: ["Test"]
""",
        encoding="utf-8",
    )
    bundle = load_content(tmp_path)
    assert any("leeres Deck" in e for e in bundle.errors)


# --------------------------------------------------------------------------- #
# Reine Rechenlogik
# --------------------------------------------------------------------------- #


def test_gewichtung_ohne_bundesland_ist_gleichverteilt():
    weights = examen.area_weights(None)
    assert weights == pytest.approx({a: 1 / 3 for a in examen.AREAS})


def test_gewichtung_folgt_der_klausurverteilung():
    land = SimpleNamespace(
        data={
            "klausuren": {
                "verteilung": {"zivilrecht": 3, "strafrecht": 2, "oeffentliches-recht": 2}
            }
        }
    )
    weights = examen.area_weights(land)  # type: ignore[arg-type]
    assert weights["zivilrecht"] == pytest.approx(3 / 7)
    assert weights["strafrecht"] == pytest.approx(2 / 7)
    assert sum(weights.values()) == pytest.approx(1.0)


def test_phase_bleibt_bei_neuberechnung_stabil():
    """docs/13 Abschnitt 2.3: die Phase haengt am Vorbereitungsbeginn, nicht am Aufruf."""
    exam = datetime(2027, 3, 1, tzinfo=UTC)
    user = SimpleNamespace(exam_date=exam, created_at=datetime(2026, 1, 1, tzinfo=UTC))
    frueh = examen.phase_info(user, date(2026, 4, 1))  # type: ignore[arg-type]
    spaet = examen.phase_info(user, date(2027, 2, 15))  # type: ignore[arg-type]
    assert frueh["vorbereitungsbeginn"] == "2026-03-01"
    assert spaet["vorbereitungsbeginn"] == "2026-03-01"
    assert frueh["phase"] == PHASE_GRUNDLAGEN
    assert spaet["phase"] == PHASE_ENDSPURT
    assert spaet["tage_bis_examen"] == 14


def test_naechster_klausurtag_ist_ein_samstag():
    for offset in range(7):
        heute = date(2026, 9, 21) + timedelta(days=offset)  # Montag ... Sonntag
        tag = examen.next_klausurtag(heute)
        assert tag.weekday() == 5
        assert 1 <= (tag - heute).days <= 7


# --------------------------------------------------------------------------- #
# API
# --------------------------------------------------------------------------- #


def test_bundeslaender_liste_und_profil(client):
    liste = client.get("/v1/examen/bundeslaender").json()
    assert len(liste) == 16
    by = next(b for b in liste if b["code"] == "BY")
    assert by["klausuren"]["verteilung"] == {
        "zivilrecht": 3,
        "strafrecht": 1,
        "oeffentliches-recht": 2,
    }
    assert by["pruefstatus"] == "in-pruefung"

    profil = client.get("/v1/examen/bundeslaender/by").json()
    assert profil["gewichtung"]["strafrecht"] == pytest.approx(1 / 6)
    assert {t["slug"] for t in profil["landesrecht_themen"]} == {
        "by-polizei-ordnungsrecht",
        "by-landesrecht-allgemein",
    }
    assert profil["landesrecht"]["normenspiegel"]["polizei_generalklausel"].startswith("Art. 11")
    assert client.get("/v1/examen/bundeslaender/xx").status_code == 404


def test_universitaeten_nach_bundesland_und_kursplan(client):
    bayern = client.get("/v1/examen/universitaeten", params={"bundesland": "by"}).json()
    assert {u["slug"] for u in bayern} >= {"lmu-muenchen", "uni-passau", "uni-wuerzburg"}
    assert all(u["bundesland"] == "BY" for u in bayern)

    lmu = client.get("/v1/examen/universitaeten/lmu-muenchen").json()
    assert lmu["bundesland_name"] == "Bayern"
    semester = [k["semester"] for k in lmu["kurse"]]
    assert semester == sorted(semester)
    assert any(k["examenskurs"] for k in lmu["kurse"])
    assert client.get("/v1/examen/universitaeten/gibt-es-nicht").status_code == 404


def test_universitaet_setzt_bundesland_im_profil(auth_client):
    me = auth_client.patch("/v1/auth/me", json={"universitaet_slug": "uni-koeln"}).json()
    assert me["universitaet_slug"] == "uni-koeln"
    assert me["bundesland"] == "NW"

    assert auth_client.patch("/v1/auth/me", json={"bundesland": "XX"}).status_code == 422
    assert (
        auth_client.patch("/v1/auth/me", json={"universitaet_slug": "uni-nirgendwo"}).status_code
        == 422
    )

    # Leerstring loescht, None laesst unveraendert.
    me = auth_client.patch("/v1/auth/me", json={"universitaet_slug": ""}).json()
    assert me["universitaet_slug"] is None
    assert me["bundesland"] == "NW"


def _slugs(cards: list[dict]) -> set[str]:
    return {c["topic_slug"] for c in cards}


def test_landesrecht_ist_nur_im_eigenen_bundesland_sichtbar(auth_client):
    # Ohne Bundesland: kein Landesrecht, egal welches.
    ohne = auth_client.get("/v1/cards/due", params={"limit": 200, "new_limit": 100}).json()
    assert not any(s.endswith("-polizei-ordnungsrecht") for s in _slugs(ohne))

    auth_client.patch("/v1/auth/me", json={"bundesland": "BY"})
    mit = auth_client.get(
        "/v1/cards/due",
        params={"limit": 200, "new_limit": 100, "topic": "by-polizei-ordnungsrecht"},
    ).json()
    assert mit, "bayerisches Landesrecht muss fuer einen bayerischen Nutzer erscheinen"
    fremd = auth_client.get(
        "/v1/cards/due",
        params={"limit": 200, "new_limit": 100, "topic": "nw-polizei-ordnungsrecht"},
    ).json()
    assert fremd == []

    coverage = auth_client.get("/v1/progress/coverage").json()
    slugs = {t["slug"] for t in coverage["topics"]}
    assert "by-polizei-ordnungsrecht" in slugs
    assert "nw-polizei-ordnungsrecht" not in slugs


def test_deck_filter_in_cards_due(auth_client):
    auth_client.patch("/v1/auth/me", json={"bundesland": "NW"})
    deck = auth_client.get(
        "/v1/cards/due",
        params={"limit": 200, "new_limit": 100, "deck": "or-polizei-ordnungsrecht"},
    ).json()
    assert deck
    assert _slugs(deck) <= {
        "or-sicherheitsrecht-generalklausel-standardmassnahmen",
        "nw-polizei-ordnungsrecht",
    }
    assert "nw-polizei-ordnungsrecht" in _slugs(deck)
    assert auth_client.get("/v1/cards/due", params={"deck": "gibt-es-nicht"}).status_code == 404


def test_deck_ist_auf_das_bundesland_zugeschnitten(auth_client):
    ohne = auth_client.get("/v1/examen/kurse/or-polizei-ordnungsrecht/deck").json()
    assert {t["slug"] for t in ohne["topics"]} == {
        "or-sicherheitsrecht-generalklausel-standardmassnahmen"
    }
    assert ohne["landesrecht_fehlt"] == []
    assert ohne["cards_total"] > 0

    auth_client.patch("/v1/auth/me", json={"bundesland": "HE"})
    mit = auth_client.get("/v1/examen/kurse/or-polizei-ordnungsrecht/deck").json()
    assert "he-polizei-ordnungsrecht" in {t["slug"] for t in mit["topics"]}
    assert mit["cards_total"] > ohne["cards_total"]
    assert mit["cases"], "das Deck traegt die Faelle seiner Themen"
    assert auth_client.get("/v1/examen/kurse/nix/deck").status_code == 404


def test_cockpit_ohne_profil_ist_ehrlich_leer(auth_client):
    cockpit = auth_client.get("/v1/examen/cockpit").json()
    assert cockpit["profil"]["vollstaendig"] is False
    assert cockpit["phase"] is None
    assert cockpit["bundesland"] is None
    assert cockpit["plan"] == []
    reife = cockpit["examensreife"]
    assert reife["gesamt"] == 0.0
    assert reife["komponenten"]["landesrecht"]["value"] is None
    assert reife["komponenten"]["technik"]["value"] is None
    # Ohne Universitaet: der komplette Katalog als Decks.
    assert len(cockpit["kurs_decks"]) >= 15
    assert cockpit["landesrecht_deck"]["topics"] == []
    assert cockpit["naechste_klausur"]["vorschlag"] is not None


def test_cockpit_mit_profil_plan_und_gewichtung(auth_client):
    exam = (date.today() + timedelta(days=200)).isoformat()
    auth_client.patch(
        "/v1/auth/me",
        json={"universitaet_slug": "uni-koeln", "exam_date": exam, "daily_minutes": 120},
    )
    cockpit = auth_client.get("/v1/examen/cockpit", params={"plan_days": 5}).json()

    assert cockpit["profil"]["vollstaendig"] is True
    assert cockpit["profil"]["bundesland"]["code"] == "NW"
    assert cockpit["profil"]["universitaet"]["slug"] == "uni-koeln"
    assert cockpit["phase"]["tage_bis_examen"] == 200
    assert cockpit["phase"]["phase"] in {"grundlagen", "vertiefung", "endspurt"}

    by_area = cockpit["examensreife"]["by_area"]
    assert by_area["strafrecht"]["klausuren"] == 2
    assert by_area["strafrecht"]["gewicht"] == pytest.approx(2 / 7, abs=1e-3)
    assert sum(v["gewicht"] for v in by_area.values()) == pytest.approx(1.0, abs=1e-3)

    assert len(cockpit["plan"]) == 5
    assert cockpit["plan"][0]["blocks"]
    assert {t["slug"] for t in cockpit["landesrecht_deck"]["topics"]} == {
        "nw-polizei-ordnungsrecht",
        "nw-landesrecht-allgemein",
    }
    assert cockpit["checkliste"], "Checkliste des Landes wird mitgeliefert"
    assert any(item["jetzt_dran"] for item in cockpit["checkliste"])
    assert cockpit["bundesland"]["abschichtung"]["moeglich"] is True
    # Decks in Reihenfolge des Studienverlaufsplans der Universitaet.
    semester = [d["semester_default"] for d in cockpit["kurs_decks"]]
    assert semester == sorted(semester)


def test_examensreife_reagiert_auf_klausuren_und_schwachstellen(auth_client):
    auth_client.patch("/v1/auth/me", json={"bundesland": "BW"})
    response = auth_client.post(
        "/v1/cases/zr-fall-sonderpreis/submit",
        json={"text": GUTACHTEN, "mode": "klausur", "duration_s": 3600},
    )
    assert response.status_code == 201, response.text

    cockpit = auth_client.get("/v1/examen/cockpit").json()
    komponenten = cockpit["examensreife"]["komponenten"]
    assert komponenten["technik"]["value"] is not None
    assert komponenten["klausurpraxis"]["value"] == pytest.approx(1 / examen.KLAUSURPRAXIS_WOCHEN)
    assert "klausurpraxis" in cockpit["examensreife"]["formel"]
    assert cockpit["schwachstellen"]["abgaben"] == 1
    # Der gerade geschriebene Fall wird nicht erneut als Klausur vorgeschlagen.
    vorschlag = cockpit["naechste_klausur"]["vorschlag"]
    assert vorschlag is not None
    assert vorschlag["slug"] != "zr-fall-sonderpreis"


def test_lernplan_kennt_nur_sichtbare_themen(auth_client):
    exam = (date.today() + timedelta(days=120)).isoformat()
    plan = auth_client.post("/v1/plan", json={"exam_date": exam, "horizon_days": 30}).json()
    alle = set(plan["covered_topics"]) | set(plan["uncovered_topics"])
    assert not any(s.endswith("-landesrecht-allgemein") for s in alle)

    auth_client.patch("/v1/auth/me", json={"bundesland": "SH"})
    plan = auth_client.post("/v1/plan", json={"exam_date": exam, "horizon_days": 30}).json()
    alle = set(plan["covered_topics"]) | set(plan["uncovered_topics"])
    assert "sh-landesrecht-allgemein" in alle
    assert "by-landesrecht-allgemein" not in alle
