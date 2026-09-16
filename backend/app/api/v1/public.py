"""Oeffentliche, unauthentifizierte Endpunkte fuer den Web-Client vor Login."""

from __future__ import annotations

from fastapi import APIRouter

from app.config import get_settings

router = APIRouter(prefix="/public", tags=["public"])


@router.get("/config")
def public_config() -> dict:
    """Feature-Flags, die die Preisseite (SUB-104) ohne Login braucht.

    Steuert dort die Umschaltung zwischen Variante A/B, siehe SUB-107.
    """
    return {"paywall_enabled": get_settings().paywall_enabled}
