"""Free-Tier-Limits (docs/20-release-g2-bezahlstrecke.md, Abschnitt 4 B2).

Limits unveraendert aus docs/19-kosten-preis-budget.md Abschnitt 4, nicht neu
erfunden. Sie wirken ausschliesslich bei ``paywall_enabled=True``; Pro-Nutzer
(``User.has_pro_access``) sind von allen drei Limits ausgenommen. Alle drei
Sperren nutzen dasselbe Fehlerformat (``upgrade_required: true``), damit der
Client (F1) gezielt reagieren kann statt auf generische Fehler.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import NoReturn

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import Settings
from app.core.timeutil import as_utc
from app.models import (
    AnalyzeCall,
    Card,
    Case,
    CaseAccess,
    LlmCorrectionCall,
    Review,
    Topic,
    User,
    UserCard,
)

FREE_DUE_CARDS_PER_DAY = 20
FREE_CASES = 2
FREE_ANALYZE_CALLS_PER_WEEK = 3
ANALYZE_WINDOW = timedelta(days=7)

# Kostenbremse LLM-Korrektur (SUB-310). 20/Monat ist keine neu erfundene
# Zahl, sondern die in docs/19-kosten-preis-budget.md Abschnitt 5 bereits
# festgelegte Fair-Use-Grenze ("Pro-Tarif mit Fair-Use von 20 Korrekturen pro
# Monat, darueber gedrosselt statt abgerechnet") - gilt unabhaengig vom
# Free/Pro-Status, denn die Kosten entstehen unabhaengig von der Paywall.
LLM_CORRECTIONS_PER_USER_PER_MONTH = 20
LLM_MONTHLY_WINDOW = timedelta(days=30)


def is_free_tier(user: User, settings: Settings, *, now: datetime | None = None) -> bool:
    """Notausgang (``paywall_enabled=False``) und Pro-Zugang schalten Limits ab."""
    if not settings.paywall_enabled:
        return False
    return not user.has_pro_access(now)


def _upgrade_required(reason: str, message: str, *, reset_at: datetime | None = None) -> NoReturn:
    """``message`` ist der vom Client (F1, ``app/lib/api.dart``) angezeigte Text -
    ohne dieses Feld faellt der Client auf die Dart-Map-Stringform des
    ``detail``-Objekts zurueck (SUB-121)."""
    detail: dict[str, object] = {"upgrade_required": True, "reason": reason, "message": message}
    if reset_at is not None:
        detail["reset_at"] = reset_at.isoformat()
    raise HTTPException(status.HTTP_403_FORBIDDEN, detail)


def due_cards_quota_remaining(db: Session, user: User, *, now: datetime) -> int:
    """Wie viele faellige Karten der Nutzer heute noch abrufen darf.

    Gezaehlt werden die tatsaechlich eingereichten Reviews des Tages, nicht
    der Client-``limit``-Parameter - der laesst sich sonst beliebig hochsetzen.
    """
    start_of_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
    reviewed_today = (
        db.query(Review)
        .filter(Review.user_id == user.id, Review.reviewed_at >= start_of_day)
        .count()
    )
    return max(0, FREE_DUE_CARDS_PER_DAY - reviewed_today)


def locked_area(db: Session, user: User) -> str | None:
    """Das Rechtsgebiet, auf das ein Free-Nutzer festgelegt ist.

    Ergibt sich aus der ersten Karte, mit der der Nutzer je gelernt hat - kein
    zusaetzliches Feld noetig. Vor der ersten Karte gibt es noch keine
    Festlegung, der Nutzer sieht dann alle Rechtsgebiete.
    """
    first = (
        db.query(UserCard).filter(UserCard.user_id == user.id).order_by(UserCard.id).first()
    )
    if first is None:
        return None
    card = db.get(Card, first.card_id)
    if card is None:
        return None
    topic = db.query(Topic).filter_by(slug=card.topic_slug).one_or_none()
    return topic.area if topic else None


def area_topic_slugs(db: Session, area: str):
    """Subquery mit allen Themen-Slugs eines Rechtsgebiets, fuer ``.in_()``."""
    return select(Topic.slug).where(Topic.area == area)


def enforce_case_access(db: Session, user: User, case: Case) -> None:
    """Free-Nutzer duerfen nur zwei unterschiedliche Faelle nutzen.

    Bereits gesehene Faelle bleiben immer erreichbar; erst der dritte *neue*
    Fall wird abgewiesen.
    """
    existing = db.query(CaseAccess).filter_by(user_id=user.id, case_id=case.id).one_or_none()
    if existing is not None:
        return
    used = db.query(CaseAccess).filter_by(user_id=user.id).count()
    if used >= FREE_CASES:
        _upgrade_required(
            "free_case_limit_reached",
            f"Ab dem {FREE_CASES + 1}. Fall nur mit Pro verfuegbar.",
        )
    db.add(CaseAccess(user_id=user.id, case_id=case.id))
    db.commit()


def enforce_analyze_quota(db: Session, user: User, *, now: datetime) -> None:
    """Free-Nutzer duerfen max. drei Struktur-Checks pro rollierender Woche."""
    window_start = now - ANALYZE_WINDOW
    calls = (
        db.query(AnalyzeCall)
        .filter(AnalyzeCall.user_id == user.id, AnalyzeCall.created_at >= window_start)
        .order_by(AnalyzeCall.created_at)
        .all()
    )
    if len(calls) >= FREE_ANALYZE_CALLS_PER_WEEK:
        reset_at = as_utc(calls[0].created_at)
        assert reset_at is not None
        reset_at += ANALYZE_WINDOW
        _upgrade_required(
            "free_analyze_limit_reached",
            f"Diese Woche schon {FREE_ANALYZE_CALLS_PER_WEEK} Analysen genutzt. "
            f"Reset am {reset_at.date().isoformat()}.",
            reset_at=reset_at,
        )
    db.add(AnalyzeCall(user_id=user.id, created_at=now))
    db.commit()


def llm_user_quota_exceeded(db: Session, user: User, *, now: datetime) -> bool:
    """Ob dieser Nutzer sein Fair-Use-Monatslimit fuer LLM-Korrekturen erreicht hat.

    Anders als ``enforce_analyze_quota`` wirft diese Funktion keinen 403 -
    eine Kostenbremse darf eine bezahlte Korrektur nie mit einem Fehler
    quittieren, nur mit stiller Qualitaetsminderung (siehe ``get_evaluator``).
    """
    window_start = now - LLM_MONTHLY_WINDOW
    count = (
        db.query(LlmCorrectionCall)
        .filter(LlmCorrectionCall.user_id == user.id, LlmCorrectionCall.created_at >= window_start)
        .count()
    )
    return count >= LLM_CORRECTIONS_PER_USER_PER_MONTH


def llm_global_budget_exhausted(db: Session, settings: Settings, *, now: datetime) -> bool:
    """Ob das monatliche Gesamtbudget fuer LLM-Kosten (ueber alle Nutzer) erreicht ist.

    Die realen Kosten je Aufruf sind ungemessen; das Budget wird deshalb ueber
    den konservativen Schaetzwert ``settings.llm_cost_estimate_eur`` in eine
    Aufrufobergrenze umgerechnet (siehe ``app/config.py``).
    """
    if settings.llm_cost_estimate_eur <= 0:
        return False
    window_start = now - LLM_MONTHLY_WINDOW
    count = db.query(LlmCorrectionCall).filter(LlmCorrectionCall.created_at >= window_start).count()
    max_calls = int(settings.llm_monthly_budget_eur / settings.llm_cost_estimate_eur)
    return count >= max_calls


def record_llm_correction_call(db: Session, user: User, *, now: datetime) -> None:
    """Zaehlt einen an ``LLMEvaluator`` dispatchten Aufruf fuer beide Kostenbremsen."""
    db.add(LlmCorrectionCall(user_id=user.id, created_at=now))
    db.commit()


__all__ = [
    "FREE_ANALYZE_CALLS_PER_WEEK",
    "FREE_CASES",
    "FREE_DUE_CARDS_PER_DAY",
    "LLM_CORRECTIONS_PER_USER_PER_MONTH",
    "area_topic_slugs",
    "due_cards_quota_remaining",
    "enforce_analyze_quota",
    "enforce_case_access",
    "is_free_tier",
    "llm_global_budget_exhausted",
    "llm_user_quota_exceeded",
    "locked_area",
    "record_llm_correction_call",
]
