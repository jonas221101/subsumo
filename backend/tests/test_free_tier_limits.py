"""Free-Tier-Limits serverseitig (SUB-96, docs/20-release-g2-bezahlstrecke.md B2)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import pytest

import app.db as db_module
from app.config import get_settings
from app.models import Card, Review, Topic, User, UserCard

AUTH_PASSWORD = "examen2029!"
GUTACHTEN_TEXT = "Ein kurzer Testtext fuer den Struktur-Check ohne Anspruch auf Bewertung."
CASE_SLUGS = [
    "zr-fall-sonderpreis",
    "sr-fall-notwehr-schlagstock",
    "or-fall-versammlungsauflage",
]


@pytest.fixture
def paywall(monkeypatch):
    """Aktiviert die Paywall fuer die Dauer eines Tests (Default ist aus)."""
    monkeypatch.setenv("SUBSUMO_PAYWALL_ENABLED", "true")
    get_settings.cache_clear()
    try:
        yield
    finally:
        get_settings.cache_clear()


def _register(client) -> str:
    email = f"{uuid.uuid4().hex[:10]}@uni-beispiel.de"
    response = client.post("/v1/auth/register", json={"email": email, "password": AUTH_PASSWORD})
    assert response.status_code == 201, response.text
    client.headers["Authorization"] = f"Bearer {response.json()['access_token']}"
    return email


def _grant_pro(email: str) -> None:
    with db_module.SessionLocal() as db:
        user = db.query(User).filter_by(email=email).one()
        user.pro_until = datetime.now(UTC) + timedelta(days=30)
        db.add(user)
        db.commit()


def _make_due(email: str, area: str, count: int) -> None:
    """Legt ``count`` bereits faellige Karten aus ``area`` fuer den Nutzer an."""
    with db_module.SessionLocal() as db:
        user = db.query(User).filter_by(email=email).one()
        topic_slugs = [t.slug for t in db.query(Topic).filter_by(area=area).all()]
        cards = db.query(Card).filter(Card.topic_slug.in_(topic_slugs)).limit(count).all()
        assert len(cards) >= count, f"Testinhalt deckt {count} Karten in {area} nicht ab"
        due = datetime.now(UTC) - timedelta(days=1)
        for card in cards:
            db.add(UserCard(user_id=user.id, card_id=card.id, due=due, state="review"))
        db.commit()


def _log_reviews_today(email: str, count: int) -> None:
    """Simuliert ``count`` bereits eingereichte Reviews des heutigen Tages."""
    with db_module.SessionLocal() as db:
        user = db.query(User).filter_by(email=email).one()
        card = db.query(Card).first()
        now = datetime.now(UTC)
        for _ in range(count):
            db.add(
                Review(
                    client_id=f"seed-{uuid.uuid4().hex}",
                    user_id=user.id,
                    card_id=card.id,
                    rating=3,
                    reviewed_at=now,
                )
            )
        db.commit()


# --------------------------------------------------------------------------- #
# GET /cards/due - 20 faellige Karten/Tag, ein Rechtsgebiet
# --------------------------------------------------------------------------- #


def test_cards_due_free_nutzer_wird_auf_tageskontingent_gedeckelt(client, paywall):
    email = _register(client)
    _make_due(email, "zivilrecht", 25)
    _log_reviews_today(email, 15)

    body = client.get("/v1/cards/due", params={"limit": 200, "new_limit": 0}).json()
    due_cards = [c for c in body if c["state"] != "new"]
    assert len(due_cards) == 5  # 20 Tageskontingent - 15 bereits verbraucht


def test_cards_due_free_nutzer_ohne_restkontingent_bekommt_keine_faelligen_karten(
    client, paywall
):
    email = _register(client)
    _make_due(email, "zivilrecht", 5)
    _log_reviews_today(email, 20)

    body = client.get("/v1/cards/due", params={"limit": 200, "new_limit": 0}).json()
    assert body == []


def test_cards_due_pro_nutzer_ist_vom_tageskontingent_ausgenommen(client, paywall):
    email = _register(client)
    _grant_pro(email)
    _make_due(email, "zivilrecht", 25)
    _log_reviews_today(email, 15)

    body = client.get("/v1/cards/due", params={"limit": 200, "new_limit": 0}).json()
    due_cards = [c for c in body if c["state"] != "new"]
    assert len(due_cards) == 25


def test_cards_due_free_nutzer_ist_auf_ein_rechtsgebiet_festgelegt(client, paywall):
    email = _register(client)
    # Zivilrecht zuerst gelernt - das legt das Rechtsgebiet fest.
    _make_due(email, "zivilrecht", 3)
    _make_due(email, "strafrecht", 3)

    body = client.get("/v1/cards/due", params={"limit": 200, "new_limit": 0}).json()
    assert len(body) == 3
    with db_module.SessionLocal() as db:
        zivilrecht_topics = {t.slug for t in db.query(Topic).filter_by(area="zivilrecht").all()}
    assert all(c["topic_slug"] in zivilrecht_topics for c in body)


def test_cards_due_pro_nutzer_sieht_mehrere_rechtsgebiete(client, paywall):
    email = _register(client)
    _grant_pro(email)
    _make_due(email, "zivilrecht", 3)
    _make_due(email, "strafrecht", 3)

    body = client.get("/v1/cards/due", params={"limit": 200, "new_limit": 0}).json()
    assert len(body) == 6


# --------------------------------------------------------------------------- #
# GET /cases/{slug} - ab dem dritten unterschiedlichen Fall 403
# --------------------------------------------------------------------------- #


def test_cases_free_nutzer_ab_drittem_fall_403(client, paywall):
    _register(client)
    for slug in CASE_SLUGS[:2]:
        assert client.get(f"/v1/cases/{slug}").status_code == 200

    response = client.get(f"/v1/cases/{CASE_SLUGS[2]}")
    assert response.status_code == 403
    assert response.json()["detail"]["upgrade_required"] is True


def test_cases_free_nutzer_kann_bereits_gesehene_faelle_weiter_nutzen(client, paywall):
    _register(client)
    for slug in CASE_SLUGS[:2]:
        assert client.get(f"/v1/cases/{slug}").status_code == 200
    assert client.get(f"/v1/cases/{CASE_SLUGS[2]}").status_code == 403

    for slug in CASE_SLUGS[:2]:
        assert client.get(f"/v1/cases/{slug}").status_code == 200


def test_cases_pro_nutzer_ist_vom_fall_limit_ausgenommen(client, paywall):
    email = _register(client)
    _grant_pro(email)
    for slug in CASE_SLUGS:
        assert client.get(f"/v1/cases/{slug}").status_code == 200


def test_cases_unbekannter_fall_bleibt_404_auch_wenn_kontingent_erschoepft(client, paywall):
    _register(client)
    for slug in CASE_SLUGS[:2]:
        assert client.get(f"/v1/cases/{slug}").status_code == 200

    response = client.get("/v1/cases/gibt-es-nicht")
    assert response.status_code == 404


# --------------------------------------------------------------------------- #
# POST /gutachten/analyze - max. 3 Aufrufe/Woche
# --------------------------------------------------------------------------- #


def test_gutachten_analyze_free_nutzer_max_drei_pro_woche(client, paywall):
    _register(client)
    for _ in range(3):
        response = client.post("/v1/gutachten/analyze", json={"text": GUTACHTEN_TEXT})
        assert response.status_code == 200, response.text

    response = client.post("/v1/gutachten/analyze", json={"text": GUTACHTEN_TEXT})
    assert response.status_code == 403
    body = response.json()["detail"]
    assert body["upgrade_required"] is True
    assert "reset_at" in body


def test_gutachten_analyze_pro_nutzer_ist_vom_wochenlimit_ausgenommen(client, paywall):
    email = _register(client)
    _grant_pro(email)
    for _ in range(5):
        response = client.post("/v1/gutachten/analyze", json={"text": GUTACHTEN_TEXT})
        assert response.status_code == 200, response.text


# --------------------------------------------------------------------------- #
# Einheitliches Fehlerformat + Notausgang
# --------------------------------------------------------------------------- #


def test_alle_drei_limits_nutzen_dasselbe_fehlerformat(client, paywall):
    """upgrade_required: true einheitlich, damit F1 gezielt reagieren kann."""
    email = _register(client)
    _make_due(email, "zivilrecht", 5)
    _log_reviews_today(email, 20)
    cards_response = client.get("/v1/cards/due")
    assert cards_response.status_code == 200  # weiches Limit, kein 403

    for slug in CASE_SLUGS[:2]:
        assert client.get(f"/v1/cases/{slug}").status_code == 200
    case_response = client.get(f"/v1/cases/{CASE_SLUGS[2]}")

    for _ in range(3):
        response = client.post("/v1/gutachten/analyze", json={"text": GUTACHTEN_TEXT})
        assert response.status_code == 200
    analyze_response = client.post("/v1/gutachten/analyze", json={"text": GUTACHTEN_TEXT})

    for response in (case_response, analyze_response):
        assert response.status_code == 403
        detail = response.json()["detail"]
        assert detail["upgrade_required"] is True
        assert isinstance(detail["reason"], str) and detail["reason"]


def test_limits_greifen_nicht_wenn_paywall_deaktiviert(client):
    assert get_settings().paywall_enabled is False
    _register(client)

    for slug in CASE_SLUGS:
        assert client.get(f"/v1/cases/{slug}").status_code == 200
    for _ in range(5):
        response = client.post("/v1/gutachten/analyze", json={"text": GUTACHTEN_TEXT})
        assert response.status_code == 200, response.text
