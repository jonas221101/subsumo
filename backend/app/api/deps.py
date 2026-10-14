"""Abhaengigkeiten der API-Schicht."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.config import get_settings
from app.core.security import TokenError, decode_access_token
from app.db import get_db
from app.models import User

DbSession = Annotated[Session, Depends(get_db)]


def get_current_user(
    db: DbSession,
    authorization: Annotated[str | None, Header()] = None,
) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            "Kein Bearer-Token übermittelt",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        payload = decode_access_token(authorization.split(" ", 1)[1].strip())
    except TokenError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(exc)) from exc

    user = db.get(User, int(payload["sub"]))
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Nutzer existiert nicht mehr")
    # Geschlossene Testphase (docs/35): ein gueltiges Token reicht nicht, die
    # Adresse muss auf der Liste stehen - so wirkt ein Entfernen sofort.
    allowlist = get_settings().beta_allowlist()
    if allowlist and user.email.lower() not in allowlist:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Kein Zugang zur Testphase")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
