"""Fachrichtungen (docs/34): Content-Profile, Sichtbarkeit, Profilwechsel, Gates."""

from __future__ import annotations

import uuid
from pathlib import Path

import pytest
import yaml

from app.config import REPO_ROOT
from app.services import examen
from app.services.content import load_content
from app.services.evaluator import _gesamtquote
from app.services.gutachten import analyze, neutral_report
from app.services.redaktion.fach_gate import check_fach

CONTENT = REPO_ROOT / "content"
FACHRICHTUNGEN = {"jura", "elektrotechnik", "maschinenbau", "lehramt"}


# ---------------------------------------------------------------- Content-Loader


def test_alle_fachrichtungen_haben_profil_fachgebiete_und_inhalte():
    bundle = load_content(CONTENT)
    assert bundle.errors == []
    assert {f["slug"] for f in bundle.fachrichtungen} == FACHRICHTUNGEN
    for fach in bundle.fachrichtungen:
        areas = {a["slug"] for a in fach["areas"]}
        assert len(areas) == 3, fach["slug"]
        for area in areas:
            assert bundle.area_map[area] == fach["slug"]
            themen = [t for t in bundle.topics if t["area"] == area]
            assert themen, f"{fach['slug']}/{area} hat keine Themen"
            assert all(t["fachrichtung"] == fach["slug"] for t in themen)
        kurse = [k for k in bundle.kurse if k["fachrichtung"] == fach["slug"]]
        assert any(k["examenskurs"] for k in kurse), f"{fach['slug']} ohne Abschlusskurs"
        unis = [u for u in bundle.universitaeten if fach["slug"] in u["fachrichtungen"]]
        assert unis, f"{fach['slug']} an keiner Universitaet"


def test_jede_aufgabe_ausserhalb_jura_hat_loesungsschritte_und_formeln_einheiten():
    bundle = load_content(CONTENT)
    for case in bundle.cases:
        if bundle.fachrichtung_of_area(case["area"]) != "jura":
            assert case.get("steps"), case["slug"]
    for card in bundle.cards:
        if card.get("type") == "formel":
            assert card.get("einheiten"), card["slug"]
            assert "=" in card["back"] or "≈" in card["back"], card["slug"]


def _schreibe(tmp_path: Path, rel: str, data: dict) -> None:
    path = tmp_path / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(yaml.safe_dump(data, allow_unicode=True), encoding="utf-8")


def _fach(slug: str, areas: list[str], **methodik) -> dict:
    return {
        "fachrichtung": {
            "slug": slug,
            "name": slug.title(),
            "areas": [{"slug": a, "title": a} for a in areas],
            "begriffe": {"fall": "Aufgabe"},
            "kartentypen": {"definition": "Definition", "formel": "Formel"},
            "methodik": methodik,
            "quellen": ["Test"],
            "stand": "2026-10",
        }
    }


def _thema(slug: str, area: str, cards: list[dict]) -> dict:
    return {
        "topic": {"slug": slug, "area": area, "title": slug, "relevance": 3, "stand": "2026-10"},
        "cards": cards,
    }


def test_fachgebiet_darf_nur_einer_fachrichtung_gehoeren(tmp_path: Path):
    _schreibe(tmp_path, "fachrichtungen/a.yaml", _fach("a", ["x-eins"]))
    _schreibe(tmp_path, "fachrichtungen/b.yaml", _fach("b", ["x-eins"]))
    bundle = load_content(tmp_path)
    assert any("x-eins" in e and "gehoert schon" in e for e in bundle.errors), bundle.errors


def test_thema_mit_unbekanntem_fachgebiet_und_formel_ohne_einheiten(tmp_path: Path):
    _schreibe(tmp_path, "fachrichtungen/t.yaml", _fach("t", ["t-eins"], einheiten_gate=True))
    karte = {"slug": "k1", "type": "formel", "front": "U?", "back": "U = R I", "quellen": ["x"]}
    _schreibe(tmp_path, "t/ok.yaml", _thema("ok", "t-eins", [dict(karte, einheiten=["U in V"])]))
    _schreibe(tmp_path, "t/ohne.yaml", _thema("ohne", "t-eins", [dict(karte, slug="k2")]))
    _schreibe(tmp_path, "t/fremd.yaml", _thema("fremd", "gibt-es-nicht", []))
    bundle = load_content(tmp_path)
    fehler = "\n".join(bundle.errors)
    assert "t/ohne.yaml" in fehler and "einheiten" in fehler
    assert "gibt-es-nicht" in fehler
    assert [c["slug"] for c in bundle.cards] == ["k1"]
    assert all(t["fachrichtung"] == "t" for t in bundle.topics if t["slug"] != "fremd")


