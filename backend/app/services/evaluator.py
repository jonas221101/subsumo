"""Inhaltliche Bewertung eines Gutachtens gegen einen Erwartungshorizont.

Loest Challenge 4. Zwei Designentscheidungen sind nicht verhandelbar:

* **Bewertung nur gegen einen hinterlegten Erwartungshorizont.** Es gibt keinen
  Endpunkt "bewerte diesen beliebigen Sachverhalt". Das haelt die Bewertung
  nachvollziehbar und die Anwendung ausserhalb des RDG
  (siehe docs/06-recht-compliance.md).
* **Jeder Punktabzug ist auf einen Pruefpunkt zurueckfuehrbar.** Eine Note ohne
  Begruendung ist wertlos; eine KI-Note ohne Begruendung ist schaedlich.

Ohne konfigurierten LLM-Provider laeuft der heuristische Evaluator. Der ist
schwaecher, aber vollstaendig offline, kostenlos und deterministisch - die App
funktioniert also auch ohne KI.
"""

from __future__ import annotations

import json
import re
from dataclasses import asdict, dataclass, field
from datetime import UTC, datetime
from typing import Any, Protocol

from sqlalchemy.orm import Session

from app.config import Settings, get_settings
from app.core.llm import LLMClient, get_llm_client
from app.models import User
from app.services import limits
from app.services.gutachten import GutachtenReport

# Notenskala der juristischen Staatspruefungen (JurNotSkalV): untere Grenze
# der jeweiligen Notenstufe in Punkten.
NOTENSTUFEN: list[tuple[float, str]] = [
    (16.0, "sehr gut"),
    (13.0, "gut"),
    (10.0, "vollbefriedigend"),
    (7.0, "befriedigend"),
    (4.0, "ausreichend"),
    (1.5, "mangelhaft"),
    (0.0, "ungenuegend"),
]


def note_fuer_punkte(points: float) -> str:
    for untergrenze, name in NOTENSTUFEN:
        if points >= untergrenze:
            return name
    return "ungenuegend"


@dataclass
class Pruefpunkt:
    """Ein Posten des Erwartungshorizonts."""

    id: str
    label: str
    weight: float = 1.0
    keywords: list[str] = field(default_factory=list)
    norms: list[str] = field(default_factory=list)
    required: bool = False


@dataclass
class PruefpunktResult:
    id: str
    label: str
    weight: float
    hit: bool
    evidence: str = ""
    comment: str = ""


@dataclass
class Evaluation:
    points: float                 # 0-18 (JAP-Skala)
    note: str
    content_ratio: float          # 0..1 gewichtete Trefferquote
    structure_score: int          # 0..100 aus der Strukturanalyse
    checkpoints: list[PruefpunktResult]
    missed_required: list[str]
    summary: str
    engine: str                   # "heuristik" | "llm:<model>"
    disclaimer: str = (
        "Lernhilfe, keine Rechtsberatung. Die Bewertung erfolgt gegen den "
        "hinterlegten Erwartungshorizont dieses Uebungsfalls."
    )

    def to_dict(self) -> dict:
        data = asdict(self)
        data["points"] = round(self.points, 1)
        return data


def parse_expectation(raw: dict[str, Any] | None) -> list[Pruefpunkt]:
    points = (raw or {}).get("pruefpunkte", [])
    return [
        Pruefpunkt(
            id=str(p.get("id") or f"p{i}"),
            label=p.get("label", ""),
            weight=float(p.get("weight", 1.0)),
            keywords=list(p.get("keywords", [])),
            norms=list(p.get("norms", [])),
            required=bool(p.get("required", False)),
        )
        for i, p in enumerate(points)
    ]


def _normalize(text: str) -> str:
    text = text.lower()
    text = text.replace("ä", "a").replace("ö", "o").replace("ü", "u").replace("ß", "ss")
    return re.sub(r"\s+", " ", text)


