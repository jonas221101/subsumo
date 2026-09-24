"""Tests der Verzahnung Pruefpunkt.card_slugs -> Wiederholungskarte (SUB-263).

Baut auf der bereits vorhandenen, LLM-unabhaengigen Bewertungsschleife auf: der
HeuristicEvaluator erzeugt bei jeder Abgabe ein PruefpunktResult(hit=False) fuer
jeden verfehlten Pruefpunkt, vollstaendig offline (siehe app/services/evaluator.py).
Diese Tests decken die daran haengende Karten-Konsequenz in ``submit_case`` ab.
"""

from __future__ import annotations

import json
import uuid
from datetime import UTC, datetime, timedelta

import app.db as db_module
import app.services.evaluator as evaluator_module
from app.config import get_settings
from app.core.llm import LLMResponse
from app.models import Card, CardStateEnum, Case, User, UserCard

AUTH_PASSWORD = "examen2029!"

CARD_PFLICHT = "sub263-test-karte-pflicht"
CARD_NEBEN = "sub263-test-karte-neben"
CASE_SLUG = "sub263-test-fall"

EXPECTATION = {
    "pruefpunkte": [
        {
            "id": "p1",
            "label": "Pflichtpunkt",
            "weight": 2.0,
            "required": True,
            "keywords": ["Anspruchsgrundlage433"],
            "card_slugs": [CARD_PFLICHT],
        },
        {
            "id": "p2",
            "label": "Nebenpunkt",
            "weight": 1.0,
            "keywords": ["Rechtsfolgenkette"],
            "card_slugs": [CARD_NEBEN],
        },
    ]
}

TEXT_OHNE_TREFFER = "Ein Text, der keinen der beiden Stichworte enthaelt."
TEXT_MIT_BEIDEN_TREFFERN = "Hier stehen Anspruchsgrundlage433 und Rechtsfolgenkette drin."

FERN_FAELLIG = timedelta(days=30)


def _register(client) -> str:
    email = f"{uuid.uuid4().hex[:10]}@uni-beispiel.de"
    response = client.post("/v1/auth/register", json={"email": email, "password": AUTH_PASSWORD})
    assert response.status_code == 201, response.text
    client.headers["Authorization"] = f"Bearer {response.json()['access_token']}"
    return email


def _seed_fall_mit_karten(email: str) -> datetime:
    """Legt Testkarten, ein Testfall mit card_slugs und weit faellige UserCards an.

    Gibt den urspruenglichen (weit in der Zukunft liegenden) Faelligkeitstermin
    zurueck, damit Tests eine deutliche Verschiebung nachweisen koennen.
    """
    far_future = datetime.now(UTC) + FERN_FAELLIG
    with db_module.SessionLocal() as db:
        user = db.query(User).filter_by(email=email).one()

        card_pflicht = Card(
            slug=CARD_PFLICHT, topic_slug="sub263-testthema", front="Frage A", back="Antwort A"
        )
        card_neben = Card(
            slug=CARD_NEBEN, topic_slug="sub263-testthema", front="Frage B", back="Antwort B"
        )
        db.add_all([card_pflicht, card_neben])
        db.flush()

        db.add(
            UserCard(
                user_id=user.id,
                card_id=card_pflicht.id,
                due=far_future,
                state="review",
                stability=12.5,
                reps=3,
            )
        )
        db.add(
            UserCard(
                user_id=user.id,
                card_id=card_neben.id,
                due=far_future,
                state="review",
                stability=8.0,
                reps=2,
            )
        )

        db.add(
            Case(
                slug=CASE_SLUG,
                topic_slug="sub263-testthema",
                area="zivilrecht",
                title="SUB-263 Testfall",
                facts="Ein Testsachverhalt ohne fachlichen Anspruch.",
                expectation=EXPECTATION,
            )
        )
        db.commit()
    return far_future


def _user_card(slug: str) -> UserCard:
    with db_module.SessionLocal() as db:
        card = db.query(Card).filter_by(slug=slug).one()
        return db.query(UserCard).filter_by(card_id=card.id).one()


def _as_aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=UTC)


def test_verfehlter_pflichtpunkt_stellt_karte_faellig_und_relearning(client):
    email = _register(client)
    far_future = _seed_fall_mit_karten(email)

    response = client.post(f"/v1/cases/{CASE_SLUG}/submit", json={"text": TEXT_OHNE_TREFFER})
    assert response.status_code == 201, response.text
    assert "Pflichtpunkt" in response.json()["evaluation"]["missed_required"]

    uc = _user_card(CARD_PFLICHT)
    assert _as_aware(uc.due) < far_future - timedelta(days=25)
    assert uc.state == CardStateEnum.RELEARNING.value
    # FSRS-Historie bleibt unangetastet - nur due/state aendern sich.
    assert uc.stability == 12.5
    assert uc.reps == 3


