"""Individualisierung (docs/33-individualisierung.md): das Lernprofil aendert
Verhalten - Kartenstapel, FSRS-Intervalle, Planer, naechster Schritt."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

import pytest

from app.schemas import LernprofilIn
from app.services import lernprofil, srs
from app.services.lernprofil import NextStepInput, next_step
from app.services.planner import TopicInput, generate_plan

GUTACHTEN_OHNE_OBERSATZ = (
    "Da A und B am 3. Mai einen Kaufvertrag ueber das gebrauchte Fahrrad geschlossen haben, "
    "ist A zur Zahlung des Kaufpreises verpflichtet. Da der Preis von 300 Euro ausdruecklich "
    "vereinbart war und beide Parteien geschaeftsfaehig sind, schuldet A den Kaufpreis nach "
    "§ 433 Abs. 2 BGB. Da B das Fahrrad am Folgetag uebergeben und uebereignet hat, ist der "
    "Anspruch auch faellig, weil keine abweichende Vereinbarung ueber die Faelligkeit "
    "getroffen wurde. Da A die Zahlung trotz Mahnung verweigert hat, befindet er sich "
    "zudem im Verzug, weshalb B auch Verzugszinsen verlangen kann. Da schliesslich keine "
    "Einreden ersichtlich sind, insbesondere keine Verjaehrung eingetreten ist, muss A "
    "den vollen Betrag an B zahlen. Somit hat B gegen A einen durchsetzbaren Anspruch auf "
    "Zahlung von 300 Euro aus dem Kaufvertrag, und A ist zur Zahlung verpflichtet."
)


# --------------------------------------------------------------------------- #
# Reine Logik
# --------------------------------------------------------------------------- #


def test_sicherheitsniveau_verschiebt_die_zielretention():
    standard = lernprofil.retention_for(LernprofilIn(), "definition")
    sicher = lernprofil.retention_for(LernprofilIn(sicherheitsniveau="sicher"), "definition")
    kompakt = lernprofil.retention_for(LernprofilIn(sicherheitsniveau="kompakt"), "definition")
    assert standard == srs.DESIRED_RETENTION_BY_TYPE["definition"]
    assert kompakt < standard < sicher
    assert lernprofil.RETENTION_MIN <= kompakt and sicher <= lernprofil.RETENTION_MAX


def test_sicher_plant_kuerzere_intervalle_als_kompakt():
    state = srs.CardState(
        stability=30.0,
        difficulty=5.0,
        due=datetime(2026, 9, 1, tzinfo=UTC),
        last_review=datetime(2026, 8, 1, tzinfo=UTC),
        reps=3,
        state=srs.State.REVIEW,
    )
    now = datetime(2026, 9, 1, tzinfo=UTC)
    sicher = srs.review(
        state,
        3,
        now=now,
        desired_retention=lernprofil.retention_for(
            LernprofilIn(sicherheitsniveau="sicher"), "definition"
        ),
    )
    kompakt = srs.review(
        state,
        3,
        now=now,
        desired_retention=lernprofil.retention_for(
            LernprofilIn(sicherheitsniveau="kompakt"), "definition"
        ),
    )
    assert sicher.due < kompakt.due


def test_gewicht_fokus_schwerpunkt_und_pause():
    profil = LernprofilIn(
        schwerpunkte=["strafrecht"], themen_fokus=["sr-bt-betrug"], themen_pausiert=["zr-bgb-at"]
    )
    assert lernprofil.topic_weight(profil, "zr-bgb-at", "zivilrecht") == 0.0
    assert lernprofil.topic_weight(profil, "zr-at-anfechtung", "zivilrecht") == 1.0
    assert lernprofil.topic_weight(profil, "sr-notwehr-32", "strafrecht") == pytest.approx(1.25)
    assert lernprofil.topic_weight(profil, "sr-bt-betrug", "strafrecht") == pytest.approx(
        1.5 * 1.25
    )


def test_persona_aus_ziel_semester_und_examensdatum():
    class U:
        exam_date = None

    assert lernprofil.persona(LernprofilIn(), U()) == lernprofil.PERSONA_EINSTIEG
    assert lernprofil.persona(LernprofilIn(semester=5), U()) == lernprofil.PERSONA_AUFBAU
    assert lernprofil.persona(LernprofilIn(ziel="examen"), U()) == lernprofil.PERSONA_EXAMEN
    assert (
        lernprofil.persona(LernprofilIn(ziel="wiederholung"), U())
        == lernprofil.PERSONA_WIEDERHOLUNG
    )

    class M:
        exam_date = datetime(2027, 3, 1, tzinfo=UTC)

    assert lernprofil.persona(LernprofilIn(semester=1), M()) == lernprofil.PERSONA_EXAMEN


def test_ruhetage_validierung():
    with pytest.raises(ValueError):
        LernprofilIn(ruhetage=[7])
    with pytest.raises(ValueError):
        LernprofilIn(ruhetage=[0, 1, 2, 3, 4, 5, 6])
    assert LernprofilIn(ruhetage=[6, 6, 0]).ruhetage == [0, 6]


def _inp(**overrides) -> NextStepInput:
    base = dict(
        eingerichtet=True,
        persona=lernprofil.PERSONA_EINSTIEG,
        due_cards=0,
        decks=[
            {"slug": "zr-bgb-at", "title": "BGB AT", "semester": 1, "mastery": 0.4},
            {"slug": "sr-at-1", "title": "Strafrecht AT I", "semester": 1, "mastery": 0.1},
            {"slug": "zr-sachenrecht", "title": "Sachenrecht", "semester": 5, "mastery": 0.0},
            {
                "slug": "zr-examenskurs",
                "title": "Examenskurs ZR",
                "semester": 7,
                "mastery": 0.0,
                "examenskurs": True,
            },
        ],
        semester=2,
        schwachstellen=[],
        faelle_je_thema={"sr-bt-betrug": ("sr-fall-betrug", "Der Trickbetrug")},
        schwaechstes_thema=("sr-bt-betrug", "Betrug", 0.6),
        klausur_heute=False,
        klausur_vorschlag={"slug": "fall-x", "title": "Fall X", "begruendung": "schwach"},
    )
    base.update(overrides)
    return NextStepInput(**base)


def test_naechster_schritt_regelreihenfolge():
    assert next_step(_inp(eingerichtet=False))["action"]["type"] == "profil"
    assert next_step(_inp(due_cards=12))["kind"] == "wiederholung"
    klausur = next_step(_inp(klausur_heute=True, persona=lernprofil.PERSONA_EXAMEN))
    assert klausur["kind"] == "klausur" and klausur["action"]["mode"] == "klausur"
    # Einstieg: Deck mit der geringsten Reife innerhalb des Semesterstoffs, kein Examenskurs.
    einstieg = next_step(_inp())
    assert einstieg["action"] == {"type": "deck", "slug": "sr-at-1", "title": "Strafrecht AT I"}
    # Aufbau mit Schwachstelle: Fall zum Thema.
    aufbau = next_step(
        _inp(
            persona=lernprofil.PERSONA_AUFBAU,
            schwachstellen=[
                {"topic_slug": "sr-bt-betrug", "title": "Betrug", "verfehlte_pruefpunkte": 3}
            ],
        )
    )
    assert aufbau["kind"] == "fall" and aufbau["action"]["slug"] == "sr-fall-betrug"
    # Aufbau ohne Schwachstelle: gewusstes Thema anwenden.
    assert next_step(_inp(persona=lernprofil.PERSONA_AUFBAU))["kind"] == "fall"
    # Nichts mehr offen.
    frei = next_step(_inp(decks=[], schwaechstes_thema=None))
    assert frei["kind"] == "frei"


def test_technik_tipp_zum_haeufigsten_bekannten_fehler():
    tipp = lernprofil.technik_tipp(
        [{"code": "unbekannt", "anzahl": 9}, {"code": "urteilsstil", "anzahl": 4}]
    )
    assert tipp is not None and tipp["code"] == "urteilsstil" and tipp["anzahl"] == 4
    assert lernprofil.technik_tipp([]) is None


def test_planer_klausurtag_und_wochenklausur_aus_profil():
    themen = [TopicInput("a", "zivilrecht", "A", relevance=5), TopicInput("b", "strafrecht", "B")]
    start, exam = date(2026, 1, 5), date(2026, 7, 1)
    mittwoch = generate_plan(themen, start=start, exam_date=exam, klausur_weekday=2)
    assert mittwoch.klausur_count > 0
    assert all(d.day.weekday() == 2 for d in mittwoch.days if d.is_klausurtag)
    ohne = generate_plan(themen, start=start, exam_date=exam, klausuren=False)
    assert ohne.klausur_count == 0


def test_planer_gewichtet_fokus_themen_vor():
    themen = [
        TopicInput("a", "zivilrecht", "A", relevance=3),
        TopicInput("b", "zivilrecht", "B", relevance=3, weight=1.5),
    ]
    plan = generate_plan(themen, start=date(2026, 1, 5), exam_date=date(2026, 7, 1))
    assert plan.covered_topics[0] == "b"


# --------------------------------------------------------------------------- #
# API
# --------------------------------------------------------------------------- #


def test_lernprofil_default_und_put(auth_client):
    default = auth_client.get("/v1/me/lernprofil").json()
    assert default["eingerichtet"] is False
    assert default["neue_karten_pro_tag"] == 10
    assert default["persona"] == lernprofil.PERSONA_EINSTIEG

    response = auth_client.put(
        "/v1/me/lernprofil",
        json={
            "semester": 4,
            "ziel": "semesterklausur",
            "zielnote": 9,
            "schwerpunkte": ["strafrecht", "strafrecht"],
            "ruhetage": [6],
            "klausur_wochentag": 2,
            "themen_fokus": ["sr-bt-betrug"],
            "themen_pausiert": ["zr-bgb-at"],
            "eigene_decks": [
                {"slug": "mein-vermoegen", "title": "Vermoegen", "topic_slugs": ["sr-bt-betrug"]}
            ],
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["eingerichtet"] is True
    assert body["persona"] == lernprofil.PERSONA_AUFBAU
    assert body["schwerpunkte"] == ["strafrecht"]
    assert auth_client.get("/v1/me/lernprofil").json()["themen_fokus"] == ["sr-bt-betrug"]

    export = auth_client.get("/v1/account/export").json()
    assert export["account"]["lernprofil"]["semester"] == 4


def test_lernprofil_fachliche_validierung(auth_client):
    def put(**payload):
        return auth_client.put("/v1/me/lernprofil", json=payload)

    assert put(themen_fokus=["gibt-es-nicht"]).status_code == 422
    assert put(themen_fokus=["zr-bgb-at"], themen_pausiert=["zr-bgb-at"]).status_code == 422
    assert put(schwerpunkte=["handelsrecht"]).status_code == 422
    assert put(klausur_wochentag=7).status_code == 422
    assert (
        put(
            eigene_decks=[{"slug": "kein-prefix", "title": "x", "topic_slugs": ["zr-bgb-at"]}]
        ).status_code
        == 422
    )
    # Landesrecht eines fremden Bundeslands ist nicht sichtbar und daher kein gueltiger Fokus.
    assert put(themen_fokus=["by-polizei-ordnungsrecht"]).status_code == 422
    auth_client.patch("/v1/auth/me", json={"bundesland": "BY"})
    assert put(themen_fokus=["by-polizei-ordnungsrecht"]).status_code == 200


def _topics(cards: list[dict]) -> list[str]:
    return [c["topic_slug"] for c in cards]


def test_pause_fokus_und_neue_karten_pro_tag_wirken_im_stapel(auth_client):
    auth_client.put(
        "/v1/me/lernprofil",
        json={
            "themen_pausiert": ["zr-bgb-at"],
            "themen_fokus": ["sr-bt-betrug"],
            "neue_karten_pro_tag": 3,
        },
    )
    karten = auth_client.get("/v1/cards/due", params={"limit": 50}).json()
    assert len(karten) == 3, "neue_karten_pro_tag begrenzt neue Karten ohne new_limit-Parameter"
    assert set(_topics(karten)) == {"sr-bt-betrug"}, "Fokus-Thema kommt zuerst"

    alle = auth_client.get("/v1/cards/due", params={"limit": 200, "new_limit": 100}).json()
    assert "zr-bgb-at" not in _topics(alle)
    assert (
        auth_client.get("/v1/cards/due", params={"topic": "zr-bgb-at", "new_limit": 50}).json()
        == []
    )


def test_eigenes_deck_als_stapelfilter_und_im_cockpit(auth_client):
    auth_client.put(
        "/v1/me/lernprofil",
        json={
            "eigene_decks": [
                {
                    "slug": "mein-irrtum",
                    "title": "Irrtuemer",
                    "topic_slugs": ["zr-at-anfechtung", "sr-at-vorsatz-tatbestandsirrtum"],
                }
            ]
        },
    )
    karten = auth_client.get(
        "/v1/cards/due", params={"deck": "mein-irrtum", "limit": 200, "new_limit": 100}
    ).json()
    assert karten
    assert set(_topics(karten)) <= {"zr-at-anfechtung", "sr-at-vorsatz-tatbestandsirrtum"}
    assert auth_client.get("/v1/cards/due", params={"deck": "mein-nix"}).status_code == 404

    cockpit = auth_client.get("/v1/examen/cockpit").json()
    deck = cockpit["eigene_decks"][0]
    assert deck["slug"] == "mein-irrtum" and deck["eigenes"] is True
    assert deck["cards_total"] > 0 and len(deck["topics"]) == 2
    assert deck["cases"], "eigene Decks tragen die Faelle ihrer Themen"


def test_cockpit_traegt_lernprofil_persona_und_naechsten_schritt(auth_client):
    cockpit = auth_client.get("/v1/examen/cockpit").json()
    assert cockpit["lernprofil"]["eingerichtet"] is False
    assert cockpit["naechster_schritt"]["action"]["type"] == "profil"
    assert cockpit["semesterstoff"] is None
    assert cockpit["themen"], "Themenliste fuer die Auswahl im Profil"

    auth_client.patch("/v1/auth/me", json={"universitaet_slug": "uni-koeln"})
    auth_client.put(
        "/v1/me/lernprofil",
        json={"semester": 2, "ziel": "zwischenpruefung", "wochenklausur": False},
    )
    cockpit = auth_client.get("/v1/examen/cockpit").json()
    assert cockpit["lernprofil"]["persona"] == lernprofil.PERSONA_EINSTIEG
    assert cockpit["lernprofil"]["persona_label"]
    schritt = cockpit["naechster_schritt"]
    assert schritt["kind"] == "deck"
    assert schritt["action"]["slug"] in cockpit["semesterstoff"]["decks"]
    assert cockpit["semesterstoff"]["semester"] == 2
    assert cockpit["semesterstoff"]["cards_total"] > 0


def test_wochenklausur_und_klausurtag_im_cockpit_und_plan(auth_client):
    exam = (date.today() + timedelta(days=150)).isoformat()
    auth_client.patch("/v1/auth/me", json={"exam_date": exam})
    auth_client.put(
        "/v1/me/lernprofil",
        json={"ziel": "examen", "klausur_wochentag": 2, "ruhetage": [6], "wochenklausur": False},
    )
    cockpit = auth_client.get("/v1/examen/cockpit", params={"plan_days": 14}).json()
    assert cockpit["naechste_klausur"]["aktiv"] is False
    assert date.fromisoformat(cockpit["naechste_klausur"]["datum"]).weekday() == 2
    sonntage = [d for d in cockpit["plan"] if date.fromisoformat(d["date"]).weekday() == 6]
    assert sonntage and all(b["title"] == "Ruhetag" for d in sonntage for b in d["blocks"])
    assert not any(b["kind"] == "klausur" for d in cockpit["plan"] for b in d["blocks"])

    plan = auth_client.post("/v1/plan", json={"exam_date": exam}).json()
    assert plan["klausur_count"] == 0
    assert all(
        d["blocks"][0]["title"] == "Ruhetag"
        for d in plan["days"]
        if date.fromisoformat(d["date"]).weekday() == 6
    )


def test_pausiertes_thema_fehlt_im_plan_und_technik_tipp_nach_abgabe(auth_client):
    exam = (date.today() + timedelta(days=120)).isoformat()
    auth_client.put("/v1/me/lernprofil", json={"themen_pausiert": ["zr-bgb-at"]})
    plan = auth_client.post("/v1/plan", json={"exam_date": exam, "horizon_days": 30}).json()
    assert "zr-bgb-at" not in set(plan["covered_topics"]) | set(plan["uncovered_topics"])

    response = auth_client.post(
        "/v1/cases/zr-fall-sonderpreis/submit",
        json={"text": GUTACHTEN_OHNE_OBERSATZ, "mode": "uebung"},
    )
    assert response.status_code == 201, response.text
    cockpit = auth_client.get("/v1/examen/cockpit").json()
    tipp = cockpit["schwachstellen"]["technik_tipp"]
    assert tipp is not None and tipp["code"] in lernprofil.TECHNIK_TIPPS
    assert tipp["titel"] and tipp["tipp"]
