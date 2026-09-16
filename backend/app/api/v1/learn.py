"""Karteikarten-Lernschleife: faellige Karten holen, Reviews zurueckspielen."""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Query
from sqlalchemy import or_, select

from app.api.deps import CurrentUser, DbSession
from app.config import get_settings
from app.core.timeutil import as_utc
from app.models import Card, Review, Topic, UserCard
from app.schemas import (
    CoverageOut,
    CoverageTopicOut,
    DueCardOut,
    ReviewBatchIn,
    ReviewBatchOut,
    ReviewResultOut,
)
from app.services import limits, srs

router = APIRouter(tags=["lernen"])

# Ab dieser Stabilitaet gilt eine Karte als "reif" - sie haelt ueber ein
# Semester und zaehlt fuer die Coverage.
MATURE_STABILITY_DAYS = 21.0


def _to_state(row: UserCard) -> srs.CardState:
    return srs.CardState(
        stability=row.stability,
        difficulty=row.difficulty,
        due=as_utc(row.due),
        last_review=as_utc(row.last_review),
        reps=row.reps,
        lapses=row.lapses,
        state=row.state,
    )


@router.get("/cards/due", response_model=list[DueCardOut])
def due_cards(
    user: CurrentUser,
    db: DbSession,
    limit: int = Query(default=20, ge=1, le=200),
    new_limit: int = Query(default=10, ge=0, le=100),
    topic: str | None = None,
) -> list[DueCardOut]:
    """Faellige Wiederholungen zuerst, danach neue Karten.

    Wiederholungen haben immer Vorrang: neuen Stoff aufzunehmen, waehrend
    Altes verfaellt, ist der teuerste Fehler im Jurastudium.

    Free-Tier-Limit (docs/20 B2): max. 20 faellige Karten/Tag, serverseitig
    ueber die Reviews des Tages gezaehlt statt ueber ``limit``, und nur ein
    Rechtsgebiet - das des ersten je gelernten Themas.
    """
    now = datetime.now(UTC)
    settings = get_settings()

    due_limit = limit
    area = None
    if limits.is_free_tier(user, settings, now=now):
        due_limit = min(limit, limits.due_cards_quota_remaining(db, user, now=now))
        area = limits.locked_area(db, user)
    area_topics = limits.area_topic_slugs(db, area) if area is not None else None

    query = (
        db.query(UserCard, Card)
        .join(Card, Card.id == UserCard.card_id)
        .filter(UserCard.user_id == user.id)
        .filter(or_(UserCard.due <= now, UserCard.content_changed.is_(True)))
    )
    if topic:
        query = query.filter(Card.topic_slug == topic)
    if area_topics is not None:
        query = query.filter(Card.topic_slug.in_(area_topics))
    faellig = query.order_by(UserCard.due).limit(due_limit).all()

    result = [
        DueCardOut(
            slug=card.slug,
            topic_slug=card.topic_slug,
            type=card.type,
            front=card.front,
            back=card.back,
            norms=card.norms or [],
            sources=card.sources or [],
            stand=card.stand,
            content_hash=card.content_hash,
            due=uc.due,
            state=uc.state,
            reps=uc.reps,
            content_changed=uc.content_changed,
        )
        for uc, card in faellig
    ]

    rest = min(new_limit, limit - len(result))
    if rest > 0:
        bekannt = select(UserCard.card_id).where(UserCard.user_id == user.id)
        neu_query = db.query(Card).filter(Card.id.not_in(bekannt))
        if topic:
            neu_query = neu_query.filter(Card.topic_slug == topic)
        if area_topics is not None:
            neu_query = neu_query.filter(Card.topic_slug.in_(area_topics))
        # Neue Karten nach Pruefungsrelevanz des Themas, nicht alphabetisch.
        relevanz = {t.slug: t.relevance for t in db.query(Topic).all()}
        neu = sorted(
            neu_query.limit(rest * 10).all(),
            key=lambda c: (-relevanz.get(c.topic_slug, 3), c.slug),
        )[:rest]
        result.extend(
            DueCardOut(
                slug=c.slug,
                topic_slug=c.topic_slug,
                type=c.type,
                front=c.front,
                back=c.back,
                norms=c.norms or [],
                sources=c.sources or [],
                stand=c.stand,
                content_hash=c.content_hash,
                state="new",
            )
            for c in neu
        )
    return result


