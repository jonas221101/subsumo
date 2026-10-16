"""Auslieferung der Lerninhalte an die Clients."""

from __future__ import annotations

import hashlib
import json

from fastapi import APIRouter, Query

from app.api.deps import DbSession, OptionalUser
from app.models import Card, Case, Schema, Topic, User
from app.schemas import CardOut, CaseSummaryOut, SchemaOut, TopicOut

router = APIRouter(prefix="/content", tags=["content"])


def _content_version(cards: list[Card]) -> str:
    """Return a stable version for the complete card snapshot.

    Python's ``hash()`` is intentionally randomized between processes.  The
    client instead receives the SHA-256 of a canonical representation of all
    fields exposed by the card snapshot.
    """
    snapshot = [
        {
            "slug": card.slug,
            "topic_slug": card.topic_slug,
            "type": card.type,
            "front": card.front,
            "back": card.back,
            "norms": card.norms or [],
            "sources": card.sources or [],
            "stand": card.stand,
            "content_hash": card.content_hash,
        }
        for card in sorted(cards, key=lambda card: card.slug)
    ]
    canonical = json.dumps(snapshot, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


@router.get("/manifest")
def manifest(db: DbSession) -> dict:
    """Kennzahlen und stabile Version fuer den Karten-Snapshot-Sync."""
    cards = db.query(Card).all()
    return {
        "topics": db.query(Topic).count(),
        "cards": len(cards),
        "schemata": db.query(Schema).count(),
        "cases": db.query(Case).count(),
        "content_version": _content_version(cards),
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
    limit: int = Query(default=500, ge=1, le=10000),
    offset: int = Query(default=0, ge=0),
) -> list[Card]:
    query = db.query(Card)
    if topic:
        query = query.filter(Card.topic_slug == topic)
    if type:
        query = query.filter(Card.type == type)
    return query.order_by(Card.slug).offset(offset).limit(limit).all()


def topic_bundeslaender(db: DbSession) -> dict[str, str]:
    """Themen-Slug -> Bundesland-Code, nur fuer Landesrecht-Themen."""
    rows = db.query(Topic.slug, Topic.bundesland).filter(Topic.bundesland.isnot(None)).all()
    return {slug: land for slug, land in rows}


def annotate_bundesland(db: DbSession, items: list, user: User | None = None, *, filtern=False):
    """Setzt ``bundesland`` an Faellen/Schemata; filtert optional auf das Nutzerland.

    Landesrecht-Inhalte sieht nur, wer das passende Bundesland im Profil hat;
    ohne Nutzer oder ohne Bundesland bleibt nur das Bundesrecht (wie bei
    ``examen.visible_topics_query``).
    """
    lands = topic_bundeslaender(db)
    out = []
    for item in items:
        land = lands.get(item.topic_slug)
        if filtern and land is not None and (user is None or user.bundesland != land):
            continue
        item.bundesland = land
        out.append(item)
    return out


@router.get("/schemata", response_model=list[SchemaOut])
def schemata(
    db: DbSession, user: OptionalUser, area: str | None = None, topic: str | None = None
) -> list[Schema]:
    query = db.query(Schema)
    if area:
        query = query.filter(Schema.area == area)
    if topic:
        query = query.filter(Schema.topic_slug == topic)
    return annotate_bundesland(db, query.order_by(Schema.slug).all(), user, filtern=True)


@router.get("/cases", response_model=list[CaseSummaryOut])
def cases(
    db: DbSession,
    user: OptionalUser,
    area: str | None = None,
    max_difficulty: int | None = Query(default=None, ge=1, le=5),
) -> list[Case]:
    query = db.query(Case)
    if area:
        query = query.filter(Case.area == area)
    if max_difficulty:
        query = query.filter(Case.difficulty <= max_difficulty)
    return annotate_bundesland(
        db, query.order_by(Case.difficulty, Case.slug).all(), user, filtern=True
    )