def test_universitaet_darf_nur_kurse_ihrer_fachrichtungen_fuehren(tmp_path: Path):
    _schreibe(tmp_path, "fachrichtungen/a.yaml", _fach("a", ["a-eins"]))
    _schreibe(tmp_path, "fachrichtungen/b.yaml", _fach("b", ["b-eins"]))
    _schreibe(tmp_path, "a/t.yaml", _thema("a-t", "a-eins", []))
    _schreibe(tmp_path, "b/t.yaml", _thema("b-t", "b-eins", []))
    for f in "ab":
        _schreibe(
            tmp_path,
            f"examen/kurse/{f}.yaml",
            {
                "kurs": {
                    "slug": f"{f}-kurs",
                    "title": f,
                    "area": f"{f}-eins",
                    "quellen": ["x"],
                    "stand": "2026-10",
                    "topic_slugs": [f"{f}-t"],
                }
            },
        )
    _schreibe(
        tmp_path,
        "examen/universitaeten/u.yaml",
        {
            "universitaet": {
                "slug": "u",
                "name": "U",
                "bundesland": "BY",
                "quellen": ["x"],
                "stand": "2026-10",
                "fachrichtungen": ["a", "unbekannt"],
                "kurse": [{"kurs": "a-kurs"}, {"kurs": "b-kurs"}],
            }
        },
    )
    bundle = load_content(tmp_path)
    fehler = "\n".join(bundle.errors)
    assert "unbekannt" in fehler
    assert "b-kurs" in fehler


# ---------------------------------------------------------------- Fach-Gate


def test_fach_gate_meldet_paragraphen_einheiten_und_fehlende_steps():
    draft = {
        "cards": [
            {
                "slug": "f1",
                "type": "formel",
                "back": "P = U I",
                "einheiten": ["P in W"],
                "norms": ["§ 433 BGB"],
            },
            {
                "slug": "f2",
                "type": "formel",
                "back": "irgendwas ohne Gleichung",
                "einheiten": ["Watt"],
            },
        ],
        "faelle": [{"slug": "a1", "expectation": {"pruefpunkte": [{"norms": ["§ 1 StGB"]}]}}],
    }
    fehler = check_fach(draft, einheiten_gate=True)
    text = "\n".join(fehler)
    assert "§ 433 BGB" in text
    assert "Watt" in text and "Gleichung" in text
    assert "steps" in text and "§ 1 StGB" in text
    # Lehramt: nur die Loesungsschritte, Paragraphen sind erlaubt.
    assert check_fach(draft, einheiten_gate=False) == [
        "faelle[0] (a1): Aufgabe ohne Loesungsschritte ('steps')"
    ]
    assert check_fach({"cards": [], "faelle": []}, einheiten_gate=True) == []


def test_neutraler_report_zaehlt_nur_den_inhalt():
    neutral = neutral_report("U = 12 V / 2 kOhm = 6 mA")
    assert neutral.neutral is True
    assert _gesamtquote(0.5, neutral) == pytest.approx(0.5)
    echt = analyze("A könnte gegen B einen Anspruch aus § 433 Abs. 2 BGB haben. " * 3)
    assert _gesamtquote(1.0, echt) < 1.0 or echt.score == 100


# ---------------------------------------------------------------- API


def _register(client, fachrichtung: str | None):
    body = {"email": f"{uuid.uuid4().hex[:8]}@uni-beispiel.de", "password": "examen2029!"}
    if fachrichtung is not None:
        body["fachrichtung"] = fachrichtung
    return client.post("/v1/auth/register", json=body)


