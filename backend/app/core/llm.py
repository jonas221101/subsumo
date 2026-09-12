"""Gemeinsamer LLM-Client fuer Evaluator und KI-Redaktion.

Ein Aufrufpfad statt zwei, damit Provider-Wechsel, Timeouts und
Fehlerbehandlung an einer Stelle stehen. Absichtlich minimal: ein Protocol
fuer Testbarkeit ohne Netz (siehe ``FakeLLMClient`` in den Tests), eine
duenne Anthropic-Implementierung, sonst nichts.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from app.config import Settings, get_settings


class LLMError(Exception):
    """Aufruf fehlgeschlagen - kein Netz, kein Key, Timeout, Server-Fehler."""


@dataclass
class LLMResponse:
    text: str
    model: str
    stop_reason: str = ""


class LLMClient(Protocol):
    """Minimale Schnittstelle. Jede Implementierung - echt oder Fake in
    Tests - muss nur diese eine Methode erfuellen."""

    def complete(self, prompt: str, *, max_tokens: int = 4000) -> LLMResponse: ...


class AnthropicClient:
    """Duenne Schicht um die Anthropic Messages API.

    Wirft ``LLMError`` bei jedem Problem - Aufrufer entscheiden selbst, ob sie
    das als Fallback-Signal (Evaluator) oder als Abbruch (Redaktion) behandeln.
    Es wird nie eine Nutzerkennung im Prompt uebertragen (siehe
    docs/06-recht-compliance.md, DSGVO-Abschnitt).
    """

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    @property
    def available(self) -> bool:
        return self.settings.llm_provider == "anthropic" and bool(self.settings.llm_api_key)

    def complete(self, prompt: str, *, max_tokens: int = 4000) -> LLMResponse:
        if not self.available:
            raise LLMError("Kein LLM-Provider konfiguriert (SUBSUMO_LLM_API_KEY fehlt)")
        try:
            import httpx

            response = httpx.post(
                "https://api.anthropic.com/v1/messages",
                timeout=self.settings.llm_timeout_s,
                headers={
                    "x-api-key": self.settings.llm_api_key,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json={
                    "model": self.settings.llm_model,
                    "max_tokens": max_tokens,
                    "messages": [{"role": "user", "content": prompt}],
                },
            )
            response.raise_for_status()
            data = response.json()
            text = data["content"][0]["text"]
            return LLMResponse(
                text=text, model=data.get("model", self.settings.llm_model),
                stop_reason=data.get("stop_reason", ""),
            )
        except LLMError:
            raise
        except Exception as exc:  # noqa: BLE001 - jeder Grund wird zu LLMError
            raise LLMError(f"Anthropic-Aufruf fehlgeschlagen: {exc}") from exc


def get_llm_client() -> LLMClient:
    return AnthropicClient()
