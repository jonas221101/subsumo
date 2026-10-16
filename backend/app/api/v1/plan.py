"""Adaptiver Lernplan."""

from __future__ import annotations

from datetime import UTC, date, datetime

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, DbSession
from app.config import get_settings
from app.schemas import PlanIn
from app.services import examen, lernprofil, srs
from app.services.planner import generate_plan

router = APIRouter(prefix="/plan", tags=["plan"])


@router.post("")
def create_plan(payload: PlanIn, user: CurrentUser, db: DbSession) -> dict:
    """Erzeugt einen Tagesplan bis zum Examenstermin.

    Der Plan beruecksichtigt den tatsaechlichen Kartenbestand des Nutzers: die
    prognostizierte Wiederholungslast wird zuerst vom Tagesbudget abgezogen,
    erst der Rest geht in neuen Stoff.
    """
    if payload.exam_date <= date.today():
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY, "Das Examensdatum muss in der Zukunft liegen"
        )

    settings = get_settings()
    daily = payload.daily_minutes or user.daily_minutes or settings.default_daily_minutes

    # Nur sichtbare Themen: bundesrechtlicher Kern plus das Landesrecht des
    # eigenen Bundeslands (docs/32-examensvorbereitung.md Abschnitt 4).
    topics = examen.topic_inputs(db, user)
    now = datetime.now(UTC)
    card_states = examen.visible_card_states(db, user, now=now)

    horizon = payload.horizon_days or (payload.exam_date - date.today()).days
    due_forecast = srs.forecast_load(card_states, days=min(horizon, 400), now=now)

    # Rhythmus aus dem Lernprofil (docs/33); explizite Ruhetage im Aufruf
    # gewinnen, damit ein Client den Plan auch ad hoc durchrechnen kann.
    profil = lernprofil.get_profil(user)
    plan = generate_plan(
        topics,
        start=date.today(),
        exam_date=payload.exam_date,
        daily_minutes=daily,
        due_forecast=due_forecast,
        seconds_per_card=settings.seconds_per_card,
        rest_weekdays=set(payload.rest_weekdays or profil.ruhetage),
        horizon_days=payload.horizon_days,
        klausur_weekday=profil.klausur_wochentag,
        klausuren=profil.wochenklausur,
    )
    return plan.to_dict()
