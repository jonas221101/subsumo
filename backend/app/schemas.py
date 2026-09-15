"""Pydantic-Schemata der oeffentlichen API."""

from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel, EmailStr, Field


class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=200)
    display_name: str = ""


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    id: int
    email: str
    display_name: str
    exam_date: datetime | None = None
    daily_minutes: int
    pro_active: bool = False
    pro_until: datetime | None = None
    cancel_at_period_end: bool = False


class UserUpdateIn(BaseModel):
    # Entitlement-Felder (pro_until, stripe_*, cancel_at_period_end) sind hier
    # bewusst nicht erlaubt - die werden ausschliesslich vom Stripe-Webhook (B4)
    # gesetzt, siehe docs/20-release-g2-bezahlstrecke.md Abschnitt 4 B1.
    display_name: str | None = None
    exam_date: date | None = None
    daily_minutes: int | None = Field(default=None, ge=15, le=600)


class TopicOut(BaseModel):
    slug: str
    area: str
    title: str
    parent_slug: str | None = None
    relevance: int


class CardOut(BaseModel):
    slug: str
    topic_slug: str
    type: str
    front: str
    back: str
    norms: list[str] = []
    sources: list[str] = []
    stand: str = ""
    content_hash: str = ""


class DueCardOut(CardOut):
    due: datetime | None = None
    state: str = "new"
    reps: int = 0
    content_changed: bool = False


class SchemaOut(BaseModel):
    slug: str
    topic_slug: str
    area: str
    title: str
    norms: list[str] = []
    steps: list = []
    sources: list[str] = []
    stand: str = ""


class CaseSummaryOut(BaseModel):
    slug: str
    topic_slug: str
    area: str
    title: str
    difficulty: int
    minutes: int


class CaseOut(CaseSummaryOut):
    facts: str
    question: str
    steps: list = []
    # Der Erwartungshorizont wird nicht ausgeliefert, solange nicht abgegeben
    # wurde - sonst waere jede Uebung wertlos.


class ReviewIn(BaseModel):
    client_id: str = Field(min_length=8, max_length=64)
    card_slug: str
    rating: int = Field(ge=1, le=4)
    reviewed_at: datetime
    elapsed_ms: int = 0


class ReviewBatchIn(BaseModel):
    reviews: list[ReviewIn] = Field(max_length=500)


class ReviewResultOut(BaseModel):
    card_slug: str
    accepted: bool
    due: datetime | None = None
    state: str = "new"
    stability_days: float = 0.0


class ReviewBatchOut(BaseModel):
    applied: int
    duplicates: int
    unknown_cards: list[str] = []
    results: list[ReviewResultOut] = []


class AnalyzeIn(BaseModel):
    text: str = Field(max_length=120_000)
    case_slug: str | None = None


class SubmissionIn(BaseModel):
    text: str = Field(min_length=1, max_length=120_000)
    mode: str = Field(default="uebung", pattern="^(uebung|klausur)$")
    duration_s: int = 0


class PlanIn(BaseModel):
    exam_date: date
    daily_minutes: int | None = Field(default=None, ge=15, le=600)
    rest_weekdays: list[int] = Field(default_factory=list)
    horizon_days: int | None = Field(default=None, ge=1, le=900)


class CoverageTopicOut(BaseModel):
    slug: str
    title: str
    area: str
    relevance: int
    cards_total: int
    cards_started: int
    cards_mature: int
    mastery: float


class CoverageOut(BaseModel):
    weighted_coverage: float
    by_area: dict[str, float]
    topics: list[CoverageTopicOut]


class AccountExportAccountOut(BaseModel):
    id: int
    email: str
    display_name: str
    exam_date: datetime | None = None
    daily_minutes: int
    created_at: datetime


class AccountExportUserCardOut(BaseModel):
    card_slug: str
    stability: float
    difficulty: float
    due: datetime
    last_review: datetime | None = None
    reps: int
    lapses: int
    state: str
    content_changed: bool


class AccountExportReviewOut(BaseModel):
    client_id: str
    card_slug: str
    rating: int
    reviewed_at: datetime
    elapsed_ms: int


class AccountExportSubmissionOut(BaseModel):
    id: int
    case_slug: str
    text: str
    mode: str
    duration_s: int
    structure_score: int
    points: float | None = None
    report: dict
    created_at: datetime


class AccountExportOut(BaseModel):
    """Selbstauskunft nach Art. 15 DSGVO - alle zur Nutzer-ID gespeicherten Daten."""

    exported_at: datetime
    account: AccountExportAccountOut
    user_cards: list[AccountExportUserCardOut] = []
    reviews: list[AccountExportReviewOut] = []
    submissions: list[AccountExportSubmissionOut] = []


class AccountDeleteIn(BaseModel):
    password: str
    confirm: bool = False
