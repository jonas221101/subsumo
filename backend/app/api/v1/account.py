"""DSGVO-Betroffenenrechte: Selbstauskunft (Art. 15) und Loeschung (Art. 17)."""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, DbSession
from app.core.security import verify_password
from app.models import Card, Case, Review, Submission, UserCard
from app.schemas import (
    AccountDeleteIn,
    AccountExportAccountOut,
    AccountExportOut,
    AccountExportReviewOut,
    AccountExportSubmissionOut,
    AccountExportUserCardOut,
)

router = APIRouter(prefix="/account", tags=["account"])


@router.get("/export", response_model=AccountExportOut)
def export_account(user: CurrentUser, db: DbSession) -> AccountExportOut:
    """Vollstaendige maschinenlesbare Selbstauskunft (Art. 15 DSGVO).

    Deckt alle zur Nutzer-ID gespeicherten und daraus abgeleiteten Daten ab:
    Konto, FSRS-Lernzustand, Review-Historie und abgegebene Gutachtentexte
    samt Bewertung. Nur fuer das eigene, angemeldete Konto erreichbar.
    """
    card_slugs = dict(db.query(Card.id, Card.slug).all())
    case_slugs = dict(db.query(Case.id, Case.slug).all())

    user_cards = db.query(UserCard).filter_by(user_id=user.id).all()
    reviews = db.query(Review).filter_by(user_id=user.id).order_by(Review.reviewed_at).all()
    submissions = (
        db.query(Submission).filter_by(user_id=user.id).order_by(Submission.created_at).all()
    )

    return AccountExportOut(
        exported_at=datetime.now(UTC),
        account=AccountExportAccountOut(
            id=user.id,
            email=user.email,
            display_name=user.display_name,
            exam_date=user.exam_date,
            daily_minutes=user.daily_minutes,
            created_at=user.created_at,
        ),
        user_cards=[
            AccountExportUserCardOut(
                card_slug=card_slugs.get(uc.card_id, ""),
                stability=uc.stability,
                difficulty=uc.difficulty,
                due=uc.due,
                last_review=uc.last_review,
                reps=uc.reps,
                lapses=uc.lapses,
                state=uc.state,
                content_changed=uc.content_changed,
            )
            for uc in user_cards
        ],
        reviews=[
            AccountExportReviewOut(
                client_id=r.client_id,
                card_slug=card_slugs.get(r.card_id, ""),
                rating=r.rating,
                reviewed_at=r.reviewed_at,
                elapsed_ms=r.elapsed_ms,
            )
            for r in reviews
        ],
        submissions=[
            AccountExportSubmissionOut(
                id=s.id,
                case_slug=case_slugs.get(s.case_id, ""),
                text=s.text,
                mode=s.mode,
                duration_s=s.duration_s,
                structure_score=s.structure_score,
                points=s.points,
                report=s.report,
                created_at=s.created_at,
            )
            for s in submissions
        ],
    )


@router.post("/delete")
def delete_account(payload: AccountDeleteIn, user: CurrentUser, db: DbSession) -> dict:
    """Vollstaendige Loeschung (Art. 17 DSGVO) - mit Bestaetigungsschritt.

    Der Bestaetigungsschritt verlangt neben ``confirm=true`` das aktuelle
    Passwort - das schuetzt vor versehentlicher Loeschung durch einen blossen
    Klick mit einem noch gueltigen Token. Entfernt alle personenbezogenen und
    nutzerbezogenen Daten (Konto, FSRS-Zustand, Reviews, Gutachtenabgaben).
    Es gibt aktuell keine Daten, die aus Integritaetsgruenden anonymisiert
    erhalten bleiben muessten - keine Zahlungen, keine geteilten Aggregate,
    die auf einzelne Konten zurueckfuehren (siehe PR-Beschreibung SUB-84).
    Danach ist kein Login mit diesem Konto mehr moeglich.
    """
    if not payload.confirm:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "Bestaetigung erforderlich (confirm=true)"
        )
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Passwort ist falsch")

    db.query(Review).filter_by(user_id=user.id).delete()
    db.query(UserCard).filter_by(user_id=user.id).delete()
    db.query(Submission).filter_by(user_id=user.id).delete()
    db.delete(user)
    db.commit()
    return {"deleted": True}
