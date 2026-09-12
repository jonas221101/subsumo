"""Collector-Agent: schlaegt Lerninhalte zu einem Thema vor.

Loest Challenge 10 (Content ist der Engpass) durch Automatisierung des
Rohentwurfs. Der Collector ist bewusst NICHT die letzte Instanz - sein Entwurf
durchlaeuft danach die Schema-Validierung (deterministisch) und den
Reviewer-Agenten (fachliches Urteil), siehe ``pipeline.py``. Ein Collector,
der allein entscheidet, was veroeffentlicht wird, waere genau die Blackbox,
die diese App an anderer Stelle bewusst vermeidet (siehe evaluator.py).
"""

from __future__ import annotations

import re
from dataclasses import dataclass

import yaml

from app.core.llm import LLMClient, LLMError, get_llm_client
from app.services.redaktion.prompts import collector_prompt

_YAML_BLOCK = re.compile(r"```(?:ya?ml)?\s*\n(.*?)```", re.S)


@dataclass
class TopicRequest:
    area: str
    working_title: str
    context: str = ""
    min_cards: int = 6
    min_schemata: int = 1
    min_cases: int = 1


class CollectorError(Exception):
    """Der Collector konnte keinen brauchbaren Entwurf liefern."""


def _extract_yaml(text: str) -> str:
    """Der Prompt verlangt reines YAML, Modelle liefern trotzdem gern einen
    Codeblock - beide Formen werden akzeptiert."""
    match = _YAML_BLOCK.search(text)
    return match.group(1) if match else text


class CollectorAgent:
    def __init__(self, client: LLMClient | None = None) -> None:
        self.client = client or get_llm_client()

    def collect(
        self,
        request: TopicRequest,
        *,
        existing_slugs: list[str],
        feedback: str = "",
    ) -> dict:
        """Liefert einen Rohentwurf als geparstes dict (Struktur einer
        content/*.yaml-Datei). Wirft ``CollectorError``, wenn das Modell kein
        gueltiges YAML liefert - das ist ein Retry-Signal fuer die Pipeline,
        keine stille Fehlertoleranz wie beim Evaluator-Fallback."""
        prompt = collector_prompt(
            area=request.area,
            working_title=request.working_title,
            context=request.context or request.working_title,
            min_cards=request.min_cards,
            min_schemata=request.min_schemata,
            min_cases=request.min_cases,
            existing_slugs=existing_slugs,
            feedback=feedback,
        )
        try:
            response = self.client.complete(prompt, max_tokens=8000)
        except LLMError as exc:
            raise CollectorError(f"LLM-Aufruf fehlgeschlagen: {exc}") from exc

        raw = _extract_yaml(response.text)
        try:
            draft = yaml.safe_load(raw)
        except yaml.YAMLError as exc:
            raise CollectorError(f"Kein gueltiges YAML in der Antwort: {exc}") from exc

        if not isinstance(draft, dict) or "topic" not in draft:
            raise CollectorError("Antwort enthaelt keinen 'topic'-Block")
        return draft
