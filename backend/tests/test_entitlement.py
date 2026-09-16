"""Entitlement-Datenmodell und serverseitige Durchsetzung (SUB-95, docs/20 B1)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from app.config import get_settings
from app.models import User

AUTH_PASSWORD = "examen2029!"


# --------------------------------------------------------------------------- #
# User.has_pro_access - reiner Zeitvergleich, keine Client-Eingabe beteiligt
# --------------------------------------------------------------------------- #


def test_has_pro_access_neuer_nutzer_ohne_pro_until_ist_false():
    user = User(email="x@uni-beispiel.de", password_hash="x")
    assert user.has_pro_access() is False


def test_has_pro_access_pro_until_in_der_zukunft_ist_true():
    user = User(email="x@uni-beispiel.de", password_hash="x")
    user.pro_until = datetime.now(UTC) + timedelta(days=1)
    assert user.has_pro_access() is True


def test_has_pro_access_pro_until_in_der_vergangenheit_ist_false_ohne_reset():
    user = User(email="x@uni-beispiel.de", password_hash="x")
    user.pro_until = datetime.now(UTC) - timedelta(seconds=1)
    # Kein manueller Reset noetig - der naechste Aufruf vergleicht einfach neu.
    assert user.has_pro_access() is False
    assert user.pro_until is not None


# --------------------------------------------------------------------------- #
# GET /auth/me
# --------------------------------------------------------------------------- #


def _set_pro_until(value: datetime | None, *, email: str) -> None:
    """Setzt pro_until direkt in der DB - B3/B4 (Stripe) existieren hier noch nicht."""
    import app.db as db_module

    with db_module.SessionLocal() as db:
        user = db.query(User).filter_by(email=email).one()
        user.pro_until = value
        db.add(user)
        db.commit()


def test_auth_me_liefert_neue_entitlement_felder(auth_client):
    body = auth_client.get("/v1/auth/me").json()
    assert "pro_active" in body
    assert "pro_until" in body
    assert "cancel_at_period_end" in body
    assert body["pro_until"] is None
    assert body["cancel_at_period_end"] is False


def test_auth_me_ohne_paywall_ist_jeder_nutzer_pro(auth_client):
    """paywall_enabled default False - Notausgang, siehe docs/20 Abschnitt 5."""
    assert get_settings().paywall_enabled is False
    assert auth_client.get("/v1/auth/me").json()["pro_active"] is True


def test_auth_me_mit_paywall_folgt_pro_until_zeitbasiert(client, monkeypatch):
    monkeypatch.setenv("SUBSUMO_PAYWALL_ENABLED", "true")
    get_settings.cache_clear()
    try:
        email = f"{uuid.uuid4().hex[:10]}@uni-beispiel.de"
        reg = client.post("/v1/auth/register", json={"email": email, "password": AUTH_PASSWORD})
        client.headers["Authorization"] = f"Bearer {reg.json()['access_token']}"

        assert client.get("/v1/auth/me").json()["pro_active"] is False

        _set_pro_until(datetime.now(UTC) + timedelta(days=30), email=email)
        assert client.get("/v1/auth/me").json()["pro_active"] is True

        _set_pro_until(datetime.now(UTC) - timedelta(days=1), email=email)
        assert client.get("/v1/auth/me").json()["pro_active"] is False
    finally:
        get_settings.cache_clear()


# --------------------------------------------------------------------------- #
# PATCH /auth/me darf keine Entitlement-Felder setzen
# --------------------------------------------------------------------------- #


def test_patch_me_ignoriert_entitlement_felder(auth_client):
    response = auth_client.patch(
        "/v1/auth/me",
        json={
            "display_name": "Neuer Name",
            "pro_until": (datetime.now(UTC) + timedelta(days=365)).isoformat(),
            "cancel_at_period_end": True,
            "stripe_customer_id": "cus_manipuliert",
            "stripe_subscription_id": "sub_manipuliert",
            "pro_active": True,
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert body["display_name"] == "Neuer Name"
    assert body["pro_until"] is None
    assert body["cancel_at_period_end"] is False
    # Notausgang (paywall_enabled=False) entscheidet, nicht der manipulierte Wert.
    assert body["pro_active"] is True