def test_public_config_listet_fachrichtungen_mit_begriffen(client):
    cfg = client.get("/v1/public/config").json()
    slugs = {f["slug"] for f in cfg["fachrichtungen"]}
    assert slugs == FACHRICHTUNGEN
    et = next(f for f in cfg["fachrichtungen"] if f["slug"] == "elektrotechnik")
    assert et["kurzname"] == "ET" and et["begriffe"]["faelle"] == "Aufgaben"


def test_registrierung_mit_fachrichtung_und_unbekannte_wird_abgelehnt(client):
    assert _register(client, "astrologie").status_code == 422
    response = _register(client, "maschinenbau")
    assert response.status_code == 201, response.text
    client.headers["Authorization"] = f"Bearer {response.json()['access_token']}"
    assert client.get("/v1/auth/me").json()["fachrichtung"] == "maschinenbau"
    client.headers["Authorization"] = f"Bearer {_register(client, None).json()['access_token']}"
    assert client.get("/v1/auth/me").json()["fachrichtung"] == "jura"


def test_fachrichtungen_endpunkt_und_unis_je_fachrichtung(client):
    liste = client.get("/v1/examen/fachrichtungen").json()
    assert {f["slug"] for f in liste} == FACHRICHTUNGEN
    assert all("methodik" in f and "areas" in f for f in liste)
    et_unis = client.get(
        "/v1/examen/universitaeten", params={"fachrichtung": "elektrotechnik"}
    ).json()
    assert {"tu-muenchen", "uni-hannover", "kit-karlsruhe"} <= {u["slug"] for u in et_unis}
    assert all("elektrotechnik" in u["fachrichtungen"] for u in et_unis)
    jura_unis = client.get("/v1/examen/universitaeten", params={"fachrichtung": "jura"}).json()
    assert "tu-muenchen" not in {u["slug"] for u in jura_unis}
    kurse = client.get("/v1/examen/kurse", params={"fachrichtung": "lehramt"}).json()
    assert {k["slug"] for k in kurse} == {
        "la-biwi-1",
        "la-didaktik",
        "la-schulrecht",
        "la-examenskurs",
    }


def test_katalog_endpunkte_filtern_nach_fachrichtung(client):
    def slugs(pfad: str, **params) -> set[str]:
        return {e["slug"] for e in client.get(pfad, params=params).json()}

    alle = slugs("/v1/content/topics")
    assert {"sr-bt-betrug", "et-get-ohm-kirchhoff"} <= alle
    et = slugs("/v1/content/topics", fachrichtung="elektrotechnik")
    assert "et-get-ohm-kirchhoff" in et and "sr-bt-betrug" not in et
    faelle = slugs("/v1/content/cases", fachrichtung="maschinenbau")
    assert (
        "mb-tm-aufgabe-balken-einzelkraft" in faelle and "sr-fall-gebrauchter-laptop" not in faelle
    )
    karten = slugs("/v1/content/cards", fachrichtung="lehramt", limit=2000)
    assert "la-bw-kounin" in karten and "sr-betrug-grundtatbestand" not in karten
    schemata = slugs("/v1/content/schemata", fachrichtung="lehramt")
    assert (
        "la-srp-schema-aufsichtspflichtverletzung" in schemata and "sr-schema-263" not in schemata
    )


def test_sichtbarkeit_folgt_der_fachrichtung(auth_client):
    me = auth_client.patch("/v1/auth/me", json={"fachrichtung": "elektrotechnik"}).json()
    assert me["fachrichtung"] == "elektrotechnik"
    due = auth_client.get("/v1/cards/due").json()
    assert due and all(c["topic_slug"].startswith("et-") for c in due)
    # Zurueck zu Jura: die ET-Karten verschwinden wieder aus der Faelligkeitsliste.
    auth_client.patch("/v1/auth/me", json={"fachrichtung": "jura"})
    antwort = auth_client.get("/v1/cards/due")
    assert antwort.status_code == 200, antwort.text
    due = antwort.json()
    assert due and not any(c["topic_slug"].startswith("et-") for c in due)