@router.post("/reviews/batch", response_model=ReviewBatchOut)
def submit_reviews(payload: ReviewBatchIn, user: CurrentUser, db: DbSession) -> ReviewBatchOut:
    """Nimmt die Outbox des Clients entgegen - idempotent ueber ``client_id``.

    Doppelte Uebertragungen (Netzabbruch, Retry) werden still verworfen; der
    Client muss nicht wissen, was schon angekommen ist.
    """
    applied = duplicates = 0
    unknown: list[str] = []
    results: list[ReviewResultOut] = []

    for item in sorted(payload.reviews, key=lambda r: r.reviewed_at):
        if db.query(Review).filter_by(client_id=item.client_id).first():
            duplicates += 1
            continue
        card = db.query(Card).filter_by(slug=item.card_slug).one_or_none()
        if card is None:
            unknown.append(item.card_slug)
            continue

        row = db.query(UserCard).filter_by(user_id=user.id, card_id=card.id).one_or_none()
        if row is None:
            row = UserCard(user_id=user.id, card_id=card.id, due=item.reviewed_at)
            db.add(row)
            db.flush()

        reviewed_at = item.reviewed_at
        if reviewed_at.tzinfo is None:
            reviewed_at = reviewed_at.replace(tzinfo=UTC)

        new_state = srs.review(
            _to_state(row), item.rating, now=reviewed_at, card_type=card.type
        )
        row.stability = new_state.stability
        row.difficulty = new_state.difficulty
        row.due = new_state.due
        row.last_review = new_state.last_review
        row.reps = new_state.reps
        row.lapses = new_state.lapses
        row.state = new_state.state
        row.content_changed = False

        db.add(
            Review(
                client_id=item.client_id,
                user_id=user.id,
                card_id=card.id,
                rating=item.rating,
                reviewed_at=reviewed_at,
                elapsed_ms=item.elapsed_ms,
            )
        )
        applied += 1
        results.append(
            ReviewResultOut(
                card_slug=card.slug,
                accepted=True,
                due=new_state.due,
                state=new_state.state,
                stability_days=round(new_state.stability, 2),
            )
        )

    db.commit()
    return ReviewBatchOut(
        applied=applied, duplicates=duplicates, unknown_cards=unknown, results=results
    )


@router.get("/progress/coverage", response_model=CoverageOut)
def coverage(user: CurrentUser, db: DbSession) -> CoverageOut:
    """Wissenslandkarte: was kann ich wirklich schon? (Challenge 3)

    Bewusst ehrlich: gezaehlt wird nur, was reif ist - nicht, was schon einmal
    gesehen wurde.
    """
    topics = db.query(Topic).order_by(Topic.area, Topic.position).all()
    cards = db.query(Card).all()
    states = {
        uc.card_id: uc for uc in db.query(UserCard).filter(UserCard.user_id == user.id).all()
    }

    by_topic: dict[str, list[Card]] = {}
    for card in cards:
        by_topic.setdefault(card.topic_slug, []).append(card)

    rows: list[CoverageTopicOut] = []
    area_num: dict[str, float] = {}
    area_den: dict[str, float] = {}
    num = den = 0.0

    for topic in topics:
        topic_cards = by_topic.get(topic.slug, [])
        started = mature = 0
        for card in topic_cards:
            uc = states.get(card.id)
            if uc is None:
                continue
            started += 1
            if uc.stability >= MATURE_STABILITY_DAYS and uc.state == srs.State.REVIEW:
                mature += 1
        mastery = mature / len(topic_cards) if topic_cards else 0.0

        rows.append(
            CoverageTopicOut(
                slug=topic.slug,
                title=topic.title,
                area=topic.area,
                relevance=topic.relevance,
                cards_total=len(topic_cards),
                cards_started=started,
                cards_mature=mature,
                mastery=round(mastery, 3),
            )
        )
        num += topic.relevance * mastery
        den += topic.relevance
        area_num[topic.area] = area_num.get(topic.area, 0.0) + topic.relevance * mastery
        area_den[topic.area] = area_den.get(topic.area, 0.0) + topic.relevance

    return CoverageOut(
        weighted_coverage=round(num / den, 3) if den else 0.0,
        by_area={a: round(area_num[a] / area_den[a], 3) for a in area_num if area_den[a]},
        topics=rows,
    )


@router.get("/progress/forecast")
def forecast(user: CurrentUser, db: DbSession, days: int = Query(default=30, ge=1, le=365)) -> dict:
    """Wie viele Karten werden in den naechsten Tagen faellig?"""
    settings = get_settings()
    rows = db.query(UserCard).filter(UserCard.user_id == user.id).all()
    buckets = srs.forecast_load([_to_state(r) for r in rows], days)
    return {
        "days": days,
        "due_per_day": buckets,
        "minutes_per_day": [
            round(count * settings.seconds_per_card / 60) for count in buckets
        ],
    }
