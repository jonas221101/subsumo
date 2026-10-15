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

    Bei Mehrfachzitaten ("§§ 214, 215 BauGB") steht in ``weitere`` die Liste der
    uebrigen Normen. 404 mit ``detail.quelle_url`` und ``detail.kategorie``
    (``eu`` | ``landesrecht`` | ``nicht_erfasst``), wenn kein Text hinterlegt ist;
    ``quelle_url`` ist bei Landesrecht ohne erkennbares Land ``null`` (dann Liste ``portale``).
    """
    z = normen.parse_zitat(zitat)
    result = normen.lookup(z, zitat) if z else None
    if result is None:
        h = normen.herkunft(zitat)
        if h is not None:
            detail = {
                "message": h["message"],
                "kategorie": h["kategorie"],
                "quelle_url": h["quelle_url"],
            }
            if h.get("portale"):
                detail["portale"] = h["portale"]
            raise HTTPException(status_code=404, detail=detail)
        raise HTTPException(
            status_code=404,
            detail={
                "message": "Für diese Norm ist kein Text hinterlegt – "
                "Landesrecht oder nicht erfasst.",
                "kategorie": "nicht_erfasst",
                "quelle_url": normen.quelle_url(z),
            },
        )
    return result