def test_verfehlter_nicht_pflicht_punkt_stellt_karte_nur_faellig(client):
    email = _register(client)
    far_future = _seed_fall_mit_karten(email)

    response = client.post(f"/v1/cases/{CASE_SLUG}/submit", json={"text": TEXT_OHNE_TREFFER})
    assert response.status_code == 201, response.text

    uc = _user_card(CARD_NEBEN)
    assert _as_aware(uc.due) < far_future - timedelta(days=25)
    # Kein Pflichtpunkt - state bleibt unveraendert.
    assert uc.state == "review"
    assert uc.stability == 8.0


def test_getroffener_pruefpunkt_laesst_karte_unangetastet(client):
    email = _register(client)
    far_future = _seed_fall_mit_karten(email)

    response = client.post(
        f"/v1/cases/{CASE_SLUG}/submit", json={"text": TEXT_MIT_BEIDEN_TREFFERN}
    )
    assert response.status_code == 201, response.text
    assert response.json()["evaluation"]["missed_required"] == []

    uc_pflicht = _user_card(CARD_PFLICHT)
    uc_neben = _user_card(CARD_NEBEN)
    assert _as_aware(uc_pflicht.due) == far_future
    assert uc_pflicht.state == "review"
    assert _as_aware(uc_neben.due) == far_future
    assert uc_neben.state == "review"


def test_fall_ohne_card_slugs_bleibt_unveraendert(auth_client):
    """Regressionsschutz: bestehende Faelle ohne card_slugs verhalten sich wie zuvor."""
    response = auth_client.post(
        "/v1/cases/zr-fall-sonderpreis/submit",
        json={"text": "Ein kurzer Text ohne jede Relevanz fuer den Fall."},
    )
    assert response.status_code == 201, response.text
    # Keine card_slugs im echten Content-Fall -> keine Karten-Konsequenz, kein Fehler.
    assert response.json()["evaluation"]["missed_required"]


class _FakeLLMClient:
    """Antwortet deterministisch, ohne echtes Netz - analog test_ai_consent.py."""

    available = True

    def __init__(self, checkpoints: list[dict]) -> None:
        self._checkpoints = checkpoints

    def complete(self, prompt: str, *, max_tokens: int = 4000) -> LLMResponse:
        payload = {"checkpoints": self._checkpoints, "summary": "llm-test"}
        return LLMResponse(text=json.dumps(payload), model="test-model")


def test_konsequenzlogik_greift_evaluator_unabhaengig_auch_bei_llmevaluator(client, monkeypatch):
    """Die Karten-Konsequenz haengt nur an PruefpunktResult.hit, nicht am
    Evaluator-Typ - LLMEvaluator erzeugt dieselbe Datenstruktur wie die
    Heuristik (SUB-263 Abnahmekriterium)."""
    email = _register(client)
    far_future = _seed_fall_mit_karten(email)

    fake = _FakeLLMClient(
        [
            {"id": "p1", "hit": False, "evidence": "", "comment": ""},
            {"id": "p2", "hit": False, "evidence": "", "comment": ""},
        ]
    )
    monkeypatch.setattr(evaluator_module, "get_llm_client", lambda: fake)
    monkeypatch.setenv("SUBSUMO_LLM_PROVIDER", "anthropic")
    monkeypatch.setenv("SUBSUMO_LLM_API_KEY", "test-key")
    get_settings.cache_clear()
    try:
        consent = client.post("/v1/me/ai-consent")
        assert consent.status_code == 200

        response = client.post(f"/v1/cases/{CASE_SLUG}/submit", json={"text": TEXT_OHNE_TREFFER})
        assert response.status_code == 201, response.text
        assert response.json()["evaluation"]["engine"].startswith("llm:")

        uc_pflicht = _user_card(CARD_PFLICHT)
        uc_neben = _user_card(CARD_NEBEN)
        assert _as_aware(uc_pflicht.due) < far_future - timedelta(days=25)
        assert uc_pflicht.state == CardStateEnum.RELEARNING.value
        assert _as_aware(uc_neben.due) < far_future - timedelta(days=25)
        assert uc_neben.state == "review"
    finally:
        get_settings.cache_clear()
