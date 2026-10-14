"""Feedback aus der App (docs/35-geschlossene-testphase.md).

Zwei Endpunkte, beide nur angemeldet: Rueckmeldung absenden und die eigenen
Rueckmeldungen lesen. Es gibt bewusst keinen Client-Endpunkt zum Lesen
fremder Rueckmeldungen - der Betreiber liest auf dem Server
(``scripts/beta_users.py feedback``).
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, DbSession
from app.config import get_settings
from app.models import Feedback
from app.schemas import FeedbackIn, FeedbackOut

router = APIRouter(prefix="/feedback", tags=["feedback"])


def _out(row: Feedback) -> FeedbackOut:
    return FeedbackOut(
        id=row.id,
        category=row.category,
        message=row.message,
        context=row.context,
        created_at=row.created_at,
        erledigt=row.erledigt_at is not None,
    )


@router.post("", response_model=FeedbackOut, status_code=status.HTTP_201_CREATED)
def send_feedback(payload: FeedbackIn, user: CurrentUser, db: DbSession) -> FeedbackOut:
    seit = datetime.now(UTC) - timedelta(days=1)
    heute = (
        db.query(Feedback).filter(Feedback.user_id == user.id, Feedback.created_at >= seit).count()
    )
    if heute >= get_settings().feedback_max_per_day:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Tageslimit fuer Rueckmeldungen erreicht - morgen geht es weiter.",
        )
    row = Feedback(
        user_id=user.id,
        category=payload.category,
        message=payload.message,
        context=payload.context.strip(),
        platform=payload.platform.strip(),
        app_version=payload.app_version.strip(),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _out(row)


@router.get("/mine", response_model=list[FeedbackOut])
def my_feedback(user: CurrentUser, db: DbSession) -> list[FeedbackOut]:
    rows = (
        db.query(Feedback)
        .filter(Feedback.user_id == user.id)
        .order_by(Feedback.created_at.desc(), Feedback.id.desc())
        .limit(100)
        .all()
    )
    return [_out(r) for r in rows]
