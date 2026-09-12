"""Reviewer-Agent: adversarielle fachliche Pruefung eines Collector-Entwurfs.

Bewusst als zweiter, unabhaengiger Modellaufruf - nicht als weiterer Schritt
im selben Prompt. Ein Modell, das seinen eigenen Entwurf im selben Kontext
bewertet, neigt dazu, ihn zu bestaetigen (siehe Anchoring-Effekt bei
Selbstkorrektur). Ein frischer Aufruf ohne den Entstehungskontext des
Entwurfs prueft strenger.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field

import yaml

from app.core.llm import LLMClient, LLMError, get_llm_client
from app.services.redaktion.prompts import reviewer_prompt

_JSON_BLOCK = re.compile(r"\{.*\}", re.S)


class ReviewerError(Exception):
    """Der Reviewer konnte keine auswertbare Antwort liefern."""


@dataclass
class ReviewResult:
    approved: bool
    severity: str = "unbekannt"
    issues: list[str] = field(default_factory=list)

    @property
    def feedback_text(self) -> str:
        return "\n".join(f"- {issue}" for issue in self.issues)


class ReviewerAgent:
    def __init__(self, client: LLMClient | None = None) -> None:
        self.client = client or get_llm_client()

    def review(self, draft: dict, *, existing_slugs: list[str]) -> ReviewResult:
        draft_yaml = yaml.safe_dump(draft, allow_unicode=True, sort_keys=False)
        prompt = reviewer_prompt(draft_yaml=draft_yaml, existing_slugs=existing_slugs)
        try:
            response = self.client.complete(prompt, max_tokens=2000)
        except LLMError as exc:
            raise ReviewerError(f"LLM-Aufruf fehlgeschlagen: {exc}") from exc

        match = _JSON_BLOCK.search(response.text)
        if not match:
            raise ReviewerError("Antwort enthaelt kein auswertbares JSON")
        try:
            parsed = json.loads(match.group(0))
        except json.JSONDecodeError as exc:
            raise ReviewerError(f"Antwort ist kein gueltiges JSON: {exc}") from exc

        return ReviewResult(
            approved=bool(parsed.get("approved", False)),
            severity=str(parsed.get("severity", "unbekannt")),
            issues=[str(i) for i in parsed.get("issues", [])],
        )
