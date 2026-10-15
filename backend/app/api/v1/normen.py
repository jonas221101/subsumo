"""Gesetzestext zu einem Normzitat (Tipp auf eine Normangabe in der App)."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query

from app.api.deps import CurrentUser
from app.services import normen

router = APIRouter(prefix="/normen", tags=["normen"])


@router.get("")
def norm_text(
    user: CurrentUser, zitat: str = Query(min_length=2, max_length=200)
) -> dict:
    """Liefert Gesetz, Titel und Text der (ersten) im Zitat genannten Norm.

    404 mit ``detail.quelle_url``, wenn die Norm nicht erfasst ist (Landesrecht,
    EU-Recht, unbekanntes Kuerzel oder nicht existierender Paragraph).
    """
    z = normen.parse_zitat(zitat)
    result = normen.lookup(z) if z else None
    if result is None:
        raise HTTPException(
            status_code=404,
            detail={
                "message": "Für diese Norm ist kein Text hinterlegt – "
                "Landesrecht oder nicht erfasst.",
                "quelle_url": normen.quelle_url(z),
            },
        )
    return result