def test_fachrichtungswechsel_setzt_uni_und_schwerpunkte_zurueck(auth_client):
    assert auth_client.patch("/v1/auth/me", json={"fachrichtung": "nope"}).status_code == 422
    auth_client.patch("/v1/auth/me", json={"universitaet_slug": "uni-koeln"})
    profil = auth_client.get("/v1/me/lernprofil").json()
    profil["schwerpunkte"] = ["strafrecht"]
    assert auth_client.put("/v1/me/lernprofil", json=profil).status_code == 200
    me = auth_client.patch("/v1/auth/me", json={"fachrichtung": "maschinenbau"}).json()
    assert me["fachrichtung"] == "maschinenbau"
    assert me["universitaet_slug"] in (None, "")  # Koeln bietet keinen Maschinenbau an
    assert auth_client.get("/v1/me/lernprofil").json()["schwerpunkte"] == []
    # Schwerpunkte muessen zu den Fachgebieten der Fachrichtung passen.
    profil = auth_client.get("/v1/me/lernprofil").json()
    profil["schwerpunkte"] = ["strafrecht"]
    assert auth_client.put("/v1/me/lernprofil", json=profil).status_code == 422
    profil["schwerpunkte"] = ["mb-mechanik"]
    assert auth_client.put("/v1/me/lernprofil", json=profil).status_code == 200
    # Uni, die die Fachrichtung nicht anbietet, wird abgelehnt.
    assert (
        auth_client.patch("/v1/auth/me", json={"universitaet_slug": "uni-koeln"}).status_code == 422
    )
    assert (
        auth_client.patch("/v1/auth/me", json={"universitaet_slug": "tu-muenchen"}).status_code
        == 200
    )


def test_cockpit_kennt_fachrichtung_und_eigene_fachgebiete(auth_client):
    auth_client.patch(
        "/v1/auth/me", json={"fachrichtung": "elektrotechnik", "universitaet_slug": "rwth-aachen"}
    )
    cockpit = auth_client.get("/v1/examen/cockpit").json()
    fach = cockpit["fachrichtung"]
    assert fach["slug"] == "elektrotechnik" and fach["begriffe"]["fall"] == "Aufgabe"
    assert fach["methodik"]["bundesland_profile"] is False
    areas = {a["slug"] for a in fach["areas"]}
    assert areas == {"et-grundlagen", "et-elektronik", "et-signale-systeme"}
    assert set(cockpit["examensreife"]["by_area"]) == areas
    assert cockpit["bundesland"] is None and cockpit["landesrecht_deck"]["cards_total"] == 0
    assert all(t["area"] in areas for t in cockpit["themen"]) and cockpit["themen"]
    kurse = {k["slug"] for k in cockpit["kurs_decks"]}
    assert "et-get-1" in kurse and "mb-tm-1" not in kurse and "zr-bgb-at" not in kurse


def test_gutachten_analyse_ist_fuer_technische_faecher_neutral(auth_client):
    text = "Der Strom betraegt I = 12 V / 2000 Ohm = 6 mA, die Spannung U2 = 6 V und P2 = 36 mW."
    jura = auth_client.post("/v1/gutachten/analyze", json={"text": text}).json()
    assert jura["neutral"] is False and jura["score"] < 100
    auth_client.patch("/v1/auth/me", json={"fachrichtung": "elektrotechnik"})
    et = auth_client.post("/v1/gutachten/analyze", json={"text": text}).json()
    assert et["neutral"] is True and et["findings"] == [] and et["score"] == 100
    ergebnis = auth_client.post(
        "/v1/cases/et-get-aufgabe-spannungsteiler/submit", json={"text": text}
    ).json()
    assert ergebnis["structure"]["neutral"] is True
    getroffen = {p["id"] for p in ergebnis["evaluation"]["checkpoints"] if p["hit"]}
    assert {"p2", "p3", "p4"} <= getroffen
    # Ohne Gutachtenstil zaehlt nur der Inhalt (kein Strukturabzug trotz Score 0).
    ev = ergebnis["evaluation"]
    assert ev["content_ratio"] > 0.8 and ev["points"] > 9


def test_user_fachrichtung_und_profilfallback(client):
    from app.models import User

    assert examen.user_fachrichtung(User(email="x", password_hash="y")) == "jura"
    assert examen.user_fachrichtung(User(email="x", password_hash="y", fachrichtung="")) == "jura"
