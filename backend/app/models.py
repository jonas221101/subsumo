"""Datenmodell.

Leitgedanke: ``reviews`` ist ein unveraenderlicher Ereignisstrom. ``user_cards``
ist der daraus abgeleitete Zustand und jederzeit neu berechenbar. Dadurch gibt
es beim Offline-Sync strukturell keine Merge-Konflikte (siehe
docs/02-architektur.md, Abschnitt 4).
"""

from __future__ import annotations

from datetime import UTC, datetime
from enum import StrEnum

from sqlalchemy import (
    JSON,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


def utcnow() -> datetime:
    return datetime.now(UTC)


class Area(StrEnum):
    """Die drei Rechtsgebiete der Pflichtfachpruefung."""

    ZIVILRECHT = "zivilrecht"
    STRAFRECHT = "strafrecht"
    OEFFENTLICHES_RECHT = "oeffentliches-recht"


class CardType(StrEnum):
    DEFINITION = "definition"
    SCHEMA_STEP = "schema_step"
    STREITSTAND = "streitstand"
    NORM = "norm"
    RECHTSPRECHUNG = "rechtsprechung"


class CardStateEnum(StrEnum):
    NEW = "new"
    LEARNING = "learning"
    REVIEW = "review"
    RELEARNING = "relearning"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str] = mapped_column(String(120), default="")
    # Zieltermin des Examens - Grundlage der Lernplanung.
    exam_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    daily_minutes: Mapped[int] = mapped_column(Integer, default=90)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    # Entitlement (Release G2, siehe docs/20-release-g2-bezahlstrecke.md Abschnitt 4 B1).
    # Ausschliesslich ueber den Stripe-Webhook (B4) geschrieben, nie per Client-Eingabe.
    stripe_customer_id: Mapped[str | None] = mapped_column(String(120), default=None)
    stripe_subscription_id: Mapped[str | None] = mapped_column(String(120), default=None)
    pro_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    cancel_at_period_end: Mapped[bool] = mapped_column(default=False)
    # Beginn des aktuellen Abo-Zeitraums, gesetzt vom Webhook (B4) bei
    # checkout.session.completed. Grundlage der 14-Tage-Widerrufsfrist in B5 -
    # bewusst getrennt von created_at (Registrierung != Kauf).
    subscription_started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), default=None
    )

    # Einwilligung zur KI-Korrektur (SUB-133). Kein Default-Ja - nur gesetzt,
    # wenn der Nutzer aktiv zugestimmt hat. Widerruf (Art. 7 Abs. 3 DSGVO)
    # setzt das Feld zurueck auf None, siehe app/api/v1/consent.py.
    ai_review_consent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), default=None
    )

    cards: Mapped[list[UserCard]] = relationship(back_populates="user")

    def has_pro_access(self, now: datetime | None = None) -> bool:
        """Rein zeitbasiert - kein Notausgang-Schalter, keine Client-Eingabe."""
        if self.pro_until is None:
            return False
        reference = now if now is not None else utcnow()
        pro_until = self.pro_until
        # SQLite gibt DateTime(timezone=True) als naiven Wert zurueck - ohne die
        # Normalisierung schlaegt der Vergleich mit dem tz-aware "reference" fehl.
        if pro_until.tzinfo is None:
            pro_until = pro_until.replace(tzinfo=UTC)
        return pro_until > reference


class Topic(Base):
    """Knoten der Wissenslandkarte (Challenge 3)."""

    __tablename__ = "topics"

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(160), unique=True, index=True)
    area: Mapped[str] = mapped_column(String(32), index=True)
    title: Mapped[str] = mapped_column(String(240))
    parent_slug: Mapped[str | None] = mapped_column(String(160), default=None, index=True)
    # Pruefungsrelevanz 1-5, kuratiert. Steuert Lernplan und Coverage-Gewichtung.
    relevance: Mapped[int] = mapped_column(Integer, default=3)
    position: Mapped[int] = mapped_column(Integer, default=0)


class Card(Base):
    __tablename__ = "cards"

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(200), unique=True, index=True)
    topic_slug: Mapped[str] = mapped_column(String(160), index=True)
    type: Mapped[str] = mapped_column(String(32), default=CardType.DEFINITION.value)
    front: Mapped[str] = mapped_column(Text)
    back: Mapped[str] = mapped_column(Text)
    norms: Mapped[list] = mapped_column(JSON, default=list)
    sources: Mapped[list] = mapped_column(JSON, default=list)
    stand: Mapped[str] = mapped_column(String(20), default="")
    # Inhaltshash: aendert sich der Inhalt, wird die Nutzerkarte als
    # "geaendert" markiert statt zurueckgesetzt (Challenge 10).
    content_hash: Mapped[str] = mapped_column(String(64), default="")


