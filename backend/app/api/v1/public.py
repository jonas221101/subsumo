"""Oeffentliche, unauthentifizierte Endpunkte fuer den Web-Client vor Login."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import DbSession
from app.config import get_settings
from app.models import Fachrichtung
from app.services.evaluator import llm_configured

router = APIRouter(prefix="/public", tags=["public"])


@router.get("/config")
def public_config(db: DbSession) -> dict:
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
        # Fachrichtungen (docs/34) fuer Registrierung und Build-Flavor-Check
        # vor dem Login: Slug, Name und Oberflaechen-Begriffe.
        "fachrichtungen": [
            {
                "slug": f.slug,
                "name": f.name,
                "kurzname": f.data.get("kurzname", f.name),
                "begriffe": f.data.get("begriffe", {}),
            }
            for f in db.query(Fachrichtung).order_by(Fachrichtung.slug).all()
        ],
    }
