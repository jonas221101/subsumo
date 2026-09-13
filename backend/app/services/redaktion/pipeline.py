"""Orchestriert Collector und Reviewer zu einer vollstaendigen KI-Redaktion.

Ersetzt in docs/05-content-pipeline.md den Schritt "Autor schreibt YAML,
zweite Person reviewt fachlich" durch zwei KI-Agenten - ohne die dortigen
Garantien aufzuweichen. Drei Instanzen muessen zustimmen, bevor ein Inhalt
entsteht:

1. **Collector** (LLM) schreibt einen Entwurf.
2. **Struktur-Gate** (deterministisch, ``app.services.content.load_content`` -
   dieselbe Funktion, die auch die CI faehrt) prueft Pflichtfelder,
   Slug-Eindeutigkeit, Erwartungshorizont je Fall.
3. **Reviewer** (LLM, unabhaengiger Aufruf) prueft Urheberrecht, RDG-Konformitaet
   und fachliche Plausibilitaet - Dinge, die eine Formatpruefung nicht leisten
   kann.

Erst wenn beide Gates zustimmen, wird eine Datei geschrieben - und zwar mit
Herkunftsangabe (``topic.redaktion``), damit jederzeit nachvollziehbar bleibt,
was KI-erzeugt ist. Menschliche Stichprobe bleibt vorgesehen (siehe
docs/08-ki-redaktion.md), ist aber keine Voraussetzung fuer den Merge - das
waere sonst wieder der Flaschenhals, den diese Pipeline beheben soll.
"""

from __future__ import annotations

import tempfile
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

import yaml

from app.services.content import ContentBundle, load_content
from app.services.redaktion.collector import CollectorAgent, CollectorError, TopicRequest
from app.services.redaktion.reviewer import ReviewerAgent, ReviewerError

MAX_ROUNDS = 3


@dataclass
class RedaktionResult:
    accepted: bool
    topic_slug: str = ""
    path: Path | None = None
    rounds: int = 0
    history: list[str] = field(default_factory=list)
    draft: dict | None = None

    def to_dict(self) -> dict:
        return {
            "accepted": self.accepted,
            "topic_slug": self.topic_slug,
            "path": str(self.path) if self.path else None,
            "rounds": self.rounds,
            "history": self.history,
        }


def collect_existing_slugs(bundle: ContentBundle) -> list[str]:
    """Alle bereits vergebenen Slugs - Grundlage fuer Kollisionsvermeidung."""
    slugs: list[str] = [t["slug"] for t in bundle.topics]
    slugs += [c["slug"] for c in bundle.cards]
    slugs += [s["slug"] for s in bundle.schemata]
    slugs += [f["slug"] for f in bundle.cases]
    return sorted(set(slugs))


def _validate_structure(draft: dict) -> list[str]:
    """Prueft den Entwurf mit demselben Validator, den auch die CI faehrt.

    Laeuft in einem Temp-Verzeichnis - der Entwurf ist zu diesem Zeitpunkt
    noch nicht freigegeben und darf nicht im echten content/-Baum landen.
    """
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "entwurf.yaml"
        path.write_text(
            yaml.safe_dump(draft, allow_unicode=True, sort_keys=False), encoding="utf-8"
        )
        bundle = load_content(Path(tmp))
    return bundle.errors


class RedaktionPipeline:
    def __init__(
        self,
        *,
        content_dir: Path,
        collector: CollectorAgent | None = None,
        reviewer: ReviewerAgent | None = None,
        max_rounds: int = MAX_ROUNDS,
    ) -> None:
        self.content_dir = content_dir
        self.collector = collector or CollectorAgent()
        self.reviewer = reviewer or ReviewerAgent()
        self.max_rounds = max_rounds

    def run(self, request: TopicRequest) -> RedaktionResult:
        existing = collect_existing_slugs(load_content(self.content_dir))
        history: list[str] = []
        feedback = ""
        draft: dict | None = None

        for round_no in range(1, self.max_rounds + 1):
            try:
                draft = self.collector.collect(
                    request, existing_slugs=existing, feedback=feedback
                )
            except CollectorError as exc:
                history.append(f"Runde {round_no}: Collector-Fehler - {exc}")
                feedback = str(exc)
                continue

            struktur_fehler = _validate_structure(draft)
            if struktur_fehler:
                feedback = "Formatfehler:\n" + "\n".join(f"- {e}" for e in struktur_fehler)
                history.append(f"Runde {round_no}: Struktur-Gate abgelehnt - {feedback}")
                continue

            try:
                review = self.reviewer.review(draft, existing_slugs=existing)
            except ReviewerError as exc:
                history.append(f"Runde {round_no}: Reviewer-Fehler - {exc}")
                feedback = str(exc)
                continue

            if not review.approved:
                feedback = (
                    f"Reviewer lehnt ab ({review.severity}):\n{review.feedback_text}"
                )
                history.append(f"Runde {round_no}: {feedback}")
                continue

            history.append(f"Runde {round_no}: freigegeben (Struktur + Reviewer)")
            path = self._write(draft, request)
            return RedaktionResult(
                accepted=True,
                topic_slug=draft["topic"]["slug"],
                path=path,
                rounds=round_no,
                history=history,
                draft=draft,
            )

        return RedaktionResult(
            accepted=False,
            topic_slug=(draft or {}).get("topic", {}).get("slug", request.working_title),
            rounds=self.max_rounds,
            history=history,
            draft=draft,
        )

    def _write(self, draft: dict, request: TopicRequest) -> Path:
        slug = draft["topic"]["slug"]
        draft["topic"]["redaktion"] = {
            "erzeugt_von": "collector-agent-v1",
            "geprueft_von": "reviewer-agent-v1",
            "geprueft_am": date.today().isoformat(),
            "status": "ki-freigegeben",
        }
        area_dir = self.content_dir / request.area
        area_dir.mkdir(parents=True, exist_ok=True)
        path = area_dir / f"{slug}.yaml"
        if path.exists():
            raise FileExistsError(
                f"{path} existiert bereits - Ueberschreiben ist hier bewusst nicht "
                "automatisch: ein bestehender Inhalt mit Nutzerfortschritt braucht "
                "den Update-Pfad (content_hash-Markierung), nicht einen Neuschrieb."
            )
        path.write_text(
            yaml.safe_dump(draft, allow_unicode=True, sort_keys=False), encoding="utf-8"
        )
        return path
