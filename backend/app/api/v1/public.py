"""Oeffentliche, unauthentifizierte Endpunkte fuer den Web-Client vor Login."""

from __future__ import annotations

from fastapi import APIRouter

from app.config import get_settings
from app.services.evaluator import llm_configured

router = APIRouter(prefix="/public", tags=["public"])


@router.get("/config")
def public_config() -> dict:
    """Feature-Flags, die der Client ohne Login braucht.

    ``paywall_enabled`` steuert die Umschaltung zwischen Variante A/B auf der
    Preisseite (SUB-104), siehe SUB-107. ``ai_correction_enabled`` (SUB-133)
    sagt, ob die KI-Korrektur ueberhaupt aktiv ist - unabhaengig von der
    Einwilligung des einzelnen Nutzers, die dieser eingeloggt ueber
    ``GET /v1/auth/me`` (Feld ``ai_review_consent_at``) abfragt.
    """
    settings = get_settings()
    return {
        "paywall_enabled": settings.paywall_enabled,
        "ai_correction_enabled": llm_configured(settings),
    }
