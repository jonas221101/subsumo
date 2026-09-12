"""Spaced-Repetition-Scheduler (FSRS-Variante).

Loest Challenge 2: Das Staatsexamen prueft kumulativ den Stoff aus acht bis zehn
Semestern. Ohne systematische Wiederholung ist der Stoff der ersten Semester zum
Examenszeitpunkt verloren.

Warum FSRS statt SM-2: FSRS modelliert pro Karte *Stabilitaet* (wie lange das
Gedaechtnis haelt) und *Schwierigkeit* getrennt und plant auf eine gewaehlte
Ziel-Retention. Das ergibt bei gleicher Behaltensleistung deutlich weniger
Wiederholungen - entscheidend, wenn ueber Jahre zehntausende Karten anfallen.

Das Modul ist bewusst frei von Datenbank- und Framework-Abhaengigkeiten: reine
Funktionen auf einem Zustandsobjekt, damit es identisch im Backend und (spaeter,
portiert) im Flutter-Client offline laufen kann.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, replace
from datetime import UTC, datetime, timedelta
from enum import IntEnum

# FSRS-4.5 Standardgewichte. Spaeter pro Nutzer aus dem eigenen Review-Verlauf
# optimierbar (Backlog M4).
DEFAULT_WEIGHTS: tuple[float, ...] = (
    0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.0310, 1.6474,
    0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.5870, 0.2272, 2.8755,
)

DECAY = -0.5
# FACTOR ist so gewaehlt, dass R(t=S) genau 0.9 ergibt.
FACTOR = 0.9 ** (1 / DECAY) - 1  # = 19/81

MIN_DIFFICULTY, MAX_DIFFICULTY = 1.0, 10.0
MIN_INTERVAL_DAYS = 1
MAX_INTERVAL_DAYS = 365 * 5  # Ein Studium dauert nicht ewig.

# Ziel-Retention je Kartentyp. Definitionen muessen woertlich sitzen,
# Rechtsprechung darf loechriger sein - das spart spuerbar Wiederholungszeit.
DESIRED_RETENTION_BY_TYPE: dict[str, float] = {
    "definition": 0.92,
    "schema_step": 0.90,
    "norm": 0.90,
    "streitstand": 0.88,
    "rechtsprechung": 0.85,
}
DEFAULT_RETENTION = 0.90

# Lernschritte fuer neue bzw. vergessene Karten (in Minuten), bevor die Karte in
# den Tagesrhythmus wechselt.
LEARNING_STEPS_MIN = (1, 10)
RELEARNING_STEPS_MIN = (10,)


class Rating(IntEnum):
    AGAIN = 1
    HARD = 2
    GOOD = 3
    EASY = 4


class State(str):
    NEW = "new"
    LEARNING = "learning"
    REVIEW = "review"
    RELEARNING = "relearning"


@dataclass(frozen=True)
class CardState:
    """Gedaechtniszustand einer Karte fuer einen Nutzer."""

    stability: float = 0.0
    difficulty: float = 0.0
    due: datetime | None = None
    last_review: datetime | None = None
    reps: int = 0
    lapses: int = 0
    state: str = State.NEW
    step: int = 0  # Index im Lernschritt-Array

    @property
    def is_new(self) -> bool:
        return self.state == State.NEW


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def retrievability(state: CardState, now: datetime) -> float:
    """Wahrscheinlichkeit, die Karte jetzt zu erinnern (0..1)."""
    if state.is_new or state.last_review is None or state.stability <= 0:
        return 0.0
    elapsed_days = max(0.0, (now - state.last_review).total_seconds() / 86400.0)
    return (1 + FACTOR * elapsed_days / state.stability) ** DECAY


def interval_for_retention(stability: float, desired_retention: float) -> float:
    """Tage, nach denen die Retrievability auf ``desired_retention`` faellt."""
    desired_retention = _clamp(desired_retention, 0.70, 0.99)
    return (stability / FACTOR) * (desired_retention ** (1 / DECAY) - 1)


def _initial_stability(rating: Rating, w: tuple[float, ...]) -> float:
    return max(0.1, w[rating - 1])


def _initial_difficulty(rating: Rating, w: tuple[float, ...]) -> float:
    return _clamp(w[4] - math.exp(w[5] * (rating - 1)) + 1, MIN_DIFFICULTY, MAX_DIFFICULTY)


def _next_difficulty(difficulty: float, rating: Rating, w: tuple[float, ...]) -> float:
    delta = difficulty - w[6] * (rating - 3)
    # Mittelwertrueckfuehrung zur Schwierigkeit einer "easy" beantworteten Karte:
    # verhindert, dass eine Karte durch eine Pechserie dauerhaft maximal schwer bleibt.
    reverted = w[7] * _initial_difficulty(Rating.EASY, w) + (1 - w[7]) * delta
    return _clamp(reverted, MIN_DIFFICULTY, MAX_DIFFICULTY)


def _stability_after_recall(
    stability: float, difficulty: float, r: float, rating: Rating, w: tuple[float, ...]
) -> float:
    hard_penalty = w[15] if rating == Rating.HARD else 1.0
    easy_bonus = w[16] if rating == Rating.EASY else 1.0
    growth = (
        math.exp(w[8])
        * (11 - difficulty)
        * (stability ** -w[9])
        * (math.exp(w[10] * (1 - r)) - 1)
        * hard_penalty
        * easy_bonus
    )
    return stability * (1 + growth)


def _stability_after_lapse(
    stability: float, difficulty: float, r: float, w: tuple[float, ...]
) -> float:
    lapsed = (
        w[11]
        * (difficulty ** -w[12])
        * ((stability + 1) ** w[13] - 1)
        * math.exp(w[14] * (1 - r))
    )
    # Vergessen darf die Stabilitaet nie erhoehen.
    return max(0.1, min(lapsed, stability))


def review(
    state: CardState,
    rating: Rating | int,
    *,
    now: datetime | None = None,
    desired_retention: float | None = None,
    card_type: str | None = None,
    weights: tuple[float, ...] = DEFAULT_WEIGHTS,
) -> CardState:
    """Verarbeitet eine Bewertung und liefert den neuen Kartenzustand.

    Reine Funktion: gleicher Input, gleicher Output. Das macht den Scheduler
    testbar und erlaubt es, den Kartenzustand jederzeit aus dem Review-Strom neu
    zu berechnen (siehe Sync-Strategie in docs/02-architektur.md).
    """
    rating = Rating(int(rating))
    now = now or datetime.now(UTC)
    if desired_retention is None:
        desired_retention = DESIRED_RETENTION_BY_TYPE.get(card_type or "", DEFAULT_RETENTION)
    w = weights

    if state.is_new:
        stability = _initial_stability(rating, w)
        difficulty = _initial_difficulty(rating, w)
        new_state = State.REVIEW if rating == Rating.EASY else State.LEARNING
    else:
        r = retrievability(state, now)
        difficulty = _next_difficulty(state.difficulty, rating, w)
        if rating == Rating.AGAIN:
            stability = _stability_after_lapse(state.stability, difficulty, r, w)
            new_state = State.RELEARNING
        else:
            stability = _stability_after_recall(state.stability, difficulty, r, rating, w)
            new_state = State.REVIEW

    # Kurzfristige Lernschritte: erst wenn sie durchlaufen sind, wechselt die
    # Karte in den Tagesrhythmus.
    if new_state in (State.LEARNING, State.RELEARNING) and rating != Rating.EASY:
        steps = LEARNING_STEPS_MIN if new_state == State.LEARNING else RELEARNING_STEPS_MIN
        idx = state.step if state.state == new_state else 0
        idx = 0 if rating == Rating.AGAIN else idx + 1
        if idx < len(steps):
            due = now + timedelta(minutes=steps[idx])
            return replace(
                state,
                stability=stability,
                difficulty=difficulty,
                due=due,
                last_review=now,
                reps=state.reps + 1,
                lapses=state.lapses + (1 if rating == Rating.AGAIN and not state.is_new else 0),
                state=new_state,
                step=idx,
            )
        new_state = State.REVIEW

    days = _clamp(
        round(interval_for_retention(stability, desired_retention)),
        MIN_INTERVAL_DAYS,
        MAX_INTERVAL_DAYS,
    )
    return replace(
        state,
        stability=stability,
        difficulty=difficulty,
        due=now + timedelta(days=days),
        last_review=now,
        reps=state.reps + 1,
        lapses=state.lapses + (1 if rating == Rating.AGAIN and not state.is_new else 0),
        state=new_state,
        step=0,
    )


def rebuild_from_reviews(
    events: list[tuple[Rating | int, datetime]],
    *,
    card_type: str | None = None,
    weights: tuple[float, ...] = DEFAULT_WEIGHTS,
) -> CardState:
    """Berechnet den Kartenzustand aus dem vollstaendigen Ereignisstrom neu.

    Das ist der Konfliktloeser fuer den Offline-Sync: treffen Reviews aus zwei
    Geraeten verspaetet ein, wird nicht gemerged, sondern in Zeitreihenfolge
    neu abgespielt.
    """
    state = CardState()
    for rating, at in sorted(events, key=lambda e: e[1]):
        state = review(state, rating, now=at, card_type=card_type, weights=weights)
    return state


def forecast_load(states: list[CardState], days: int, *, now: datetime | None = None) -> list[int]:
    """Anzahl faelliger Karten je Tag fuer die naechsten ``days`` Tage.

    Grundlage fuer das Load-Balancing im Lernplaner (Challenge 9): ein
    400-Karten-Rueckstand nach dem Urlaub ist der haeufigste Abbruchgrund.
    """
    now = now or datetime.now(UTC)
    buckets = [0] * days
    for st in states:
        if st.due is None:
            continue
        offset = (st.due - now).total_seconds() / 86400.0
        idx = max(0, math.floor(offset))
        if idx < days:
            buckets[idx] += 1
    return buckets