def _digraph_fold(text: str) -> str:
    """Loest ASCII-Umlaut-Digraphen auf (ae/oe/ue -> a/o/u).

    Zwei Richtungen, ein Fallback: Ein Stichwort in ASCII-Transliteration
    ('ausdruecklich') trifft nach _normalize() keinen Text mit echtem Umlaut
    ('ausdrücklich' -> 'ausdrucklich', Einzelbuchstabe) - und umgekehrt trifft
    ein Stichwort mit echtem Umlaut ('überzeugend' -> 'uberzeugend') keinen
    Nutzertext, der 'ueberzeugend' ohne Umlauttaste getippt hat. Beides wurde
    beim ersten echten End-to-End-Testlauf der KI-Redaktion real beobachtet.

    Deshalb wird diese Faltung auf BEIDE Seiten des Vergleichs angewendet -
    bewusst nur als zweiter, nachrangiger Versuch, nachdem der direkte
    Treffer auf dem unveraenderten Text gescheitert ist. Sie kann seltene
    echte Wortfolgen wie 'neue' -> 'neu' verkuerzen und so einen Treffer
    liefern, der bei genauerem Hinsehen Zufall ist - hinnehmbar fuer einen
    ohnehin heuristischen Fallback-Evaluator (siehe HEURISTIK_MAX_PUNKTE),
    nicht fuer die LLM-Bewertung, die diese Funktion nicht verwendet.
    """
    for digraph, letter in (("ae", "a"), ("oe", "o"), ("ue", "u")):
        text = text.replace(digraph, letter)
    return text


class Evaluator(Protocol):
    def evaluate(
        self, *, text: str, expectation: dict, structure: GutachtenReport
    ) -> Evaluation: ...


# Obergrenze fuer die Heuristik. Ein Stichwortabgleich kann erkennen, *ob* ein
# Pruefpunkt angesprochen wurde - nicht, ob die Argumentation traegt. Ein
# Praedikatsexamen (ab 9 Punkten) vergibt man dafuer nicht, und schon gar kein
# "sehr gut". Eine geschenkte Note zerstoert das Vertrauen in jede spaetere
# Rueckmeldung; die Deckelung wird dem Nutzer ausdruecklich erklaert.
HEURISTIK_MAX_PUNKTE = 11.0


class HeuristicEvaluator:
    """Stichwort- und Normabgleich gegen den Erwartungshorizont.

    Bewusst konservativ und gedeckelt: er erkennt, *ob* ein Pruefpunkt
    angesprochen wurde, nicht ob die Argumentation traegt. Das ist ehrlicher
    als eine Scheinnote und als Fallback ohne Netz belastbar.
    """

    name = "heuristik"

    def evaluate(
        self, *, text: str, expectation: dict, structure: GutachtenReport
    ) -> Evaluation:
        checkpoints = parse_expectation(expectation)
        haystack = _normalize(text)
        folded_haystack = _digraph_fold(haystack)
        norms_seen = {_normalize(n).replace(" ", "") for n in structure.norms}

        results: list[PruefpunktResult] = []
        for cp in checkpoints:
            evidence = ""
            hit = False
            for kw in cp.keywords:
                normalized_kw = _normalize(kw)
                if normalized_kw in haystack or _digraph_fold(normalized_kw) in folded_haystack:
                    hit, evidence = True, kw
                    break
            if not hit:
                for norm in cp.norms:
                    key = _normalize(norm).replace(" ", "")
                    if any(key in seen or seen in key for seen in norms_seen):
                        hit, evidence = True, norm
                        break
            results.append(
                PruefpunktResult(
                    id=cp.id,
                    label=cp.label,
                    weight=cp.weight,
                    hit=hit,
                    evidence=evidence,
                    comment="" if hit else "Dieser Pruefpunkt wird nicht angesprochen.",
                )
            )

        total_weight = sum(cp.weight for cp in checkpoints) or 1.0
        achieved = sum(cp.weight for cp, r in zip(checkpoints, results, strict=True) if r.hit)
        content_ratio = achieved / total_weight

        missed_required = [
            cp.label
            for cp, r in zip(checkpoints, results, strict=True)
            if cp.required and not r.hit
        ]

        # Inhalt zaehlt deutlich schwerer als Form - so bewerten Korrektoren auch.
        raw = 0.72 * content_ratio + 0.28 * (structure.score / 100)
        points = round(raw * 18 * 2) / 2
        if missed_required:
            # Ein fehlender Kernpunkt deckelt die Bewertung im unteren Bereich.
            points = min(points, 3.5)
        gedeckelt = points > HEURISTIK_MAX_PUNKTE
        points = max(0.0, min(HEURISTIK_MAX_PUNKTE, points))

        getroffen = sum(1 for r in results if r.hit)
        summary = (
            f"{getroffen} von {len(results)} Pruefpunkten angesprochen "
            f"(gewichtet {content_ratio:.0%}), Strukturscore {structure.score}/100."
        )
        if missed_required:
            summary += " Kernpruefpunkte fehlen: " + ", ".join(missed_required) + "."
        if gedeckelt:
            summary += (
                f" Ohne KI-Korrektur wird bei {HEURISTIK_MAX_PUNKTE:.0f} Punkten "
                "gedeckelt: Der Stichwortabgleich prueft, ob ein Punkt "
                "angesprochen wurde, nicht ob die Argumentation ueberzeugt."
            )

        return Evaluation(
            points=points,
            note=note_fuer_punkte(points),
            content_ratio=round(content_ratio, 3),
            structure_score=structure.score,
            checkpoints=results,
            missed_required=missed_required,
            summary=summary,
            engine=self.name,
        )


