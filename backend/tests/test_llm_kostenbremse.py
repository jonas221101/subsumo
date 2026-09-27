"""Kostenbremse fuer LLM-Korrekturen (SUB-310, docs/19-kosten-preis-budget.md
Abschnitt 5).

Zwei unabhaengige Schwellen, beide mit demselben Verhalten bei Erreichen:
``get_evaluator()`` liefert lautlos ``HeuristicEvaluator`` statt
``LLMEvaluator`` zurueck - kein Fehler, kein 5xx, nur eine andere
Korrekturqualitaet. Der ``SpyLLMClient`` (wie in ``test_ai_consent.py``)
beweist zusaetzlich, dass in diesem Fall gar kein Aufruf an den Provider geht.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import app.db as db_module
from app.config import get_settings
from app.core.llm import LLMResponse
from app.models import LlmCorrectionCall, User
from app.services.limits import LLM_CORRECTIONS_PER_USER_PER_MONTH

CASE_SLUG = "zr-fall-sonderpreis"
GUTACHTEN = (
    "K koennte gegen V einen Anspruch auf Lieferung des Fahrrads aus "
    "§ 433 Abs. 1 BGB haben. Dazu muesste ein wirksamer Kaufvertrag "
    "vorliegen. Hier haben K und V sich ueber Ware und Preis geeinigt. "
    "Mithin besteht der Anspruch aus § 433 Abs. 1 BGB."
)


class SpyLLMClient:
    """Faengt jeden Aufruf ab, ohne echtes Netz - Beweis fuer 'nie gerufen'."""

    available = True

    def __init__(self) -> None:
        self.calls: list[str] = []

    def complete(self, prompt: str, *, max_tokens: int = 4000) -> LLMResponse:
        self.calls.append(prompt)
        return LLMResponse(
            text='{"checkpoints":[],"summary":"llm-antwort"}', model="test-model"
        )


def _mit_llm_provider(monkeypatch, **env: str) -> SpyLLMClient:
    import app.services.evaluator as evaluator_module

    spy = SpyLLMClient()
    monkeypatch.setattr(evaluator_module, "get_llm_client", lambda: spy)
    monkeypatch.setenv("SUBSUMO_LLM_PROVIDER", "anthropic")
    monkeypatch.setenv("SUBSUMO_LLM_API_KEY", "test-key")
    for key, value in env.items():
        monkeypatch.setenv(key, value)
    get_settings.cache_clear()
    return spy


def _register_mit_einwilligung(client) -> str:
    email = f"{uuid.uuid4().hex[:10]}@uni-beispiel.de"
    response = client.post(
        "/v1/auth/register", json={"email": email, "password": "examen2029!"}
    )
    assert response.status_code == 201, response.text
    client.headers["Authorization"] = f"Bearer {response.json()['access_token']}"
    consent = client.post("/v1/me/ai-consent")
    assert consent.status_code == 200
    return email


def _submit(client):
    return client.post(
        f"/v1/cases/{CASE_SLUG}/submit", json={"text": GUTACHTEN, "mode": "uebung"}
    )


def _seed_llm_calls(email: str, count: int, *, age_days: float = 0.0) -> None:
    with db_module.SessionLocal() as db:
        user = db.query(User).filter_by(email=email).one()
        created_at = datetime.now(UTC) - timedelta(days=age_days)
        for _ in range(count):
            db.add(LlmCorrectionCall(user_id=user.id, created_at=created_at))
        db.commit()


# --------------------------------------------------------------------------- #
# Fair-Use-Limit je Nutzer (20/Monat, docs/19 Abschnitt 5)
# --------------------------------------------------------------------------- #


def test_user_limit_knapp_unterschritten_nutzt_weiterhin_llm(client, monkeypatch):
    spy = _mit_llm_provider(monkeypatch)
    try:
        email = _register_mit_einwilligung(client)
        _seed_llm_calls(email, LLM_CORRECTIONS_PER_USER_PER_MONTH - 1)

        resp = _submit(client)
        assert resp.status_code == 201, resp.text
        assert resp.json()["evaluation"]["engine"].startswith("llm:")
        assert len(spy.calls) == 1
    finally:
        get_settings.cache_clear()


def test_user_limit_exakt_erreicht_faellt_auf_heuristik_zurueck(client, monkeypatch):
    """Grenzfall: bei genau erreichtem Limit greift die Bremse bereits."""
    spy = _mit_llm_provider(monkeypatch)
    try:
        email = _register_mit_einwilligung(client)
        _seed_llm_calls(email, LLM_CORRECTIONS_PER_USER_PER_MONTH)

        resp = _submit(client)
        assert resp.status_code == 201, resp.text
        assert resp.json()["evaluation"]["engine"] == "heuristik"
        # Kein 5xx UND kein Aufruf an den Provider - die Bremse greift, bevor
        # ueberhaupt Kosten entstehen koennten.
        assert spy.calls == []
    finally:
        get_settings.cache_clear()


def test_user_limit_zaehlt_nur_das_laufende_30_tage_fenster(client, monkeypatch):
    spy = _mit_llm_provider(monkeypatch)
    try:
        email = _register_mit_einwilligung(client)
        _seed_llm_calls(email, LLM_CORRECTIONS_PER_USER_PER_MONTH, age_days=31)

        resp = _submit(client)
        assert resp.status_code == 201, resp.text
        assert resp.json()["evaluation"]["engine"].startswith("llm:")
        assert len(spy.calls) == 1
    finally:
        get_settings.cache_clear()


# --------------------------------------------------------------------------- #
# Globales Monatsbudget (ueber alle Nutzer)
# --------------------------------------------------------------------------- #


def test_globales_budget_erschoepft_faellt_ohne_fehler_auf_heuristik_zurueck(
    client, monkeypatch
):
    # Budget = Kostenschaetzwert -> genau ein Aufruf passt ins Budget.
    spy = _mit_llm_provider(
        monkeypatch,
        SUBSUMO_LLM_MONTHLY_BUDGET_EUR="0.30",
        SUBSUMO_LLM_COST_ESTIMATE_EUR="0.30",
    )
    try:
        andere_email = _register_mit_einwilligung(client)
        _seed_llm_calls(andere_email, 1)

        resp = _submit(client)
        assert resp.status_code == 201, resp.text
        assert resp.json()["evaluation"]["engine"] == "heuristik"
        assert spy.calls == []
    finally:
        get_settings.cache_clear()


def test_globales_budget_gilt_nutzeruebergreifend(client, monkeypatch):
    """Das Budget zaehlt alle Nutzer zusammen, nicht je Nutzer einzeln."""
    spy = _mit_llm_provider(
        monkeypatch,
        SUBSUMO_LLM_MONTHLY_BUDGET_EUR="0.30",
        SUBSUMO_LLM_COST_ESTIMATE_EUR="0.30",
    )
    try:
        verbraucher_email = _register_mit_einwilligung(client)
        _seed_llm_calls(verbraucher_email, 1)

        client.headers.pop("Authorization", None)
        _register_mit_einwilligung(client)
        resp = _submit(client)

        assert resp.status_code == 201, resp.text
        assert resp.json()["evaluation"]["engine"] == "heuristik"
        assert spy.calls == []
    finally:
        get_settings.cache_clear()


def test_budget_und_limit_unter_schwelle_bleiben_ohne_wirkung(client, monkeypatch):
    """Regression: die Bremse darf normale Nutzung nicht mitbremsen."""
    spy = _mit_llm_provider(
        monkeypatch,
        SUBSUMO_LLM_MONTHLY_BUDGET_EUR="50.0",
        SUBSUMO_LLM_COST_ESTIMATE_EUR="0.30",
    )
    try:
        _register_mit_einwilligung(client)
        resp = _submit(client)
        assert resp.status_code == 201, resp.text
        assert resp.json()["evaluation"]["engine"].startswith("llm:")
        assert len(spy.calls) == 1
    finally:
        get_settings.cache_clear()
