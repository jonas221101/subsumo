"""Werkbank-Endpunkte: KI-generierte Lernwerkzeuge (SUB-308).

Siehe docs/27-werkbank-spezifikation.md.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.api.deps import DbSession
from app.services.slug_catalog import UnknownAreaError, build_slug_catalog

router = APIRouter(prefix="/werkbank", tags=["werkbank"])


@router.get("/slug-catalog")
def slug_catalog(db: DbSession, area: str) -> dict:
    """Begrenzter Slug-Katalog fuer den Generierungskontext (Ticket 1, SUB-366).

    Dient dem Systemprompt der Stufe 2 (Abschnitt 4.2) - nicht dem
    statischen `input_field.source`-Enum aus Abschnitt 3.1, das bereits im
    Tool-Spec-v2-Schema steht (`app/services/tool_spec.py`).
    """
    try:
        catalog = build_slug_catalog(db, area)
    except UnknownAreaError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return catalog.as_dict()
