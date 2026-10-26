"""Lernprofil lesen und setzen (docs/33-individualisierung.md).

``PUT`` ersetzt das Profil komplett - der Client schickt immer den ganzen
Zustand, damit es keinen halb aktualisierten Zustand geben kann. Fachliche
Pruefung (Themen existieren, sind sichtbar, Fokus und Pause schliessen sich
aus) liegt in :func:`app.services.lernprofil.validate_topic_refs`.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, DbSession
from app.schemas import LernprofilIn, LernprofilOut
from app.services import examen, lernprofil

router = APIRouter(prefix="/me", tags=["lernprofil"])


def _out(user: CurrentUser) -> LernprofilOut:
    profil = lernprofil.get_profil(user)
    return LernprofilOut(
        **profil.model_dump(),
        eingerichtet=lernprofil.ist_eingerichtet(user),
        persona=lernprofil.persona(profil, user),
    )


@router.get("/lernprofil", response_model=LernprofilOut)
def get_lernprofil(user: CurrentUser) -> LernprofilOut:
    return _out(user)


@router.put("/lernprofil", response_model=LernprofilOut)
def put_lernprofil(payload: LernprofilIn, user: CurrentUser, db: DbSession) -> LernprofilOut:
    fehler = lernprofil.validate_topic_refs(db, payload, examen.visible_topic_slugs(db, user))
    if fehler:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "; ".join(fehler))
    user.lernprofil = payload.model_dump()
    db.add(user)
    db.commit()
    return _out(user)
