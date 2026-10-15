"""Regressionstests Lernlogik-API (Tester-Befunde Report 9): Zeitfenster,
Idempotenz pro Nutzer, Lernschritte, einheitliche Faelligkeits-Last, Klausurtermin."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, timedelta

from sqlalchemy import create_engine, inspect, text

from app.db_migrate import migrate
from app.models import Review, UserCard


def _review(slug: str, at: datetime, rating: int = 3, client_id: str | None = None, **extra):
    return {
        "client_id": client_id or uuid.uuid4().hex,
        "card_slug": slug,
        "rating": rating,
        "reviewed_at": at.isoformat(),
        **extra,
    }


def _post(client, *reviews):
    response = client.post("/v1/reviews/batch", json={"reviews": list(reviews)})
    assert response.status_code == 200, response.text
    return response.json()


def _first_card(client) -> str:
    return client.get("/v1/cards/due", params={"limit": 1}).json()[0]["slug"]


def _register(client) -> dict:
    email = f"{uuid.uuid4().hex[:10]}@uni-beispiel.de"
    r = client.post("/v1/auth/register", json={"email": email, "password": "examen2029!"})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# --- 1. reviewed_at ------------------------------------------------------- #


def test_reviewed_at_in_der_zukunft_wird_auf_jetzt_geklemmt(auth_client):
    slug = _first_card(auth_client)
    now = datetime.now(UTC)
    body = _post(auth_client, _review(slug, now + timedelta(days=3650), rating=3))
    assert body["applied"] == 1 and body["clamped"] == 1
    due = datetime.fromisoformat(body["results"][0]["due"])
    assert due < now + timedelta(days=30)  # nicht jahrelang unsichtbar


def test_reviewed_at_weit_in_der_vergangenheit_wird_auf_sieben_tage_geklemmt(auth_client):
    slug = _first_card(auth_client)
    now = datetime.now(UTC)
    body = _post(auth_client, _review(slug, datetime(1, 1, 1, tzinfo=UTC), rating=4))
    assert body["applied"] == 1 and body["clamped"] == 1
    due = datetime.fromisoformat(body["results"][0]["due"])
    assert due > now  # nicht "sofort faellig" durch Uhrzeit aus dem Jahr 1


def test_nachgesendete_bewertung_der_letzten_tage_bleibt_unveraendert(auth_client):
    slug = _first_card(auth_client)
    body = _post(auth_client, _review(slug, datetime.now(UTC) - timedelta(days=5)))
    assert body["applied"] == 1 and body["clamped"] == 0


def test_rueckdatierte_bewertung_dreht_neuere_nicht_zurueck(auth_client, client):
    slug = _first_card(auth_client)
    now = datetime.now(UTC)
    neu = _post(auth_client, _review(slug, now - timedelta(minutes=1), rating=4))
    alt = _post(auth_client, _review(slug, now - timedelta(days=2), rating=1))
    assert alt["applied"] == 1
    assert alt["results"][0]["due"] == neu["results"][0]["due"]
    assert alt["results"][0]["state"] == neu["results"][0]["state"] == "review"


def test_reihenfolge_im_batch_folgt_reviewed_at(auth_client):
    slug = _first_card(auth_client)
    now = datetime.now(UTC)
    spaet = _review(slug, now - timedelta(minutes=1), rating=3)
    frueh = _review(slug, now - timedelta(days=1), rating=1)
    body = _post(auth_client, spaet, frueh)  # unsortiert geliefert
    assert body["applied"] == 2
    assert body["results"][0]["state"] == "learning"  # Frueh zuerst: Nochmal
    assert body["results"][1]["state"] == "learning"  # dann Gut -> Schritt 2, nicht review


# --- 6. Validierung -------------------------------------------------------- #


def test_rating_ist_strikt(auth_client):
    slug = _first_card(auth_client)
    now = datetime.now(UTC)
    for bad in (True, "3", 3.5):
        r = auth_client.post(
            "/v1/reviews/batch", json={"reviews": [_review(slug, now, rating=bad)]}
        )
        assert r.status_code == 422, bad


def test_elapsed_ms_wird_begrenzt(auth_client, client):
    slug = _first_card(auth_client)
    now = datetime.now(UTC)
    _post(
        auth_client,
        _review(slug, now, client_id="negativ-0000001", elapsed_ms=-5),
    )
    other = _first_card(auth_client)
    assert other
    from app.db import SessionLocal

    with SessionLocal() as db:
        row = db.query(Review).filter_by(client_id="negativ-0000001").one()
        assert row.elapsed_ms == 0


def test_unbekanntes_thema_ist_404_wie_unbekanntes_deck(auth_client):
    assert auth_client.get("/v1/cards/due", params={"topic": "xyz"}).status_code == 404
    assert auth_client.get("/v1/cards/due", params={"deck": "xyz"}).status_code == 404


# --- 2. Idempotenz pro Nutzer --------------------------------------------- #


def test_client_id_ist_pro_nutzer_idempotent(auth_client, client):
    slug = _first_card(auth_client)
    now = datetime.now(UTC)
    gemeinsam = "kollision-client-id-1"
    a = _post(auth_client, _review(slug, now, client_id=gemeinsam))
    assert a["applied"] == 1

    client.headers.update(_register(client))
    b = _post(client, _review(slug, now, client_id=gemeinsam))
    assert b["applied"] == 1 and b["duplicates"] == 0  # war: stiller Verlust

    again = _post(client, _review(slug, now, client_id=gemeinsam))
    assert again["duplicates"] == 1


def test_migration_bestehende_db_alte_schemata(tmp_path):
    """Alte DB: globaler Unique-Index auf reviews.client_id, user_cards ohne step."""
    engine = create_engine(f"sqlite:///{tmp_path}/alt.db")
    with engine.begin() as conn:
        conn.execute(
            text("CREATE TABLE user_cards (id INTEGER PRIMARY KEY, user_id INT, state VARCHAR(16))")
        )
        conn.execute(text("INSERT INTO user_cards (user_id, state) VALUES (1, 'learning')"))
        conn.execute(
            text(
                "CREATE TABLE reviews (id INTEGER PRIMARY KEY, client_id VARCHAR(64), "
                "user_id INT, card_id INT)"
            )
        )
        conn.execute(text("CREATE UNIQUE INDEX ix_reviews_client_id ON reviews (client_id)"))
    migrate(engine)
    migrate(engine)  # idempotent
    insp = inspect(engine)
    assert "step" in {c["name"] for c in insp.get_columns("user_cards")}
    idx = {i["name"]: i for i in insp.get_indexes("reviews")}
    assert not idx["ix_reviews_client_id"]["unique"]
    assert idx["uq_reviews_user_client"]["unique"]
    with engine.begin() as conn:
        assert conn.execute(text("SELECT step FROM user_cards")).scalar() == 0
        conn.execute(text("INSERT INTO reviews (client_id, user_id, card_id) VALUES ('x', 1, 1)"))
        conn.execute(text("INSERT INTO reviews (client_id, user_id, card_id) VALUES ('x', 2, 1)"))


# --- 3. Lernschritte persistiert ------------------------------------------ #


def test_lernschritt_wird_persistiert_und_gut_nach_nochmal_bleibt_kurz(auth_client):
    slug = _first_card(auth_client)
    t = datetime.now(UTC) - timedelta(hours=3)
    a = _post(auth_client, _review(slug, t, rating=1))["results"][0]
    assert a["state"] == "learning"
    b = _post(auth_client, _review(slug, t + timedelta(minutes=2), rating=3))["results"][0]
    assert b["state"] == "learning"  # war: direkt review mit +1 Tag
    from app.db import SessionLocal

    with SessionLocal() as db:
        assert db.query(UserCard).one().step == 1
    c = _post(auth_client, _review(slug, t + timedelta(minutes=15), rating=3))["results"][0]
    assert c["state"] == "review"


# --- 4. Faelligkeitslast einheitlich -------------------------------------- #


def _lerne(client, n: int, now: datetime):
    cards = client.get("/v1/cards/due", params={"limit": n, "new_limit": n}).json()
    _post(client, *[_review(c["slug"], now - timedelta(days=6), rating=1) for c in cards])
    return cards


def test_faelligkeit_cards_due_cockpit_plan_forecast_stimmen_ueberein(auth_client):
    now = datetime.now(UTC)
    cards = _lerne(auth_client, 12, now)  # Nochmal vor 6 Tagen -> alle ueberfaellig/lernend
    pausiert = cards[0]["topic_slug"]
    auth_client.put("/v1/me/lernprofil", json={"themen_pausiert": [pausiert]})

    due = auth_client.get("/v1/cards/due", params={"limit": 200, "new_limit": 0}).json()
    erwartet = len(due)
    assert erwartet > 0
    assert all(c["topic_slug"] != pausiert for c in due)

    forecast = auth_client.get("/v1/progress/forecast", params={"days": 5}).json()
    assert forecast["due_per_day"][0] == erwartet

    exam = (date.today() + timedelta(days=120)).isoformat()
    auth_client.patch("/v1/auth/me", json={"exam_date": exam})
    cockpit = auth_client.get("/v1/examen/cockpit").json()
    wh = [b for b in cockpit["plan"][0]["blocks"] if b["kind"] == "wiederholung"]
    assert wh and wh[0]["title"] == f"{min(erwartet, 10**6)} faellige Karten"
    plan = auth_client.post("/v1/plan", json={"exam_date": exam}).json()
    wh2 = [b for b in plan["days"][0]["blocks"] if b["kind"] == "wiederholung"]
    assert wh2[0]["title"] == wh[0]["title"]


# --- 5. Klausurtermin / gestartete Themen --------------------------------- #


def test_cockpit_klausurtermin_stimmt_mit_dem_plan_ueberein(auth_client):
    exam = (date.today() + timedelta(days=150)).isoformat()
    auth_client.patch("/v1/auth/me", json={"exam_date": exam})
    cockpit = auth_client.get("/v1/examen/cockpit", params={"plan_days": 7}).json()
    plan = auth_client.post("/v1/plan", json={"exam_date": exam}).json()
    erste = next(
        d["date"] for d in plan["days"] if any(b["kind"] == "klausur" for b in d["blocks"])
    )
    assert cockpit["naechste_klausur"]["datum"] == erste
    # Nicht der naechste Samstag, solange die Grundlagenphase laeuft.
    assert date.fromisoformat(erste) > date.today() + timedelta(days=7)


def test_plan_zeigt_gestartete_themen_nicht_als_neu(auth_client):
    cards = auth_client.get("/v1/cards/due", params={"limit": 3, "new_limit": 3}).json()
    topic = cards[0]["topic_slug"]
    _post(auth_client, _review(cards[0]["slug"], datetime.now(UTC), rating=3))
    exam = (date.today() + timedelta(days=120)).isoformat()
    plan = auth_client.post("/v1/plan", json={"exam_date": exam}).json()
    titel = [
        b["title"] for d in plan["days"] for b in d["blocks"] if b["topic_slug"] == topic
    ]
    assert titel and titel[0].startswith("Weiterlernen: ")
