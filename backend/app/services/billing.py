"""Duenner Wrapper um die Stripe-SDK (docs/20-release-g2-bezahlstrecke.md B3/B4/B5).

Haelt die Stripe-Aufrufe an einer Stelle, damit die API-Schicht (`app.api.v1.billing`)
schlank bleibt und Tests einzelne Aufrufe gezielt mocken koennen.
"""

from __future__ import annotations

from typing import Any

import stripe

from app.config import Settings
from app.models import User

PLAN_MONTHLY = "monthly"
PLAN_YEARLY = "yearly"


class UnknownPlanError(ValueError):
    pass


def _price_id(plan: str, settings: Settings) -> str:
    if plan == PLAN_MONTHLY:
        return settings.stripe_price_monthly
    if plan == PLAN_YEARLY:
        return settings.stripe_price_yearly
    raise UnknownPlanError(plan)


def create_checkout_session(user: User, plan: str, settings: Settings) -> str:
    """Erstellt eine Stripe-Checkout-Session (Mode ``subscription``) und liefert die URL.

    Setzt bewusst kein Entitlement - das passiert ausschliesslich ueber den
    Webhook (B4), damit ein manipulierter Client sich hierueber keinen Zugriff
    verschaffen kann.
    """
    price_id = _price_id(plan, settings)
    stripe.api_key = settings.stripe_secret_key
    session = stripe.checkout.Session.create(
        mode="subscription",
        line_items=[{"price": price_id, "quantity": 1}],
        client_reference_id=str(user.id),
        customer=user.stripe_customer_id or None,
        success_url=settings.billing_success_url,
        cancel_url=settings.billing_cancel_url,
    )
    return session.url


def construct_webhook_event(payload: bytes, sig_header: str, settings: Settings) -> Any:
    """Prueft die Signatur gegen ``STRIPE_WEBHOOK_SECRET``.

    Wirft ``stripe.error.SignatureVerificationError`` bei ungueltiger Signatur -
    die API-Schicht uebersetzt das in ein 400 ohne DB-Schreibung.
    """
    stripe.api_key = settings.stripe_secret_key
    return stripe.Webhook.construct_event(payload, sig_header, settings.stripe_webhook_secret)


def retrieve_subscription_current_period_end(subscription_id: str, settings: Settings) -> int:
    """Unix-Timestamp des Endes der laufenden Abrechnungsperiode."""
    stripe.api_key = settings.stripe_secret_key
    subscription = stripe.Subscription.retrieve(subscription_id)
    return subscription["current_period_end"]


def set_cancel_at_period_end(subscription_id: str, settings: Settings) -> None:
    """Regulaerer Kuendigungsfall: Zugriff bleibt bis Periodenende."""
    stripe.api_key = settings.stripe_secret_key
    stripe.Subscription.modify(subscription_id, cancel_at_period_end=True)


def cancel_immediately_with_refund(subscription_id: str, settings: Settings) -> None:
    """Widerrufsfall: sofortige Stornierung und volle Rueckerstattung der letzten Zahlung."""
    stripe.api_key = settings.stripe_secret_key
    subscription = stripe.Subscription.retrieve(subscription_id)
    invoice_id = subscription["latest_invoice"]
    invoice = stripe.Invoice.retrieve(invoice_id)
    charge_id = invoice["charge"]
    stripe.Refund.create(charge=charge_id)
    stripe.Subscription.delete(subscription_id)
