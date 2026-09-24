"""DSGVO-Betroffenenrechte: Selbstauskunft (Art. 15) und Loeschung (Art. 17)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, DbSession
from app.core.security import verify_password
from app.models import (
    AnalyzeCall,
    Card,
    Case,
    CaseAccess,
    RedeemCode,
    RedeemCodeRedemption,
    Review,
    Submission,
    UserCard,
)
from app.schemas import (
    AccountDeleteIn,
    AccountExportAccountOut,
    AccountExportOut,
    AccountExportRedemptionOut,
    AccountExportReviewOut,
    AccountExportSubmissionOut,
    AccountExportUserCardOut,
    RedeemCodeIn,
    RedeemCodeOut,
)

router = APIRouter(prefix="/account", tags=["account"])


@router.get("/export", response_model=AccountExportOut)
def export_account(user: CurrentUser, db: DbSession) -> AccountExportOut:
    """Vollstaendige maschinenlesbare Selbstauskunft (Art. 15 DSGVO).

    Deckt alle zur Nutzer-ID gespeicherten und daraus abgeleiteten Daten ab:
    Konto, FSRS-Lernzustand, Review-Historie, abgegebene Gutachtentexte samt
    Bewertung sowie eingeloeste Freischaltcodes (SUB-270). Nur fuer das
    eigene, angemeldete Konto erreichbar.
    """
    card_slugs = dict(db.query(Card.id, Card.slug).all())
    case_slugs = dict(db.query(Case.id, Case.slug).all())
    campaign_slugs = dict(db.query(RedeemCode.id, RedeemCode.campaign_slug).all())

    user_cards = db.query(UserCard).filter_by(user_id=user.id).all()
    reviews = db.query(Review).filter_by(user_id=user.id).order_by(Review.reviewed_at).all()
    submissions = (
        db.query(Submission).filter_by(user_id=user.id).order_by(Submission.created_at).all()
    )
    redemptions = (
        db.query(RedeemCodeRedemption)
        .filter_by(user_id=user.id)
        .order_by(RedeemCodeRedemption.redeemed_at)
        .all()
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
            stripe_customer_id=user.stripe_customer_id,
            stripe_subscription_id=user.stripe_subscription_id,
            pro_until=user.pro_until,
            cancel_at_period_end=user.cancel_at_period_end,
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
        redemptions=[
            AccountExportRedemptionOut(
                campaign_slug=campaign_slugs.get(r.redeem_code_id, ""),
                redeemed_at=r.redeemed_at,
            )
            for r in redemptions
        ],
    )


@router.post("/delete")
def delete_account(payload: AccountDeleteIn, user: CurrentUser, db: DbSession) -> dict:
    """Vollstaendige Loeschung (Art. 17 DSGVO) - mit Bestaetigungsschritt.

    Der Bestaetigungsschritt verlangt neben ``confirm=true`` das aktuelle
    Passwort - das schuetzt vor versehentlicher Loeschung durch einen blossen
    Klick mit einem noch gueltigen Token. Entfernt alle personenbezogenen und
    nutzerbezogenen Daten (Konto, FSRS-Zustand, Reviews, Gutachtenabgaben,
    eingeloeste Freischaltcodes). Es gibt aktuell keine Daten, die aus
    Integritaetsgruenden anonymisiert erhalten bleiben muessten - keine
    Zahlungen, keine geteilten Aggregate, die auf einzelne Konten
    zurueckfuehren (siehe PR-Beschreibung SUB-84). Danach ist kein Login mit
    diesem Konto mehr moeglich.
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
    db.query(CaseAccess).filter_by(user_id=user.id).delete()
    db.query(AnalyzeCall).filter_by(user_id=user.id).delete()
    db.query(RedeemCodeRedemption).filter_by(user_id=user.id).delete()
    db.delete(user)
    db.commit()
    return {"deleted": True}


@router.post("/redeem", response_model=RedeemCodeOut)
def redeem_code(payload: RedeemCodeIn, user: CurrentUser, db: DbSession) -> RedeemCodeOut:
    """Freischaltcode einloesen (docs/28-freischaltcode-spezifikation.md Abschnitt 3).

    Kein Stripe-Aufruf - verlaengert nur ``User.pro_until``. 404 fuer
    unbekannten wie deaktivierten Code in einer Fehlermeldung, damit der
    Endpoint kein Orakel fuer gueltige Codes ist (Enumeration-Schutz).
    """
    normalized = payload.code.strip().upper()
    code = db.query(RedeemCode).filter_by(code=normalized).one_or_none()
    if code is None or not code.active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Code nicht gefunden")

    now = datetime.now(UTC)
    if code.expires_at is not None and _as_aware(code.expires_at) <= now:
        raise HTTPException(status.HTTP_410_GONE, "Code ist abgelaufen")

    already_redeemed = (
        db.query(RedeemCodeRedemption)
        .filter_by(redeem_code_id=code.id, user_id=user.id)
        .one_or_none()
    )
    if already_redeemed is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Code wurde bereits eingeloest")

    if code.max_redemptions is not None:
        redemption_count = (
            db.query(RedeemCodeRedemption).filter_by(redeem_code_id=code.id).count()
        )
        if redemption_count >= code.max_redemptions:
            raise HTTPException(status.HTTP_410_GONE, "Code ist ausgeschoepft")

    base = _as_aware(user.pro_until) if user.pro_until is not None else now
    user.pro_until = max(base, now) + timedelta(days=code.pro_duration_days)
    db.add(user)
    db.add(RedeemCodeRedemption(redeem_code_id=code.id, user_id=user.id))
    db.commit()
    return RedeemCodeOut(pro_until=user.pro_until)


def _as_aware(value: datetime) -> datetime:
    return value if value.tzinfo is not None else value.replace(tzinfo=UTC)
