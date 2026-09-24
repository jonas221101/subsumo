"""Unit-Tests fuer den IP-basierten Rate-Limiter (docs/26-projektreview-sub254.md
Abschnitt 3.2, SUB-255)."""

from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.testclient import TestClient

from app.config import get_settings
from app.core.ratelimit import RateLimiter, _client_ip


def test_erlaubt_bis_zum_limit_und_blockt_danach():
    limiter = RateLimiter(max_requests=3, window_seconds=60)
    assert limiter.allow("k", now=0) is True
    assert limiter.allow("k", now=1) is True
    assert limiter.allow("k", now=2) is True
    assert limiter.allow("k", now=3) is False


def test_keys_sind_unabhaengig_voneinander():
    limiter = RateLimiter(max_requests=1, window_seconds=60)
    assert limiter.allow("a", now=0) is True
    assert limiter.allow("b", now=0) is True
    assert limiter.allow("a", now=1) is False


def test_fenster_rutscht_alte_treffer_fallen_raus():
    limiter = RateLimiter(max_requests=1, window_seconds=10)
    assert limiter.allow("k", now=0) is True
    assert limiter.allow("k", now=5) is False
    assert limiter.allow("k", now=11) is True


def _ip_app() -> FastAPI:
    """Minimale App, um ``_client_ip`` gegen einen echten Request zu pruefen."""
    app = FastAPI()

    @app.get("/ip")
    def ip(request: Request) -> dict[str, str]:
        return {"ip": _client_ip(request)}

    return app


def test_ohne_konfigurierten_proxy_wird_x_forwarded_for_ignoriert(monkeypatch):
    # SUB-255-Review: ohne explizit vertrauenswuerdigen Proxy darf ein Client
    # den Header nicht selbst setzen koennen, um das Limit zu umgehen.
    monkeypatch.delenv("SUBSUMO_RATE_LIMIT_TRUSTED_PROXIES", raising=False)
    get_settings.cache_clear()
    client = TestClient(_ip_app())
    resp = client.get("/ip", headers={"X-Forwarded-For": "203.0.113.9"})
    assert resp.json()["ip"] == "testclient"
    get_settings.cache_clear()


def test_hinter_vertrauenswuerdigem_proxy_zaehlt_die_letzte_forwarded_ip(monkeypatch):
    # docs/22-deploy-runbook.md: nginx haengt den echten Client per
    # $proxy_add_x_forwarded_for als letzten Eintrag an - ein davorstehender,
    # potenziell vom Client gefaelschter Eintrag darf nicht gewinnen.
    monkeypatch.setenv("SUBSUMO_RATE_LIMIT_TRUSTED_PROXIES", "testclient")
    get_settings.cache_clear()
    client = TestClient(_ip_app())
    resp = client.get(
        "/ip", headers={"X-Forwarded-For": "clientgefaelscht, 203.0.113.7"}
    )
    assert resp.json()["ip"] == "203.0.113.7"
    get_settings.cache_clear()
