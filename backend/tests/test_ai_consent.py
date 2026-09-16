"""Einwilligungs-Gate vor LLM-Versand (SUB-133).

Kernaussage dieser Datei: Ohne Einwilligung des Nutzers verlaesst kein
Gutachtentext das System in Richtung LLM-Provider - selbst wenn ein Provider
konfiguriert ist. Der ``SpyLLMClient`` zeichnet jeden Aufruf auf, unabhaengig
davon, ob ``LLMEvaluator`` etwaige Fehler intern abfaengt (siehe
``app/services/evaluator.py``); ``calls`` bleibt damit der verlaessliche Beweis,
nicht nur ein Seiteneffekt.
"""

from __future__ import annotations

import app.services.evaluator as evaluator_module
from app.config import get_settings
from app.core.llm import LLMResponse

CASE_SLUG = "zr-fall-sonderpreis"
GUTACHTEN = (
    "K koennte gegen V einen Anspruch auf Lieferung des Fahrrads aus "
    "§ 433 Abs. 1 BGB haben. Dazu muesste ein wirksamer Kaufvertrag "
    "vorliegen. Hier haben K und V sich ueber Ware und Preis geeinigt. "
    "Mithin besteht der Anspruch aus § 433 Abs. 1 BGB."
)


class SpyLLMClient:
    """Faengt jeden Aufruf ab, ohne echtes Netz - fuer den Beweis 'nie gerufen'."""

    available = True

    def __init__(self) -> None:
        self.calls: list[str] = []

    def complete(self, prompt: str, *, max_tokens: int = 4000) -> LLMResponse:
        self.calls.append(prompt)
        return LLMResponse(
            text='{"checkpoints":[],"summary":"llm-antwort"}', model="test-model"
        )


def _mit_llm_provider(auth_client, monkeypatch) -> SpyLLMClient:
    spy = SpyLLMClient()
    monkeypatch.setattr(evaluator_module, "get_llm_client", lambda: spy)
    monkeypatch.setenv("SUBSUMO_LLM_PROVIDER", "anthropic")
    monkeypatch.setenv("SUBSUMO_LLM_API_KEY", "test-key")
    get_settings.cache_clear()
    return spy


def _submit(auth_client):
    return auth_client.post(
        f"/v1/cases/{CASE_SLUG}/submit", json={"text": GUTACHTEN, "mode": "uebung"}
    )


# --------------------------------------------------------------------------- #
# (a) LLM aktiv, keine Einwilligung -> Heuristik, kein Provider-Aufruf
# --------------------------------------------------------------------------- #


def test_llm_aktiv_ohne_einwilligung_bleibt_heuristik_ohne_provider_aufruf(
    auth_client, monkeypatch
):
    spy = _mit_llm_provider(auth_client, monkeypatch)
    try:
        resp = _submit(auth_client)
        assert resp.status_code == 201, resp.text
        assert resp.json()["evaluation"]["engine"] == "heuristik"
        # Der eigentliche Zweck der Aufgabe: kein Nutzertext ging an den Provider.
        assert spy.calls == []
    finally:
        get_settings.cache_clear()


# --------------------------------------------------------------------------- #
# (b) LLM aktiv, Einwilligung erteilt -> LLM-Pfad
# --------------------------------------------------------------------------- #


def test_llm_aktiv_mit_einwilligung_nutzt_llm_pfad(auth_client, monkeypatch):
    spy = _mit_llm_provider(auth_client, monkeypatch)
    try:
        consent = auth_client.post("/v1/me/ai-consent")
        assert consent.status_code == 200
        assert consent.json()["ai_review_consent_at"] is not None

        resp = _submit(auth_client)
        assert resp.status_code == 201, resp.text
        assert resp.json()["evaluation"]["engine"].startswith("llm:")
        assert len(spy.calls) == 1
        assert GUTACHTEN in spy.calls[0]
    finally:
        get_settings.cache_clear()


# --------------------------------------------------------------------------- #
# (c) Widerruf wirkt ab der naechsten Abgabe
# --------------------------------------------------------------------------- #


def test_widerruf_wirkt_ab_der_naechsten_abgabe(auth_client, monkeypatch):
    spy = _mit_llm_provider(auth_client, monkeypatch)
    try:
        auth_client.post("/v1/me/ai-consent")
        erste = _submit(auth_client)
        assert erste.json()["evaluation"]["engine"].startswith("llm:")
        assert len(spy.calls) == 1

        widerruf = auth_client.delete("/v1/me/ai-consent")
        assert widerruf.status_code == 200
        assert widerruf.json()["ai_review_consent_at"] is None

        zweite = _submit(auth_client)
        assert zweite.json()["evaluation"]["engine"] == "heuristik"
        # Kein zweiter Aufruf nach dem Widerruf.
        assert len(spy.calls) == 1
    finally:
        get_settings.cache_clear()


# --------------------------------------------------------------------------- #
# (d) llm_provider=none -> unveraendertes Verhalten, mit oder ohne Einwilligung
# --------------------------------------------------------------------------- #


def test_ohne_llm_provider_bleibt_verhalten_unveraendert(auth_client):
    assert get_settings().llm_provider == "none"

    ohne_einwilligung = _submit(auth_client)
    assert ohne_einwilligung.json()["evaluation"]["engine"] == "heuristik"

    auth_client.post("/v1/me/ai-consent")
    mit_einwilligung = _submit(auth_client)
    assert mit_einwilligung.json()["evaluation"]["engine"] == "heuristik"


# --------------------------------------------------------------------------- #
# Einwilligungs-Endpunkte
# --------------------------------------------------------------------------- #


def test_ai_consent_erfordert_authentifizierung(client):
    assert client.post("/v1/me/ai-consent").status_code == 401
    assert client.delete("/v1/me/ai-consent").status_code == 401


def test_ai_consent_kein_default_ja(auth_client):
    me = auth_client.get("/v1/auth/me").json()
    assert me["ai_review_consent_at"] is None


def test_ai_consent_erteilen_setzt_zeitstempel_und_ist_sichtbar_in_me(auth_client):
    auth_client.post("/v1/me/ai-consent")
    me = auth_client.get("/v1/auth/me").json()
    assert me["ai_review_consent_at"] is not None


def test_ai_consent_widerruf_ohne_vorherige_einwilligung_ist_unschaedlich(auth_client):
    resp = auth_client.delete("/v1/me/ai-consent")
    assert resp.status_code == 200
    assert resp.json()["ai_review_consent_at"] is None
