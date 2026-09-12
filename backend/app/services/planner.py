"""Adaptiver Lernplan bis zum Examenstermin.

Loest Challenge 5 (das Repetitorium verkauft vor allem Struktur und
Verbindlichkeit) und Challenge 9 (Ueberlastung ist der haeufigste Abbruchgrund).

Drei Eigenschaften, die einen brauchbaren von einem nutzlosen Plan trennen:

1. **Wiederholungen haben Vorrang.** Faellige Karten werden zuerst aus dem
   Tagesbudget bedient. Was nicht passt, wird nicht gestrichen, sondern als
   Rueckstand auf die Folgetage verteilt.
2. **Harte Tagesobergrenze.** Der Plan ueberschreitet das Nutzerbudget nie -
   ausser an ausdruecklich geplanten Klausurtagen. Ein Plan, den man nicht
   schaffen kann, wird nicht befolgt.
3. **Interleaving statt Blockung.** Rechtsgebiete werden abwechselnd geplant.
   Verschraenktes Lernen schneidet bei Transferaufgaben - und nichts anderes
   ist eine Klausur - besser ab als wochenlange Monoblöcke.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import date, timedelta

KLAUSUR_WEEKDAY = 5  # Samstag
PHASE_GRUNDLAGEN, PHASE_VERTIEFUNG, PHASE_ENDSPURT = "grundlagen", "vertiefung", "endspurt"
# Anteile am Zeitraum bis zum Examen.
PHASE_SPLIT = (0.55, 0.30)
# Mehr als 60 % des Tages fuer Wiederholungen frisst jeden Lernfortschritt.
MAX_REVIEW_SHARE = 0.6


@dataclass
class TopicInput:
    slug: str
    area: str
    title: str
    relevance: int = 3           # 1-5, kuratierte Pruefungsrelevanz
    mastery: float = 0.0         # 0..1, aus dem Kartenzustand abgeleitet

    @property
    def priority(self) -> float:
        """Hohe Relevanz und geringe Beherrschung zuerst."""
        return self.relevance * (1.0 - min(max(self.mastery, 0.0), 1.0))

    @property
    def budget_minutes(self) -> int:
        """Grobe Zeitschaetzung fuer einen Durchgang durch das Thema."""
        return 20 + self.relevance * 8


@dataclass
class PlanBlock:
    kind: str        # wiederholung | neu | fall | klausur | puffer
    title: str
    minutes: int
    topic_slug: str = ""
    area: str = ""


@dataclass
class PlanDay:
    day: date
    phase: str
    blocks: list[PlanBlock] = field(default_factory=list)
    review_backlog: int = 0      # nicht geschaffte faellige Karten

    @property
    def total_minutes(self) -> int:
        return sum(b.minutes for b in self.blocks)

    @property
    def is_klausurtag(self) -> bool:
        return any(b.kind == "klausur" for b in self.blocks)


@dataclass
class StudyPlan:
    days: list[PlanDay]
    exam_date: date
    daily_minutes: int
    covered_topics: list[str]
    uncovered_topics: list[str]
    klausur_count: int
    peak_backlog: int

    def to_dict(self) -> dict:
        return {
            "exam_date": self.exam_date.isoformat(),
            "daily_minutes": self.daily_minutes,
            "klausur_count": self.klausur_count,
            "peak_backlog": self.peak_backlog,
            "covered_topics": self.covered_topics,
            "uncovered_topics": self.uncovered_topics,
            "days": [
                {
                    "date": d.day.isoformat(),
                    "phase": d.phase,
                    "total_minutes": d.total_minutes,
                    "review_backlog": d.review_backlog,
                    "blocks": [
                        {
                            "kind": b.kind,
                            "title": b.title,
                            "minutes": b.minutes,
                            "topic_slug": b.topic_slug,
                            "area": b.area,
                        }
                        for b in d.blocks
                    ],
                }
                for d in self.days
            ],
        }


def _interleave_by_area(topics: list[TopicInput]) -> list[TopicInput]:
    """Round-Robin ueber die Rechtsgebiete, innerhalb je nach Prioritaet."""
    by_area: dict[str, list[TopicInput]] = {}
    for topic in sorted(topics, key=lambda t: (-t.priority, t.slug)):
        by_area.setdefault(topic.area, []).append(topic)

    ordered: list[TopicInput] = []
    areas = sorted(by_area, key=lambda a: -max(t.priority for t in by_area[a]))
    while any(by_area.values()):
        for area in areas:
            if by_area[area]:
                ordered.append(by_area[area].pop(0))
    return ordered


def _phase_for(index: int, total: int) -> str:
    if total <= 0:
        return PHASE_ENDSPURT
    ratio = index / total
    if ratio < PHASE_SPLIT[0]:
        return PHASE_GRUNDLAGEN
    if ratio < PHASE_SPLIT[0] + PHASE_SPLIT[1]:
        return PHASE_VERTIEFUNG
    return PHASE_ENDSPURT


def generate_plan(
    topics: list[TopicInput],
    *,
    start: date,
    exam_date: date,
    daily_minutes: int = 90,
    due_forecast: list[int] | None = None,
    seconds_per_card: int = 20,
    rest_weekdays: set[int] | None = None,
    horizon_days: int | None = None,
) -> StudyPlan:
    """Erzeugt einen Tagesplan von ``start`` bis ``exam_date``.

    ``due_forecast[i]`` ist die Zahl der an Tag ``i`` faellig werdenden Karten
    (aus :func:`app.services.srs.forecast_load`).
    """
    if exam_date <= start:
        raise ValueError("Das Examensdatum muss nach dem Startdatum liegen.")
    if daily_minutes < 15:
        raise ValueError("Ein Tagesbudget unter 15 Minuten ergibt keinen Plan.")

    total_days = (exam_date - start).days
    if horizon_days is not None:
        total_days = min(total_days, horizon_days)
    rest_weekdays = rest_weekdays or set()
    due_forecast = list(due_forecast or [])

    queue = [
        {"topic": t, "remaining": t.budget_minutes, "pass": 1}
        for t in _interleave_by_area(topics)
    ]
    # Zweiter Durchgang in verkuerzter Form - Wiederholung des Gelernten.
    second_pass = [
        {"topic": t, "remaining": max(15, t.budget_minutes // 2), "pass": 2}
        for t in _interleave_by_area([t for t in topics if t.relevance >= 3])
    ]

    days: list[PlanDay] = []
    backlog = 0
    covered: list[str] = []
    peak_backlog = 0

    for offset in range(total_days):
        current = start + timedelta(days=offset)
        phase = _phase_for(offset, total_days)
        day = PlanDay(day=current, phase=phase)

        if current.weekday() in rest_weekdays:
            day.review_backlog = backlog + (
                due_forecast[offset] if offset < len(due_forecast) else 0
            )
            backlog = day.review_backlog
            peak_backlog = max(peak_backlog, backlog)
            day.blocks.append(PlanBlock("puffer", "Ruhetag", 0))
            days.append(day)
            continue

        budget = daily_minutes

        # 1) Klausurtag - verdraengt alles andere, bewusst ueber Budget.
        if current.weekday() == KLAUSUR_WEEKDAY and phase != PHASE_GRUNDLAGEN:
            minutes = 300 if phase == PHASE_ENDSPURT else 120
            day.blocks.append(
                PlanBlock("klausur", f"Klausur unter Examensbedingungen ({minutes} min)", minutes)
            )
            day.review_backlog = backlog + (
                due_forecast[offset] if offset < len(due_forecast) else 0
            )
            backlog = day.review_backlog
            peak_backlog = max(peak_backlog, backlog)
            days.append(day)
            continue

        # 2) Wiederholungen zuerst, aber gedeckelt.
        due_today = backlog + (due_forecast[offset] if offset < len(due_forecast) else 0)
        if due_today:
            max_review_minutes = int(budget * MAX_REVIEW_SHARE)
            cards_per_minute = 60 / max(1, seconds_per_card)
            doable = int(max_review_minutes * cards_per_minute)
            done = min(due_today, doable)
            minutes = max(1, math.ceil(done / cards_per_minute))
            day.blocks.append(PlanBlock("wiederholung", f"{done} faellige Karten", minutes))
            budget -= minutes
            backlog = due_today - done
        else:
            backlog = 0
        day.review_backlog = backlog
        peak_backlog = max(peak_backlog, backlog)

        # 3) Rueckstand bremst die Aufnahme von Neuem - nicht umgekehrt.
        if backlog > 150:
            day.blocks.append(
                PlanBlock("puffer", "Rueckstand abbauen statt Neues anfangen", budget)
            )
            days.append(day)
            continue

        # 4) Restzeit fuer Stoff bzw. Faelle.
        source = queue if phase == PHASE_GRUNDLAGEN else (queue or second_pass)
        while budget >= 15 and source:
            item = source[0]
            topic: TopicInput = item["topic"]
            minutes = min(budget, item["remaining"])
            kind = "neu" if item["pass"] == 1 else "fall"
            label = topic.title if item["pass"] == 1 else f"Fall & Wiederholung: {topic.title}"
            day.blocks.append(PlanBlock(kind, label, minutes, topic.slug, topic.area))
            if topic.slug not in covered:
                covered.append(topic.slug)
            item["remaining"] -= minutes
            budget -= minutes
            if item["remaining"] <= 0:
                source.pop(0)
            source = queue if phase == PHASE_GRUNDLAGEN else (queue or second_pass)

        if budget >= 15:
            day.blocks.append(PlanBlock("puffer", "Freie Wiederholung / Puffer", budget))

        days.append(day)

    all_slugs = [t.slug for t in topics]
    return StudyPlan(
        days=days,
        exam_date=exam_date,
        daily_minutes=daily_minutes,
        covered_topics=covered,
        uncovered_topics=[s for s in all_slugs if s not in covered],
        klausur_count=sum(1 for d in days if d.is_klausurtag),
        peak_backlog=peak_backlog,
    )