class LLMEvaluator:
    """Bewertung durch ein Sprachmodell - streng an den Erwartungshorizont gebunden.

    Faellt bei jedem Fehler (kein Key, Timeout, unparsbare Antwort) lautlos auf
    die Heuristik zurueck. Ein Ausfall des Providers darf nie dazu fuehren, dass
    ein Nutzer nach fuenf Stunden Klausur gar kein Feedback bekommt.

    Es wird keine Nutzerkennung uebertragen (Pseudonymisierung, Art. 32 DSGVO).
    """

    def __init__(self, client: LLMClient | None = None) -> None:
        self.settings = get_settings()
        self.fallback = HeuristicEvaluator()
        # Injizierbar fuer Tests (FakeLLMClient) - Produktionscode laesst das
        # weg und bekommt den echten Anthropic-Client ueber get_llm_client().
        self.client = client

    @property
    def name(self) -> str:
        return f"llm:{self.settings.llm_model}"

    def _build_prompt(self, text: str, checkpoints: list[Pruefpunkt]) -> str:
        horizont = "\n".join(
            f"- [{cp.id}] {cp.label} (Gewicht {cp.weight}"
            + (", zwingend" if cp.required else "")
            + (f", Normen: {', '.join(cp.norms)}" if cp.norms else "")
            + ")"
            for cp in checkpoints
        )
        return (
            "Du korrigierst eine juristische Uebungsklausur. Bewerte AUSSCHLIESSLICH "
            "anhand des folgenden Erwartungshorizonts. Erfinde keine Pruefpunkte und "
            "keine Normen.\n\n"
            f"ERWARTUNGSHORIZONT:\n{horizont}\n\n"
            f"GUTACHTEN DES PRUEFLINGS:\n{text}\n\n"
            "Antworte ausschliesslich mit JSON nach diesem Schema:\n"
            '{"checkpoints":[{"id":"...","hit":true,"evidence":"woertliches Zitat aus '
            'dem Gutachten","comment":"knappe Begruendung"}],'
            '"summary":"zwei bis vier Saetze Gesamtrueckmeldung"}\n'
            "Regeln: 'hit' nur true, wenn der Pruefpunkt inhaltlich tatsaechlich "
            "behandelt wird, nicht bei blosser Erwaehnung. 'evidence' muss woertlich "
            "im Gutachten stehen."
        )

    def evaluate(
        self, *, text: str, expectation: dict, structure: GutachtenReport
    ) -> Evaluation:
        base = self.fallback.evaluate(text=text, expectation=expectation, structure=structure)
        client = self.client or get_llm_client()
        if not getattr(client, "available", True):
            return base

        checkpoints = parse_expectation(expectation)
        try:
            response = client.complete(self._build_prompt(text, checkpoints), max_tokens=4000)
            parsed = json.loads(re.search(r"\{.*\}", response.text, re.S).group(0))
        except Exception:  # noqa: BLE001 - jeder Fehler fuehrt zum Fallback
            return base

        by_id = {c["id"]: c for c in parsed.get("checkpoints", []) if isinstance(c, dict)}
        results: list[PruefpunktResult] = []
        for cp in checkpoints:
            raw = by_id.get(cp.id, {})
            evidence = str(raw.get("evidence", ""))
            # Schutz gegen halluzinierte Belege: das Zitat muss im Text stehen.
            if evidence and _normalize(evidence) not in _normalize(text):
                evidence = ""
            results.append(
                PruefpunktResult(
                    id=cp.id,
                    label=cp.label,
                    weight=cp.weight,
                    hit=bool(raw.get("hit", False)),
                    evidence=evidence,
                    comment=str(raw.get("comment", "")),
                )
            )

        total_weight = sum(cp.weight for cp in checkpoints) or 1.0
        hits = sum(cp.weight for cp, r in zip(checkpoints, results, strict=True) if r.hit)
        content_ratio = hits / total_weight
        missed_required = [
            cp.label
            for cp, r in zip(checkpoints, results, strict=True)
            if cp.required and not r.hit
        ]
        raw_score = 0.72 * content_ratio + 0.28 * (structure.score / 100)
        points = round(raw_score * 18 * 2) / 2
        if missed_required:
            points = min(points, 3.5)

        return Evaluation(
            points=max(0.0, min(18.0, points)),
            note=note_fuer_punkte(points),
            content_ratio=round(content_ratio, 3),
            structure_score=structure.score,
            checkpoints=results,
            missed_required=missed_required,
            summary=str(parsed.get("summary", base.summary)),
            engine=self.name,
        )


