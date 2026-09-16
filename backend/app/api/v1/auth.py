"""Registrierung, Login, Profil."""

from __future__ import annotations

from datetime import UTC, datetime, time

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, DbSession
from app.config import get_settings
from app.core.security import create_access_token, hash_password, verify_password
from app.models import User
from app.schemas import LoginIn, RegisterIn, TokenOut, UserOut, UserUpdateIn

router = APIRouter(prefix="/auth", tags=["auth"])


def _user_out(user: User) -> UserOut:
    # Notausgang: bei ausgeschalteter Paywall verhaelt sich jeder Nutzer wie
    # Pro, unabhaengig vom gespeicherten Entitlement (docs/20 Abschnitt 5).
    pro_active = user.has_pro_access() if get_settings().paywall_enabled else True
    return UserOut(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        exam_date=user.exam_date,
        daily_minutes=user.daily_minutes,
        pro_active=pro_active,
        pro_until=user.pro_until,
        cancel_at_period_end=user.cancel_at_period_end,
        ai_review_consent_at=user.ai_review_consent_at,
    )


@router.post("/register", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterIn, db: DbSession) -> TokenOut:
    email = payload.email.lower()
    if db.query(User).filter_by(email=email).first():
        raise HTTPException(status.HTTP_409_CONFLICT, "Diese E-Mail ist bereits registriert")
    user = User(
        email=email,
        password_hash=hash_password(payload.password),
        display_name=payload.display_name or email.split("@")[0],
    )
    db.add(user)
    db.commit()
    return TokenOut(access_token=create_access_token(str(user.id)))


@router.post("/login", response_model=TokenOut)
def login(payload: LoginIn, db: DbSession) -> TokenOut:
    user = db.query(User).filter_by(email=payload.email.lower()).first()
    # Dieselbe Meldung fuer unbekannte Nutzer und falsche Passwoerter -
    # sonst laesst sich ueber die API herausfinden, wer registriert ist.
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "E-Mail oder Passwort ist falsch")
    return TokenOut(access_token=create_access_token(str(user.id)))


@router.get("/me", response_model=UserOut)
def me(user: CurrentUser) -> UserOut:
    return _user_out(user)


@router.patch("/me", response_model=UserOut)
def update_me(payload: UserUpdateIn, user: CurrentUser, db: DbSession) -> UserOut:
    if payload.display_name is not None:
        user.display_name = payload.display_name
    if payload.daily_minutes is not None:
        user.daily_minutes = payload.daily_minutes
    if payload.exam_date is not None:
        user.exam_date = datetime.combine(payload.exam_date, time.min, tzinfo=UTC)
    db.add(user)
    db.commit()
    return _user_out(user)
