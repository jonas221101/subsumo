"""Auslieferung der Lerninhalte an die Clients."""

from __future__ import annotations

from fastapi import APIRouter, Query

from app.api.deps import DbSession
from app.models import Card, Case, Schema, Topic
from app.schemas import CardOut, CaseSummaryOut, SchemaOut, TopicOut

router = APIRouter(prefix="/content", tags=["content"])


@router.get("/manifest")
def manifest(db: DbSession) -> dict:
    """Kennzahlen fuer den Delta-Sync des Clients."""
    cards = db.query(Card).all()
    return {
        "topics": db.query(Topic).count(),
        "cards": len(cards),
        "schemata": db.query(Schema).count(),
        "cases": db.query(Case).count(),
        # Aenderungen am Inhalt schlagen ueber die Hashes auf die Version durch.
        "content_version": str(hash(tuple(sorted(c.content_hash for c in cards))) & 0xFFFFFFFF),
    }


@router.get("/topics", response_model=list[TopicOut])
def topics(db: DbSession, area: str | None = None) -> list[Topic]:
    query = db.query(Topic)
    if area:
        query = query.filter(Topic.area == area)
    return query.order_by(Topic.area, Topic.position, Topic.slug).all()


@router.get("/cards", response_model=list[CardOut])
def cards(
    db: DbSession,
    topic: str | None = None,
    type: str | None = None,
    limit: int = Query(default=500, le=2000),
) -> list[Card]:
    query = db.query(Card)
    if topic:
        query = query.filter(Card.topic_slug == topic)
    if type:
        query = query.filter(Card.type == type)
    return query.order_by(Card.slug).limit(limit).all()


@router.get("/schemata", response_model=list[SchemaOut])
def schemata(db: DbSession, area: str | None = None, topic: str | None = None) -> list[Schema]:
    query = db.query(Schema)
    if area:
        query = query.filter(Schema.area == area)
    if topic:
        query = query.filter(Schema.topic_slug == topic)
    return query.order_by(Schema.slug).all()


@router.get("/cases", response_model=list[CaseSummaryOut])
def cases(
    db: DbSession,
    area: str | None = None,
    max_difficulty: int | None = Query(default=None, ge=1, le=5),
) -> list[Case]:
    query = db.query(Case)
    if area:
        query = query.filter(Case.area == area)
    if max_difficulty:
        query = query.filter(Case.difficulty <= max_difficulty)
    return query.order_by(Case.difficulty, Case.slug).all()