def llm_configured(settings: Settings | None = None) -> bool:
    """Ob ein LLM-Provider grundsaetzlich aktiv ist (unabhaengig von Einwilligung).

    Basis fuer das Feature-Flag in ``GET /v1/public/config`` (SUB-133).
    """
    settings = settings or get_settings()
    return settings.llm_provider == "anthropic" and bool(settings.llm_api_key)


def get_evaluator(
    *, consented: bool = True, db: Session | None = None, user: User | None = None
) -> Evaluator:
    """Waehlt den Evaluator. ``consented=False`` erzwingt die Heuristik.

    Ohne Einwilligung wird ``LLMEvaluator`` gar nicht erst konstruiert - der
    Nutzertext verlaesst das System damit strukturell nicht in Richtung
    Provider, nicht nur durch ein Verhalten, das man auch vergessen koennte
    (SUB-133, Einwilligungs-Gate vor LLM-Versand).

    Kostenbremse (SUB-310): ist entweder das Fair-Use-Limit des Nutzers oder
    das globale Monatsbudget erreicht, wird ebenfalls lautlos auf die
    Heuristik zurueckgefallen - kein Fehler, kein 5xx, der Nutzer merkt nur
    eine andere Korrekturqualitaet (siehe ``app/services/limits.py``). Ohne
    ``db``/``user`` (z. B. der Kalibrierungs-Harness in
    ``scripts/kalibrierung_cli.py``, der ausserhalb eines Requests laeuft)
    greift die Kostenbremse nicht, da es dort keinen abzurechnenden Nutzer
    gibt.
    """
    settings = get_settings()
    if not (llm_configured(settings) and consented):
        return HeuristicEvaluator()
    if db is not None and user is not None:
        now = datetime.now(UTC)
        if limits.llm_user_quota_exceeded(db, user, now=now) or limits.llm_global_budget_exhausted(
            db, settings, now=now
        ):
            return HeuristicEvaluator()
        limits.record_llm_correction_call(db, user, now=now)
    return LLMEvaluator()
