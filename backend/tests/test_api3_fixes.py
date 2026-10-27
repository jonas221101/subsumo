"""Welle-3-API-Befunde: Redaktionsfelder, Karten-Paging, Semester-Stufung,
null-Loeschen im Profil, Nutzertexte."""

from __future__ import annotations

from datetime import date, timedelta

from app.services import examen
from app.services.examen import TopicProgress
from app.services.planner import PHASE_GRUNDLAGEN, TopicInput, generate_plan


def _walk(obj):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield k
            yield from _walk(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from _walk(v)


def test_bundesland_und_uni_liefern_keine_redaktionsangaben(client):
    land = client.get("/v1/examen/bundeslaender/BY").json()
    uni = client.get("/v1/examen/universitaeten/lmu-muenchen").json()
    for body in (land, uni):
        assert "redaktion" not in set(_walk(body))
        text = str(body)
        assert "nicht gegen die aktuelle Fassung" not in text
        assert "pruefliste_redaktion" not in text
        assert "erzeugt_von" not in text
        assert body["hinweis_nutzer"].startswith("Angaben ohne Gewähr")
    assert land["pruefstatus"]
    liste = client.get("/v1/examen/bundeslaender").json()
    assert "redaktion" not in set(_walk(liste))


def test_content_endpunkte_liefern_keine_redaktionsbloecke(client):
    for pfad in ("topics", "cards?limit=50", "schemata", "cases"):
        assert "redaktion" not in set(_walk(client.get(f"/v1/content/{pfad}").json()))


def test_karten_paging_ueber_offset_und_hohes_limit(client):
    manifest = client.get("/v1/content/manifest").json()
    alle = client.get("/v1/content/cards", params={"limit": 10000}).json()
    assert len(alle) == manifest["cards"]
    seite1 = client.get("/v1/content/cards", params={"limit": 10, "offset": 0}).json()
    seite2 = client.get("/v1/content/cards", params={"limit": 10, "offset": 10}).json()
    assert [c["slug"] for c in seite1 + seite2] == [c["slug"] for c in alle[:20]]
    assert client.get("/v1/content/cards", params={"limit": 10001}).status_code == 422
    assert client.get("/v1/content/cards", params={"offset": -1}).status_code == 422


def test_patch_me_null_loescht_bundesland_und_examensdatum(auth_client):
    exam = (date.today() + timedelta(days=100)).isoformat()
    me = auth_client.patch("/v1/auth/me", json={"bundesland": "BY", "exam_date": exam}).json()
    assert me["bundesland"] == "BY"
    assert me["exam_date"] is not None

    # Fehlende Felder bleiben unveraendert.
    me = auth_client.patch("/v1/auth/me", json={"daily_minutes": 60}).json()
    assert me["bundesland"] == "BY"
    assert me["exam_date"] is not None

    me = auth_client.patch("/v1/auth/me", json={"bundesland": None}).json()
    assert me["bundesland"] is None
    assert me["exam_date"] is not None
    me = auth_client.patch("/v1/auth/me", json={"exam_date": None}).json()
    assert me["exam_date"] is None


def _prog(slug, area, relevance=5):
    return TopicProgress(slug, slug, area, relevance, None, cards_total=10)


def test_schwaechstes_thema_bevorzugt_semesterstoff():
    progress = {
        "or-baurecht": _prog("or-baurecht", "oeffentliches-recht"),
        "zr-bgb-at": _prog("zr-bgb-at", "zivilrecht"),
    }
    profil = None  # topic_weight ohne Profil -> neutral
    from types import SimpleNamespace

    profil = SimpleNamespace(
        schwerpunkte=[], themen_fokus=[], themen_pausiert=[], semester=1, ziel=None
    )
    stufen = {"or-baurecht": 6, "zr-bgb-at": 0}
    assert examen.schwaechstes_thema(progress, profil, stufen)[0] == "zr-bgb-at"
    # Ohne Stufung (Examen / hohes Semester): gleiche Prioritaet -> Zivilrecht zuerst, stabil.
    first = examen.schwaechstes_thema(progress, profil)
    assert first[0] == "zr-bgb-at"
    assert examen.schwaechstes_thema(dict(reversed(progress.items())), profil) == first


def test_plan_beginnt_mit_semesterstoff():
    themen = [
        TopicInput("or-baurecht", "oeffentliches-recht", "Baurecht", relevance=5, stufe=6),
        TopicInput("zr-bgb-at", "zivilrecht", "BGB AT", relevance=3, stufe=0),
    ]
    plan = generate_plan(
        themen, start=date(2026, 1, 5), exam_date=date(2026, 12, 1), daily_minutes=90
    )
    erster = plan.days[0]
    assert erster.phase == PHASE_GRUNDLAGEN
    assert erster.blocks[0].topic_slug == "zr-bgb-at"


def test_topic_stufen_je_semester(auth_client):
    from app.db import SessionLocal
    from app.models import User

    def stufen(semester):
        auth_client.put("/v1/me/lernprofil", json={"semester": semester, "ziel": "semesterklausur"})
        with SessionLocal() as db:
            user = db.query(User).one()
            return examen.topic_stufen(db, user)

    s1 = stufen(1)
    assert s1["zr-bgb-at"] == 0
    assert s1["or-baurecht-bauleitplanung"] > 0
    assert stufen(8) == {}
    assert stufen(5)["or-baurecht-bauleitplanung"] > 0


def test_cockpit_semester_1_empfiehlt_kein_bauleitplanung(auth_client):
    auth_client.put("/v1/me/lernprofil", json={"semester": 1, "ziel": "semesterklausur"})
    schritt = auth_client.get("/v1/examen/cockpit").json()["naechster_schritt"]
    assert "bauleitplanung" not in str(schritt).lower()


def test_fehlende_themen_ohne_interne_kuerzel(auth_client):
    decks = auth_client.get("/v1/examen/cockpit").json()["kurs_decks"]
    zeilen = [t for d in decks for t in d["fehlende_themen"]]
    assert zeilen
    assert not any("(P2)" in t or "(P3)" in t or "siehe Kurs" in t for t in zeilen)


def test_nutzertexte_ohne_ascii_umlaute(auth_client):
    cockpit = auth_client.get("/v1/examen/cockpit").json()
    text = str(cockpit["examensreife"]) + str(cockpit["naechster_schritt"])
    for falsch in ("Faelle", "Faellen", "Hoechste", "Prioritaet", "faellig"):
        assert falsch not in text


def test_platzhalter_fall_ist_nutzerfreundlich(client):
    fall = client.get("/v1/content/cases").json()
    titel = {c["slug"]: c["title"] for c in fall}
    assert titel["or-fall-landesmietendeckel-kompetenz"] == "Der Mietendeckel eines Landes"
    assert not any(" L" == t[-2:] for t in titel.values())


def test_landesrecht_faelle_und_schemata_nur_fuer_das_eigene_bundesland(auth_client):
    anon = {"Authorization": ""}

    def cases(headers=None):
        return auth_client.get("/v1/content/cases", headers=headers).json()

    def schemata(headers=None):
        return auth_client.get("/v1/content/schemata", headers=headers).json()

    # Ohne Bundesland und ohne Token: nur Bundesrecht.
    for liste in (cases(), cases(anon), schemata(), schemata(anon)):
        assert liste
        assert all(x["bundesland"] is None for x in liste)

    auth_client.patch("/v1/auth/me", json={"bundesland": "NW"})
    mit_nw = cases() + schemata()
    laender = {x["bundesland"] for x in mit_nw}
    assert laender <= {None, "NW"}
    assert "NW" in laender
    # Anonym bleibt Landesrecht verborgen.
    assert all(x["bundesland"] is None for x in cases(anon))

    auth_client.patch("/v1/auth/me", json={"bundesland": "BY"})
    laender = {x["bundesland"] for x in cases() + schemata()}
    assert "NW" not in laender

    # Detail liefert das Feld ebenfalls.
    fall = next(c for c in cases() if c["bundesland"] == "BY")
    assert auth_client.get(f"/v1/cases/{fall['slug']}").json()["bundesland"] == "BY"


def test_neue_karten_im_hauptstapel_folgen_dem_lernprofil(auth_client):
    from app.db import SessionLocal

    def neue(**profil):
        if profil:
            auth_client.put("/v1/me/lernprofil", json=profil)
        karten = auth_client.get("/v1/cards/due", params={"limit": 30, "new_limit": 30}).json()
        return [c["topic_slug"] for c in karten]

    with SessionLocal() as db:
        sem = examen.topic_semesters(db)

    # Ohne Profil: Semester-1-Stoff zuerst, Zivil vor Straf vor OeR.
    ohne = neue()
    assert ohne
    assert all(sem.get(t, 99) == min(sem.get(x, 99) for x in ohne) for t in ohne[:5])

    # 1. Semester, Schwerpunkt Zivilrecht: nur Stoff bis Semester 1 vorn, Zivilrecht zuerst.
    mit = neue(semester=1, ziel="semesterklausur", schwerpunkte=["zivilrecht"])
    assert all(sem.get(t, 99) <= 1 for t in mit[:5])
    assert mit[0].startswith("zr-")


def test_fallliste_liefert_fallfrage_gebiet_und_bundesland(client):
    liste = client.get("/v1/content/cases").json()
    assert liste
    for c in liste[:20]:
        assert c["question"]
        assert c["area"]
        assert "bundesland" in c
        assert "facts" not in c
