"""Adaptiver Lernplan."""

from __future__ import annotations

from datetime import UTC, date, datetime

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, DbSession
from app.config import get_settings
from app.core.timeutil import as_utc
from app.models import Card, Topic, UserCard
from app.schemas import PlanIn
from app.services import srs
from app.services.planner import TopicInput, generate_plan

router = APIRouter(prefix="/plan", tags=["plan"])

MATURE_STABILITY_DAYS = 21.0


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

    cards_by_topic: dict[str, list[Card]] = {}
    for card in db.query(Card).all():
        cards_by_topic.setdefault(card.topic_slug, []).append(card)
    states = {
        uc.card_id: uc for uc in db.query(UserCard).filter(UserCard.user_id == user.id).all()
    }

    topics: list[TopicInput] = []
    for topic in db.query(Topic).order_by(Topic.position).all():
        topic_cards = cards_by_topic.get(topic.slug, [])
        mature = sum(
            1
            for c in topic_cards
            if (uc := states.get(c.id))
            and uc.stability >= MATURE_STABILITY_DAYS
            and uc.state == srs.State.REVIEW
        )
        topics.append(
            TopicInput(
                slug=topic.slug,
                area=topic.area,
                title=topic.title,
                relevance=topic.relevance,
                mastery=(mature / len(topic_cards)) if topic_cards else 0.0,
            )
        )

    horizon = payload.horizon_days or (payload.exam_date - date.today()).days
    card_states = [
        srs.CardState(
            stability=uc.stability,
            difficulty=uc.difficulty,
            due=as_utc(uc.due),
            last_review=as_utc(uc.last_review),
            reps=uc.reps,
            lapses=uc.lapses,
            state=uc.state,
        )
        for uc in states.values()
    ]
    due_forecast = srs.forecast_load(
        card_states, days=min(horizon, 400), now=datetime.now(UTC)
    )

    plan = generate_plan(
        topics,
        start=date.today(),
        exam_date=payload.exam_date,
        daily_minutes=daily,
        due_forecast=due_forecast,
        seconds_per_card=settings.seconds_per_card,
        rest_weekdays=set(payload.rest_weekdays),
        horizon_days=payload.horizon_days,
    )
    return plan.to_dict()
