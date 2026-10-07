"""Registrierung, Login, Profil."""

from __future__ import annotations

from datetime import UTC, datetime, time

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import CurrentUser, DbSession
from app.config import get_settings
from app.core.ratelimit import enforce_login_rate_limit, enforce_register_rate_limit
from app.core.security import create_access_token, hash_password, verify_password
from app.models import DEFAULT_FACHRICHTUNG, Fachrichtung, Universitaet, User
from app.schemas import LoginIn, RegisterIn, TokenOut, UserOut, UserUpdateIn
from app.services.content import BUNDESLAND_CODES

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
        bundesland=user.bundesland,
        universitaet_slug=user.universitaet_slug,
        fachrichtung=user.fachrichtung or DEFAULT_FACHRICHTUNG,
        pro_active=pro_active,
        pro_until=user.pro_until,
        cancel_at_period_end=user.cancel_at_period_end,
        ai_review_consent_at=user.ai_review_consent_at,
    )


@router.post(
    "/register",
    response_model=TokenOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(enforce_register_rate_limit)],
)
def register(payload: RegisterIn, db: DbSession) -> TokenOut:
    email = payload.email.lower()
    if db.query(User).filter_by(email=email).first():
        raise HTTPException(status.HTTP_409_CONFLICT, "Diese E-Mail ist bereits registriert")
    user = User(
        email=email,
        password_hash=hash_password(payload.password),
        display_name=payload.display_name or email.split("@")[0],
        fachrichtung=_fachrichtung_or_422(db, payload.fachrichtung) or DEFAULT_FACHRICHTUNG,
    )
    db.add(user)
    db.commit()
    return TokenOut(access_token=create_access_token(str(user.id)))


def _fachrichtung_or_422(db: DbSession, slug: str | None) -> str | None:
    """Leer/None -> None (Default greift); unbekannt -> 422."""
    cleaned = (slug or "").strip().lower()
    if not cleaned:
        return None
    if cleaned != DEFAULT_FACHRICHTUNG and db.get(Fachrichtung, cleaned) is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY, f"Unbekannte Fachrichtung '{cleaned}'"
        )
    return cleaned


@router.post("/login", response_model=TokenOut, dependencies=[Depends(enforce_login_rate_limit)])
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
    if payload.fachrichtung is not None:
        neu = _fachrichtung_or_422(db, payload.fachrichtung) or DEFAULT_FACHRICHTUNG
        if neu != (user.fachrichtung or DEFAULT_FACHRICHTUNG):
            user.fachrichtung = neu
            # Universitaet und Lernprofil-Themen gehoeren zur alten
            # Fachrichtung - zuruecksetzen statt stillschweigend Unpassendes
            # zu behalten (docs/34 Abschnitt 4).
            uni = (
                db.query(Universitaet).filter_by(slug=user.universitaet_slug).one_or_none()
                if user.universitaet_slug
                else None
            )
            if uni is not None and neu not in (uni.data.get("fachrichtungen") or ["jura"]):
                user.universitaet_slug = None
            profil = dict(user.lernprofil or {})
            for feld in ("schwerpunkte", "themen_fokus", "themen_pausiert", "eigene_decks"):
                profil.pop(feld, None)
            user.lernprofil = profil
    if payload.bundesland is not None:
        code = payload.bundesland.strip().upper()
        if code and code not in BUNDESLAND_CODES:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_ENTITY, f"Unbekanntes Bundesland '{code}'"
            )
        user.bundesland = code or None
    if payload.universitaet_slug is not None:
        slug = payload.universitaet_slug.strip()
        uni = db.query(Universitaet).filter_by(slug=slug).one_or_none() if slug else None
        if slug and uni is None:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_ENTITY, f"Unbekannte Universitaet '{slug}'"
            )
        if uni is not None and (user.fachrichtung or DEFAULT_FACHRICHTUNG) not in (
            uni.data.get("fachrichtungen") or [DEFAULT_FACHRICHTUNG]
        ):
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_ENTITY,
                f"Universitaet '{slug}' bietet die Fachrichtung '{user.fachrichtung}' nicht an",
            )
        user.universitaet_slug = slug or None
        # Die Universitaet legt das Bundesland fest - sonst wuerde ein Nutzer
        # mit Uni Muenchen und Bundesland NW nordrhein-westfaelisches
        # Landesrecht lernen, aber die bayerische Klausurstruktur sehen.
        if uni is not None and payload.bundesland is None:
            user.bundesland = uni.bundesland
    db.add(user)
    db.commit()
    return _user_out(user)
