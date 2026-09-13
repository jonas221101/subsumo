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
_ALLOWED_SEVERITIES = {"ok", "kleinere_maengel", "schwerwiegend"}


def _object_without_duplicate_keys(pairs: list[tuple[str, object]]) -> dict:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"doppelter JSON-Schluessel: {key}")
        result[key] = value
    return result


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
        # The permissive extraction intentionally allows prose/code fences
        # around one object, but must not extract an object nested in an array.
        if (
            response.text[: match.start()].rstrip().endswith("[")
            or response.text[match.end() :].lstrip().startswith("]")
        ):
            raise ReviewerError("Reviewer-JSON muss ein einzelnes Objekt sein")
        try:
            parsed = json.loads(
                match.group(0), object_pairs_hook=_object_without_duplicate_keys
            )
        except (json.JSONDecodeError, ValueError) as exc:
            raise ReviewerError(f"Antwort ist kein gueltiges JSON: {exc}") from exc

        if not isinstance(parsed, dict):
            raise ReviewerError("Reviewer-JSON muss ein Objekt sein")
        required = {"approved", "severity", "issues"}
        missing = required - parsed.keys()
        if missing:
            raise ReviewerError(
                "Reviewer-JSON enthaelt nicht alle Pflichtfelder: "
                + ", ".join(sorted(missing))
            )
        if type(parsed["approved"]) is not bool:
            raise ReviewerError("Reviewer-Feld 'approved' muss boolesch sein")
        if (
            type(parsed["severity"]) is not str
            or parsed["severity"] not in _ALLOWED_SEVERITIES
        ):
            raise ReviewerError("Reviewer-Feld 'severity' ist ungueltig")
        if not isinstance(parsed["issues"], list) or not all(
            isinstance(issue, str) for issue in parsed["issues"]
        ):
            raise ReviewerError("Reviewer-Feld 'issues' muss eine Liste aus Strings sein")
        if parsed["approved"] and (
            parsed["issues"] or parsed["severity"] != "ok"
        ):
            raise ReviewerError(
                "Freigabe ist nur mit severity 'ok' und ohne issues gueltig"
            )
        if not parsed["approved"] and parsed["severity"] == "ok":
            raise ReviewerError(
                "Ablehnung darf nicht severity 'ok' verwenden"
            )

        return ReviewResult(
            approved=parsed["approved"],
            severity=parsed["severity"],
            issues=parsed["issues"],
        )
