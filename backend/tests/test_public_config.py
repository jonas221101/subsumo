"""Oeffentlicher Feature-Flag-Endpoint fuer die Preisseite (SUB-107)."""

from __future__ import annotations

from app.config import get_settings


def test_public_config_ohne_auth_header_liefert_default_false(client):
    assert get_settings().paywall_enabled is False
    resp = client.get("/v1/public/config")
    assert resp.status_code == 200
    assert resp.json() == {"paywall_enabled": False}


def test_public_config_folgt_paywall_enabled_true(client, monkeypatch):
    monkeypatch.setenv("SUBSUMO_PAYWALL_ENABLED", "true")
    get_settings.cache_clear()
    try:
        resp = client.get("/v1/public/config")
        assert resp.status_code == 200
        assert resp.json() == {"paywall_enabled": True}
    finally:
        get_settings.cache_clear()


def test_public_config_aendert_auth_me_verhalten_nicht(auth_client):
    before = auth_client.get("/v1/auth/me").json()
    auth_client.get("/v1/public/config")
    after = auth_client.get("/v1/auth/me").json()
    assert before == after