class UserCard(Base):
    """Abgeleiteter FSRS-Zustand einer Karte fuer einen Nutzer."""

    __tablename__ = "user_cards"
    __table_args__ = (UniqueConstraint("user_id", "card_id", name="uq_user_card"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    card_id: Mapped[int] = mapped_column(ForeignKey("cards.id"), index=True)

    stability: Mapped[float] = mapped_column(Float, default=0.0)
    difficulty: Mapped[float] = mapped_column(Float, default=0.0)
    due: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    last_review: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    reps: Mapped[int] = mapped_column(Integer, default=0)
    lapses: Mapped[int] = mapped_column(Integer, default=0)
    state: Mapped[str] = mapped_column(String(16), default=CardStateEnum.NEW.value)
    content_changed: Mapped[bool] = mapped_column(default=False)

    user: Mapped[User] = relationship(back_populates="cards")
    card: Mapped[Card] = relationship()


class Review(Base):
    """Unveraenderliches Lernereignis. ``client_id`` macht den Sync idempotent."""

    __tablename__ = "reviews"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    card_id: Mapped[int] = mapped_column(ForeignKey("cards.id"), index=True)
    rating: Mapped[int] = mapped_column(Integer)  # 1 again, 2 hard, 3 good, 4 easy
    reviewed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    elapsed_ms: Mapped[int] = mapped_column(Integer, default=0)


class Schema(Base):
    """Pruefungsschema, z. B. 'Anspruch aus Paragraph 433 II BGB'."""

    __tablename__ = "schemata"

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(200), unique=True, index=True)
    topic_slug: Mapped[str] = mapped_column(String(160), index=True)
    area: Mapped[str] = mapped_column(String(32), index=True)
    title: Mapped[str] = mapped_column(String(240))
    norms: Mapped[list] = mapped_column(JSON, default=list)
    steps: Mapped[list] = mapped_column(JSON, default=list)
    sources: Mapped[list] = mapped_column(JSON, default=list)
    stand: Mapped[str] = mapped_column(String(20), default="")


class Case(Base):
    """Uebungsfall mit Erwartungshorizont.

    Der Erwartungshorizont (``expectation``) ist die Grundlage jeder Bewertung -
    es gibt bewusst keinen Endpunkt, der freie Sachverhalte bewertet (RDG,
    siehe docs/06-recht-compliance.md).
    """

    __tablename__ = "cases"

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(200), unique=True, index=True)
    topic_slug: Mapped[str] = mapped_column(String(160), index=True)
    area: Mapped[str] = mapped_column(String(32), index=True)
    title: Mapped[str] = mapped_column(String(240))
    difficulty: Mapped[int] = mapped_column(Integer, default=2)  # 1 leicht - 5 Examen
    minutes: Mapped[int] = mapped_column(Integer, default=60)
    facts: Mapped[str] = mapped_column(Text)
    question: Mapped[str] = mapped_column(Text, default="")
    steps: Mapped[list] = mapped_column(JSON, default=list)
    expectation: Mapped[dict] = mapped_column(JSON, default=dict)
    sources: Mapped[list] = mapped_column(JSON, default=list)
    stand: Mapped[str] = mapped_column(String(20), default="")


class Submission(Base):
    """Abgegebenes Gutachten samt Bewertung."""

    __tablename__ = "submissions"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("cases.id"), index=True)
    text: Mapped[str] = mapped_column(Text)
    mode: Mapped[str] = mapped_column(String(20), default="uebung")  # uebung | klausur
    duration_s: Mapped[int] = mapped_column(Integer, default=0)
    structure_score: Mapped[int] = mapped_column(Integer, default=0)
    points: Mapped[float | None] = mapped_column(Float, default=None)  # JAP-Skala 0-18
    report: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class CaseAccess(Base):
    """Erster Zugriff eines Nutzers auf einen Fall.

    Grundlage fuer das Free-Tier-Limit "2 gefuehrte Faelle" (docs/20, Abschnitt
    4 B2): bereits gesehene Faelle bleiben erreichbar, nur der jeweils naechste
    *neue* Fall zaehlt gegen das Kontingent.
    """

    __tablename__ = "case_access"
    __table_args__ = (UniqueConstraint("user_id", "case_id", name="uq_case_access"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("cases.id"), index=True)
    first_seen: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class AnalyzeCall(Base):
    """Protokolliert Aufrufe von ``POST /gutachten/analyze``.

    Grundlage fuer das Free-Tier-Wochenlimit (docs/20, Abschnitt 4 B2) - ein
    rollierendes 7-Tage-Fenster statt eines Kalenderwochen-Resets.
    """

    __tablename__ = "analyze_calls"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, index=True
    )


class StripeWebhookEvent(Base):
    """Persistierte Stripe-Event-IDs (docs/20 B4).

    Macht erneut zugestellte Webhook-Events wirkungslos, analog zum
    ``client_id``-Muster bei ``reviews``.
    """

    __tablename__ = "stripe_webhook_events"

    event_id: Mapped[str] = mapped_column(String(255), primary_key=True)
    event_type: Mapped[str] = mapped_column(String(120))
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
