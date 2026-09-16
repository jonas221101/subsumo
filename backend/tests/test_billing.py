"""Stripe-Billing: Checkout, Webhook, Kuendigung + Widerruf (SUB-97/98/99, docs/20 B3/B4/B5).

Stripe wird durchgehend gemockt - es gibt keinen Netzwerkzugriff auf die
Stripe-API in Tests, nur die Wrapper-Funktionen in ``app.services.billing``.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import stripe

import app.services.billing as billing_service


def _user_id(client) -> int:
    return client.get("/v1/auth/me").json()["id"]


def _set_subscription(
    client,
    *,
    user_id: int,
    stripe_subscription_id: str | None,
    subscription_started_at: datetime | None,
    pro_until: datetime | None = None,
) -> None:
    import app.db as db_module
    from app.models import User

    with db_module.SessionLocal() as db:
        user = db.get(User, user_id)
        user.stripe_subscription_id = stripe_subscription_id
        user.subscription_started_at = subscription_started_at
        if pro_until is not None:
            user.pro_until = pro_until
        db.add(user)
        db.commit()


# --------------------------------------------------------------------------- #
# POST /billing/checkout-session (SUB-97 / B3)
# --------------------------------------------------------------------------- #


def test_checkout_session_requires_auth(client):
    response = client.post("/v1/billing/checkout-session", json={"plan": "monthly"})
    assert response.status_code == 401


def test_checkout_session_unbekannter_plan_ist_400(auth_client):
    response = auth_client.post("/v1/billing/checkout-session", json={"plan": "lifetime"})
    assert response.status_code == 400


def test_checkout_session_nutzt_korrekte_price_id_je_plan(auth_client, monkeypatch):
    captured: dict = {}

    class FakeSession:
        url = "https://checkout.stripe.com/test-session"

    def fake_create(**kwargs):
        captured.update(kwargs)
        return FakeSession()

    monkeypatch.setattr(stripe.checkout.Session, "create", fake_create)

    from app.config import get_settings

    settings = get_settings()

    response = auth_client.post("/v1/billing/checkout-session", json={"plan": "monthly"})
    assert response.status_code == 200
    assert response.json()["checkout_url"] == "https://checkout.stripe.com/test-session"
    assert captured["line_items"][0]["price"] == settings.stripe_price_monthly
    assert captured["mode"] == "subscription"

    response = auth_client.post("/v1/billing/checkout-session", json={"plan": "yearly"})
    assert response.status_code == 200
    assert captured["line_items"][0]["price"] == settings.stripe_price_yearly


# --------------------------------------------------------------------------- #
# POST /billing/webhook (SUB-98 / B4)
# --------------------------------------------------------------------------- #


def _fake_event(event_id: str, event_type: str, data_object: dict) -> dict:
    return {"id": event_id, "type": event_type, "data": {"object": data_object}}


def test_webhook_ungueltige_signatur_ist_400_ohne_db_schreibung(auth_client, monkeypatch):
    def fake_construct(payload, sig_header, settings):
        raise stripe.error.SignatureVerificationError("bad signature", sig_header)

    monkeypatch.setattr(billing_service, "construct_webhook_event", fake_construct)

    response = auth_client.post(
        "/v1/billing/webhook", content=b"{}", headers={"stripe-signature": "invalid"}
    )
    assert response.status_code == 400

    import app.db as db_module
    from app.models import StripeWebhookEvent

    with db_module.SessionLocal() as db:
        assert db.query(StripeWebhookEvent).count() == 0


def test_webhook_checkout_session_completed_setzt_entitlement(auth_client, monkeypatch):
    user_id = _user_id(auth_client)
    period_end = datetime.now(UTC) + timedelta(days=30)
    event = _fake_event(
        "evt_1",
        "checkout.session.completed",
        {
            "client_reference_id": str(user_id),
            "customer": "cus_123",
            "subscription": "sub_123",
        },
    )
    monkeypatch.setattr(
        billing_service, "construct_webhook_event", lambda payload, sig, settings: event
    )
    monkeypatch.setattr(
        billing_service,
        "retrieve_subscription_current_period_end",
        lambda sub_id, settings: int(period_end.timestamp()),
    )

    response = auth_client.post(
        "/v1/billing/webhook", content=b"{}", headers={"stripe-signature": "valid"}
    )
    assert response.status_code == 200

    me = auth_client.get("/v1/auth/me").json()
    assert me["pro_active"] is True
    assert me["cancel_at_period_end"] is False


def test_webhook_dasselbe_event_zweimal_wirkt_nicht_doppelt(auth_client, monkeypatch):
    user_id = _user_id(auth_client)
    calls = {"n": 0}
    event = _fake_event(
        "evt_dup",
        "checkout.session.completed",
        {"client_reference_id": str(user_id), "customer": "cus_1", "subscription": "sub_1"},
    )

    def fake_period_end(sub_id, settings):
        calls["n"] += 1
        return int((datetime.now(UTC) + timedelta(days=30)).timestamp())

    monkeypatch.setattr(
        billing_service, "construct_webhook_event", lambda payload, sig, settings: event
    )
    monkeypatch.setattr(
        billing_service, "retrieve_subscription_current_period_end", fake_period_end
    )

    first = auth_client.post(
        "/v1/billing/webhook", content=b"{}", headers={"stripe-signature": "valid"}
    )
    second = auth_client.post(
        "/v1/billing/webhook", content=b"{}", headers={"stripe-signature": "valid"}
    )
    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json().get("duplicate") is True
    assert calls["n"] == 1


def test_webhook_invoice_payment_failed_kein_sofortiger_downgrade(auth_client, monkeypatch):
    user_id = _user_id(auth_client)
    future = datetime.now(UTC) + timedelta(days=10)
    _set_subscription(
        auth_client,
        user_id=user_id,
        stripe_subscription_id="sub_1",
        subscription_started_at=datetime.now(UTC),
        pro_until=future,
    )
    event = _fake_event("evt_fail", "invoice.payment_failed", {"customer": "cus_1"})
    monkeypatch.setattr(
        billing_service, "construct_webhook_event", lambda payload, sig, settings: event
    )

    response = auth_client.post(
        "/v1/billing/webhook", content=b"{}", headers={"stripe-signature": "valid"}
    )
    assert response.status_code == 200
    assert auth_client.get("/v1/auth/me").json()["pro_active"] is True


def test_webhook_charge_dispute_created_entzieht_sofort(auth_client, monkeypatch):
    from app.config import get_settings

    monkeypatch.setenv("SUBSUMO_PAYWALL_ENABLED", "true")
    get_settings.cache_clear()

    user_id = _user_id(auth_client)
    future = datetime.now(UTC) + timedelta(days=10)
    _set_subscription(
        auth_client,
        user_id=user_id,
        stripe_subscription_id="sub_1",
        subscription_started_at=datetime.now(UTC),
        pro_until=future,
    )
    import app.db as db_module
    from app.models import User

    with db_module.SessionLocal() as db:
        db.query(User).filter_by(id=user_id).update({"stripe_customer_id": "cus_1"})
        db.commit()

    event = _fake_event("evt_dispute", "charge.dispute.created", {"customer": "cus_1"})
    monkeypatch.setattr(
        billing_service, "construct_webhook_event", lambda payload, sig, settings: event
    )

    response = auth_client.post(
        "/v1/billing/webhook", content=b"{}", headers={"stripe-signature": "valid"}
    )
    assert response.status_code == 200
    assert auth_client.get("/v1/auth/me").json()["pro_active"] is False


def test_webhook_subscription_updated_setzt_cancel_flag(auth_client, monkeypatch):
    user_id = _user_id(auth_client)
    _set_subscription(
        auth_client,
        user_id=user_id,
        stripe_subscription_id="sub_1",
        subscription_started_at=datetime.now(UTC),
        pro_until=datetime.now(UTC) + timedelta(days=10),
    )
    event = _fake_event(
        "evt_upd", "customer.subscription.updated", {"id": "sub_1", "cancel_at_period_end": True}
    )
    monkeypatch.setattr(
        billing_service, "construct_webhook_event", lambda payload, sig, settings: event
    )

    response = auth_client.post(
        "/v1/billing/webhook", content=b"{}", headers={"stripe-signature": "valid"}
    )
    assert response.status_code == 200
    me = auth_client.get("/v1/auth/me").json()
    assert me["cancel_at_period_end"] is True
    assert me["pro_active"] is True


def test_webhook_subscription_deleted_setzt_cancel_flag_zurueck(auth_client, monkeypatch):
    user_id = _user_id(auth_client)
    _set_subscription(
        auth_client,
        user_id=user_id,
        stripe_subscription_id="sub_1",
        subscription_started_at=datetime.now(UTC),
    )
    import app.db as db_module
    from app.models import User

    with db_module.SessionLocal() as db:
        db.query(User).filter_by(id=user_id).update({"cancel_at_period_end": True})
        db.commit()

    event = _fake_event("evt_del", "customer.subscription.deleted", {"id": "sub_1"})
    monkeypatch.setattr(
        billing_service, "construct_webhook_event", lambda payload, sig, settings: event
    )

    response = auth_client.post(
        "/v1/billing/webhook", content=b"{}", headers={"stripe-signature": "valid"}
    )
    assert response.status_code == 200
    assert auth_client.get("/v1/auth/me").json()["cancel_at_period_end"] is False


# --------------------------------------------------------------------------- #
# POST /billing/cancel (SUB-99 / B5)
# --------------------------------------------------------------------------- #


def test_cancel_immediately_with_refund_ruft_stripe_kette_korrekt_auf(monkeypatch):
    """Deckt die eigentliche Refund-Kette ab (Befund aus Review von PR #42):

    ``Subscription.retrieve`` -> ``Invoice.retrieve`` -> ``Refund.create`` mit dem
    aus der Invoice ermittelten ``charge_id`` -> ``Subscription.delete``. Mockt
    dazu die rohen Stripe-SDK-Aufrufe statt der gesamten Wrapper-Funktion.
    """
    from app.config import get_settings

    calls: dict = {}

    def fake_subscription_retrieve(subscription_id):
        calls["subscription_retrieve"] = subscription_id
        return {"latest_invoice": "in_test_123"}

    def fake_invoice_retrieve(invoice_id):
        calls["invoice_retrieve"] = invoice_id
        return {"charge": "ch_test_456"}

    def fake_refund_create(**kwargs):
        calls["refund_create"] = kwargs

    def fake_subscription_delete(subscription_id):
        calls["subscription_delete"] = subscription_id

    monkeypatch.setattr(stripe.Subscription, "retrieve", fake_subscription_retrieve)
    monkeypatch.setattr(stripe.Invoice, "retrieve", fake_invoice_retrieve)
    monkeypatch.setattr(stripe.Refund, "create", fake_refund_create)
    monkeypatch.setattr(stripe.Subscription, "delete", fake_subscription_delete)

    billing_service.cancel_immediately_with_refund("sub_test_1", get_settings())

    assert calls["subscription_retrieve"] == "sub_test_1"
    assert calls["invoice_retrieve"] == "in_test_123"
    assert calls["refund_create"] == {"charge": "ch_test_456"}
    assert calls["subscription_delete"] == "sub_test_1"


def test_cancel_ohne_aktives_abo_ist_409(auth_client):
    response = auth_client.post("/v1/billing/cancel")
    assert response.status_code == 409


def test_cancel_kauf_vor_20_tagen_ist_period_end(auth_client, monkeypatch):
    from app.config import get_settings

    monkeypatch.setenv("SUBSUMO_PAYWALL_ENABLED", "true")
    get_settings.cache_clear()

    user_id = _user_id(auth_client)
    pro_until = datetime.now(UTC) + timedelta(days=10)
    _set_subscription(
        auth_client,
        user_id=user_id,
        stripe_subscription_id="sub_1",
        subscription_started_at=datetime.now(UTC) - timedelta(days=20),
        pro_until=pro_until,
    )
    calls = []
    monkeypatch.setattr(
        billing_service,
        "set_cancel_at_period_end",
        lambda sub_id, settings: calls.append(sub_id),
    )

    response = auth_client.post("/v1/billing/cancel")
    assert response.status_code == 200
    assert response.json() == {"mode": "period_end"}
    assert calls == ["sub_1"]
    me = auth_client.get("/v1/auth/me").json()
    assert me["cancel_at_period_end"] is True
    # Mit aktiver Paywall aussagekraeftig: Zugriff bleibt bis Periodenende
    # erhalten, ``pro_until`` wird durch die Kuendigung nicht angefasst.
    assert me["pro_active"] is True
    assert me["pro_until"][:19] == pro_until.isoformat()[:19]


def test_cancel_kauf_vor_5_tagen_ist_immediate_refund(auth_client, monkeypatch):
    from app.config import get_settings

    monkeypatch.setenv("SUBSUMO_PAYWALL_ENABLED", "true")
    get_settings.cache_clear()

    user_id = _user_id(auth_client)
    _set_subscription(
        auth_client,
        user_id=user_id,
        stripe_subscription_id="sub_1",
        subscription_started_at=datetime.now(UTC) - timedelta(days=5),
        pro_until=datetime.now(UTC) + timedelta(days=25),
    )
    refund_calls = []
    monkeypatch.setattr(
        billing_service,
        "cancel_immediately_with_refund",
        lambda sub_id, settings: refund_calls.append(sub_id),
    )

    response = auth_client.post("/v1/billing/cancel")
    assert response.status_code == 200
    assert response.json() == {"mode": "immediate_refund"}
    assert refund_calls == ["sub_1"]
    me = auth_client.get("/v1/auth/me").json()
    assert me["pro_active"] is False
