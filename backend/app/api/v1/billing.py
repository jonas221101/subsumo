"""Stripe-Billing: Checkout, Webhook, Kuendigung + Widerruf (docs/20 B3/B4/B5)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import stripe
from fastapi import APIRouter, HTTPException, Request, status

from app.api.deps import CurrentUser, DbSession
from app.config import Settings, get_settings
from app.models import StripeWebhookEvent, User
from app.schemas import CancelSubscriptionOut, CheckoutSessionIn, CheckoutSessionOut
from app.services import billing

router = APIRouter(tags=["billing"])


@router.post("/billing/checkout-session", response_model=CheckoutSessionOut)
def create_checkout_session(payload: CheckoutSessionIn, user: CurrentUser, db: DbSession) -> dict:
    settings = get_settings()
    try:
        checkout_url = billing.create_checkout_session(user, payload.plan, settings)
    except billing.UnknownPlanError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Unbekannter Plan: {exc}") from exc
    return {"checkout_url": checkout_url}


@router.post("/billing/webhook")
async def stripe_webhook(request: Request, db: DbSession) -> dict:
    settings = get_settings()
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature", "")
    try:
        event = billing.construct_webhook_event(payload, sig_header, settings)
    except stripe.error.SignatureVerificationError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Ungueltige Signatur") from exc

    if db.get(StripeWebhookEvent, event["id"]) is not None:
        # Erneut zugestelltes Event - bereits verarbeitet, keine doppelte Wirkung.
        return {"received": True, "duplicate": True}

    _apply_webhook_event(db, event, settings)
    db.add(StripeWebhookEvent(event_id=event["id"], event_type=event["type"]))
    db.commit()
    return {"received": True}


def _apply_webhook_event(db: DbSession, event, settings: Settings) -> None:
    event_type = event["type"]
    data = event["data"]["object"]

    if event_type == "checkout.session.completed":
        client_reference_id = data.get("client_reference_id")
        if client_reference_id is None:
            return
        user = db.get(User, int(client_reference_id))
        if user is None:
            return
        subscription_id = data["subscription"]
        period_end_ts = billing.retrieve_subscription_current_period_end(subscription_id, settings)
        user.stripe_customer_id = data["customer"]
        user.stripe_subscription_id = subscription_id
        user.pro_until = datetime.fromtimestamp(period_end_ts, tz=UTC)
        user.subscription_started_at = datetime.now(UTC)
        user.cancel_at_period_end = False
        db.add(user)
    elif event_type == "invoice.payment_failed":
        # Stripe wiederholt selbst vor Ablauf der bezahlten Periode - kein
        # sofortiger Downgrade.
        pass
    elif event_type == "charge.dispute.created":
        customer_id = data.get("customer")
        user = db.query(User).filter_by(stripe_customer_id=customer_id).one_or_none()
        if user is not None:
            user.pro_until = datetime.now(UTC)
            db.add(user)
    elif event_type == "customer.subscription.updated":
        user = db.query(User).filter_by(stripe_subscription_id=data["id"]).one_or_none()
        if user is not None:
            user.cancel_at_period_end = bool(data.get("cancel_at_period_end"))
            db.add(user)
    elif event_type == "customer.subscription.deleted":
        user = db.query(User).filter_by(stripe_subscription_id=data["id"]).one_or_none()
        if user is not None:
            user.cancel_at_period_end = False
            db.add(user)


@router.post("/billing/cancel", response_model=CancelSubscriptionOut)
def cancel_subscription(user: CurrentUser, db: DbSession) -> dict:
    """Kuendigung (docs/20 B5).

    Widerrufsfall (Kauf <= 14 Tage her, docs/06-recht-compliance.md): sofortige
    Stornierung + volle Rueckerstattung. Sonst regulaer bis Periodenende.
    Ersetzt keine anwaltliche Pruefung der endgueltigen Widerrufsbelehrung
    (SUB-85).
    """
    if not user.stripe_subscription_id:
        raise HTTPException(status.HTTP_409_CONFLICT, "Kein aktives Abo")

    settings = get_settings()
    now = datetime.now(UTC)
    started_at = _as_aware(user.subscription_started_at) if user.subscription_started_at else None
    within_withdrawal_period = started_at is not None and now - started_at <= timedelta(
        days=settings.withdrawal_period_days
    )

    if within_withdrawal_period:
        billing.cancel_immediately_with_refund(user.stripe_subscription_id, settings)
        user.pro_until = now
        user.cancel_at_period_end = False
        db.add(user)
        db.commit()
        return {"mode": "immediate_refund"}

    billing.set_cancel_at_period_end(user.stripe_subscription_id, settings)
    user.cancel_at_period_end = True
    db.add(user)
    db.commit()
    return {"mode": "period_end"}


def _as_aware(value: datetime) -> datetime:
    return value if value.tzinfo is not None else value.replace(tzinfo=UTC)
