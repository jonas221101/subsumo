"""Karteikarten-Lernschleife: faellige Karten holen, Reviews zurueckspielen."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import distinct, func, or_, select

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
from app.services import examen, lernprofil, limits, srs

router = APIRouter(tags=["lernen"])

# Ab dieser Stabilitaet gilt eine Karte als "reif" - sie haelt ueber ein
# Semester und zaehlt fuer die Coverage.
MATURE_STABILITY_DAYS = 21.0

# Zeitfenster fuer ``reviewed_at``: Die Offline-Outbox sendet Bewertungen der
# letzten Tage nach (7 Tage Puffer, z. B. Urlaub ohne Netz), Zukunft nur im
# Rahmen normaler Uhr-Abweichung.
REVIEW_MAX_AGE = timedelta(days=7)
REVIEW_FUTURE_TOLERANCE = timedelta(minutes=5)
# Antwortzeit: ueber 10 Minuten ist die Karte offen liegen geblieben.
MAX_ELAPSED_MS = 600_000


def _to_state(row: UserCard) -> srs.CardState:
    return srs.CardState(
        stability=row.stability,
        difficulty=row.difficulty,
        due=as_utc(row.due),
        last_review=as_utc(row.last_review),
        reps=row.reps,
        lapses=row.lapses,
        state=row.state,
        step=row.step or 0,
    )


def neue_karten_heute(db, user_id: int, start_of_day: datetime) -> int:
    """Karten, die der Nutzer heute (UTC-Kalendertag) zum ersten Mal bewertet hat."""
    heute = select(Review.card_id).where(
        Review.user_id == user_id, Review.reviewed_at >= start_of_day
    )
    frueher = select(Review.card_id).where(
        Review.user_id == user_id, Review.reviewed_at < start_of_day
    )
    return (
        db.query(func.count(distinct(Review.card_id)))
        .filter(Review.card_id.in_(heute), Review.card_id.not_in(frueher))
        .filter(Review.user_id == user_id)
        .scalar()
        or 0
    )


@router.get("/cards/due", response_model=list[DueCardOut])
def due_cards(
    response: Response,
    user: CurrentUser,
    db: DbSession,
    limit: int = Query(default=20, ge=1, le=200),
    new_limit: int | None = Query(default=None, ge=0, le=100),
    topic: str | None = None,
    deck: str | None = None,
    extra: bool = False,
) -> list[DueCardOut]:
    """Faellige Wiederholungen zuerst, danach neue Karten.

    Wiederholungen haben immer Vorrang: neuen Stoff aufzunehmen, waehrend
    Altes verfaellt, ist der teuerste Fehler im Jurastudium.

    Free-Tier-Limit (docs/20 B2): max. 20 faellige Karten/Tag, serverseitig
    ueber die Reviews des Tages gezaehlt statt ueber ``limit``, und nur ein
    Rechtsgebiet - das des ersten je gelernten Themas.

    ``deck`` (docs/32 Abschnitt 3.3) beschraenkt auf die Themen eines
    Kurs-Decks inklusive des Landesrechts des eigenen Bundeslands. Landesrecht
    anderer Laender ist nie dabei (:func:`examen.visible_topic_slugs`).

    Das Tageslimit neuer Karten (``new_limit`` bzw. Lernprofil
    ``neue_karten_pro_tag``) gilt pro UTC-Kalendertag: heute bereits erstmals
    bewertete Karten werden abgezogen. ``extra=true`` ("Weitere Karten lernen")
    ueberschreitet das Tageslimit bewusst und liefert bis zu ``new_limit``
    weitere neue Karten. Die Header ``X-Neue-Karten-Heute`` (heute begonnen) und
    ``X-Neue-Karten-Rest`` (Tageskontingent minus begonnen) informieren den Client.
    """
    now = datetime.now(UTC)
    settings = get_settings()

    # Unbekanntes Thema ist wie ein unbekanntes Deck ein 404, nicht eine leere Liste.
    if topic and db.query(Topic.id).filter(Topic.slug == topic).first() is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Thema nicht gefunden")

    # Lernprofil (docs/33): pausierte Themen fallen weg, neue Karten pro Tag
    # kommen aus dem Profil, Fokus/Schwerpunkt sortiert neue Karten nach vorn.
    profil = lernprofil.get_profil(user)
    if new_limit is None:
        new_limit = profil.neue_karten_pro_tag

    sichtbar = examen.visible_topic_slugs(db, user) - lernprofil.pausierte_themen(profil)
    if deck is not None:
        deck_topics = examen.deck_card_topic_slugs(db, user, deck)
        if deck_topics is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Deck nicht gefunden")
        sichtbar &= set(deck_topics)

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
    query = query.filter(Card.topic_slug.in_(sichtbar))
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

    start_of_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
    neu_heute = neue_karten_heute(db, user.id, start_of_day)
    tages_rest = max(0, new_limit - neu_heute)
    response.headers["X-Neue-Karten-Heute"] = str(neu_heute)
    response.headers["X-Neue-Karten-Rest"] = str(tages_rest)
    rest = min(new_limit if extra else tages_rest, limit - len(result))
    if rest > 0:
        bekannt = select(UserCard.card_id).where(UserCard.user_id == user.id)
        neu_query = db.query(Card).filter(Card.id.not_in(bekannt))
        neu_query = neu_query.filter(Card.topic_slug.in_(sichtbar))
        if topic:
            neu_query = neu_query.filter(Card.topic_slug == topic)
        if area_topics is not None:
            neu_query = neu_query.filter(Card.topic_slug.in_(area_topics))
        # Neue Karten nach Pruefungsrelevanz des Themas, nicht alphabetisch -
        # individuell gewichtet (Fokus-Thema, Schwerpunkt-Rechtsgebiet).
        gewicht = {
            t.slug: t.relevance * lernprofil.topic_weight(profil, t.slug, t.area)
            for t in db.query(Topic).all()
        }
        # Ueber alle ungesehenen Karten sortieren, nicht ueber eine
        # Vorauswahl - sonst laeuft ein Fokus-Thema am Ende des Alphabets
        # an der Gewichtung vorbei. Der Kartenbestand ist klein genug.
        stufen = examen.topic_stufen(db, user, profil)
        semester = examen.topic_semesters(db)
        areas = {t.slug: t.area for t in db.query(Topic).all()}
        fokus = set(profil.themen_fokus)
        schwerpunkte = set(profil.schwerpunkte)

        def sortierung(c):
            area = areas.get(c.topic_slug, "")
            return (
                0 if c.topic_slug in fokus else 1,
                stufen.get(c.topic_slug, 99 if stufen else 0),
                0 if area in schwerpunkte else 1,
                semester.get(c.topic_slug, 99) if stufen else 0,
                examen.GEBIET_RANG.get(area, 9),
                -gewicht.get(c.topic_slug, 3.0),
                c.slug,
            )

        neu = sorted(neu_query.all(), key=sortierung)[:rest]
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
    applied = duplicates = clamped = 0
    now = datetime.now(UTC)
    unknown: list[str] = []
    results: list[ReviewResultOut] = []
    # Sicherheitsniveau aus dem Lernprofil verschiebt die Ziel-Retention
    # (docs/33 Abschnitt 4.3) - identisch fuer jede Karte dieses Batches.
    profil = lernprofil.get_profil(user)

    def _aware(value: datetime) -> datetime:
        return value if value.tzinfo is not None else value.replace(tzinfo=UTC)

    for item in sorted(payload.reviews, key=lambda r: _aware(r.reviewed_at)):
        # Idempotenz pro Nutzer: dieselbe client_id eines anderen Nutzers ist
        # kein Duplikat.
        if db.query(Review).filter_by(user_id=user.id, client_id=item.client_id).first():
            duplicates += 1
            continue
        card = db.query(Card).filter_by(slug=item.card_slug).one_or_none()
        if card is None:
            unknown.append(item.card_slug)
            continue

        reviewed_at = _aware(item.reviewed_at)
        # Zeitstempel klemmen statt ablehnen: Ein abgelehnter Eintrag bliebe
        # fuer immer in der Offline-Outbox haengen und der Retry scheiterte
        # endlos. Uhr-Abweichungen des Geraets (Zukunft) und sehr alte
        # Eintraege werden auf die Grenze gesetzt, die Bewertung zaehlt.
        if reviewed_at > now + REVIEW_FUTURE_TOLERANCE:
            reviewed_at = now
            clamped += 1
        elif reviewed_at < now - REVIEW_MAX_AGE:
            reviewed_at = now - REVIEW_MAX_AGE
            clamped += 1

        row = db.query(UserCard).filter_by(user_id=user.id, card_id=card.id).one_or_none()
        if row is None:
            row = UserCard(user_id=user.id, card_id=card.id, due=reviewed_at)
            db.add(row)
            db.flush()

        # Eine rueckdatierte Bewertung (aelter als die juengste bekannte) wird
        # protokolliert, dreht den Kartenzustand aber nicht zurueck.
        last = as_utc(row.last_review)
        if last is not None and reviewed_at < last:
            db.add(
                Review(
                    client_id=item.client_id,
                    user_id=user.id,
                    card_id=card.id,
                    rating=item.rating,
                    reviewed_at=reviewed_at,
                    elapsed_ms=max(0, min(item.elapsed_ms, MAX_ELAPSED_MS)),
                )
            )
            applied += 1
            results.append(
                ReviewResultOut(
                    card_slug=card.slug,
                    accepted=True,
                    due=as_utc(row.due),
                    state=row.state,
                    stability_days=round(row.stability, 2),
                )
            )
            continue

        new_state = srs.review(
            _to_state(row),
            item.rating,
            now=reviewed_at,
            card_type=card.type,
            desired_retention=lernprofil.retention_for(profil, card.type),
        )
        row.stability = new_state.stability
        row.difficulty = new_state.difficulty
        row.due = new_state.due
        row.last_review = new_state.last_review
        row.reps = new_state.reps
        row.lapses = new_state.lapses
        row.state = new_state.state
        row.step = new_state.step
        row.content_changed = False

        db.add(
            Review(
                client_id=item.client_id,
                user_id=user.id,
                card_id=card.id,
                rating=item.rating,
                reviewed_at=reviewed_at,
                elapsed_ms=max(0, min(item.elapsed_ms, MAX_ELAPSED_MS)),
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
        applied=applied,
        duplicates=duplicates,
        unknown_cards=unknown,
        results=results,
        clamped=clamped,
    )


@router.get("/progress/coverage", response_model=CoverageOut)
def coverage(user: CurrentUser, db: DbSession) -> CoverageOut:
    """Wissenslandkarte: was kann ich wirklich schon? (Challenge 3)

    Bewusst ehrlich: gezaehlt wird nur, was reif ist - nicht, was schon einmal
    gesehen wurde.
    """
    # Landesrecht anderer Bundeslaender zaehlt nicht mit - sonst saehe jeder
    # Nutzer 15 Laender Stoff, den er nie lernen soll (docs/32 Abschnitt 4).
    topics = examen.visible_topics_query(db, user).order_by(Topic.area, Topic.position).all()
    cards = db.query(Card).all()
    states = {uc.card_id: uc for uc in db.query(UserCard).filter(UserCard.user_id == user.id).all()}

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
    now = datetime.now(UTC)
    # Gleiche Sichtbarkeit wie /cards/due: keine pausierten Themen, kein
    # Landesrecht anderer Laender; Tag 0 == aktuell faellige Karten.
    buckets = srs.forecast_load(examen.visible_card_states(db, user, now=now), days, now=now)
    return {
        "days": days,
        "due_per_day": buckets,
        "minutes_per_day": [round(count * settings.seconds_per_card / 60) for count in buckets],
    }
