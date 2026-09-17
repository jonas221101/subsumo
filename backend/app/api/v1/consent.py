"""Einwilligung zur KI-Korrektur (SUB-133).

Getrennt von ``account.py`` (Selbstauskunft/Loeschung), weil diese Einwilligung
eine eigene Rechtsgrundlage hat (Art. 6 Abs. 1 lit. a DSGVO) und jederzeit ohne
Angabe von Gruenden widerrufbar sein muss (Art. 7 Abs. 3 DSGVO) - unabhaengig
vom Konto selbst. Der Widerruf wirkt ab der naechsten Abgabe, siehe
``app/services/evaluator.py:get_evaluator``.
"""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, status

from app.api.deps import CurrentUser, DbSession
from app.schemas import AiConsentOut

router = APIRouter(prefix="/me", tags=["consent"])


@router.post("/ai-consent", response_model=AiConsentOut, status_code=status.HTTP_200_OK)
def grant_ai_consent(user: CurrentUser, db: DbSession) -> AiConsentOut:
    user.ai_review_consent_at = datetime.now(UTC)
    db.add(user)
    db.commit()
    return AiConsentOut(ai_review_consent_at=user.ai_review_consent_at)


@router.delete("/ai-consent", response_model=AiConsentOut)
def revoke_ai_consent(user: CurrentUser, db: DbSession) -> AiConsentOut:
    user.ai_review_consent_at = None
    db.add(user)
    db.commit()
    return AiConsentOut(ai_review_consent_at=None)
