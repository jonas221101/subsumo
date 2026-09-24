"""Rate-Limit auf /auth/login und /auth/register (docs/26-projektreview-sub254.md
Abschnitt 3.2, SUB-255): bremst Credential-Stuffing und Massen-Registrierung
aus einer IP."""

from __future__ import annotations

from app.config import get_settings


def test_login_wird_nach_zu_vielen_fehlversuchen_pro_ip_gesperrt(client):
    limit = get_settings().auth_rate_limit_max_requests
    payload = {"email": "unbekannt@uni-beispiel.de", "password": "falsch123"}
    for _ in range(limit):
        assert client.post("/v1/auth/login", json=payload).status_code == 401
    resp = client.post("/v1/auth/login", json=payload)
    assert resp.status_code == 429


def test_register_wird_nach_zu_vielen_versuchen_pro_ip_gesperrt(client):
    limit = get_settings().auth_rate_limit_max_requests
    for i in range(limit):
        resp = client.post(
            "/v1/auth/register",
            json={"email": f"massen-{i}@uni-beispiel.de", "password": "examen2029!"},
        )
        assert resp.status_code == 201
    resp = client.post(
        "/v1/auth/register",
        json={"email": "einer-zu-viel@uni-beispiel.de", "password": "examen2029!"},
    )
    assert resp.status_code == 429


def test_login_und_register_limits_sind_getrennte_kontingente(client):
    limit = get_settings().auth_rate_limit_max_requests
    payload = {"email": "unbekannt-2@uni-beispiel.de", "password": "falsch123"}
    for _ in range(limit):
        client.post("/v1/auth/login", json=payload)
    assert client.post("/v1/auth/login", json=payload).status_code == 429

    resp = client.post(
        "/v1/auth/register", json={"email": "frisch@uni-beispiel.de", "password": "examen2029!"}
    )
    assert resp.status_code == 201


def test_hinter_reverse_proxy_sperrt_ein_angreifer_nicht_alle_nutzer(client, monkeypatch):
    """SUB-255-Review: hinter dem in docs/22-deploy-runbook.md dokumentierten
    nginx (gleicher Host, kein --proxy-headers) ist request.client.host fuer
    jede Anfrage identisch - ohne Auswertung von X-Forwarded-For haette eine
    einzelne Quelle das Kontingent fuer alle Nutzer verbraucht (429 fuer
    alle, nicht nur fuer den Angreifer). Simuliert den Proxy, indem der
    TestClient-Peer ("testclient") als vertrauenswuerdig eingetragen wird
    und verschiedene X-Forwarded-For-Werte fuer verschiedene Quellen
    mitgeschickt werden.
    """
    monkeypatch.setenv("SUBSUMO_RATE_LIMIT_TRUSTED_PROXIES", "testclient")
    get_settings.cache_clear()
    limit = get_settings().auth_rate_limit_max_requests

    angreifer_payload = {"email": "unbekannt-3@uni-beispiel.de", "password": "falsch123"}
    angreifer_headers = {"X-Forwarded-For": "203.0.113.10"}
    for _ in range(limit):
        client.post("/v1/auth/login", json=angreifer_payload, headers=angreifer_headers)
    gesperrt = client.post(
        "/v1/auth/login", json=angreifer_payload, headers=angreifer_headers
    )
    assert gesperrt.status_code == 429

    andere_quelle = client.post(
        "/v1/auth/login",
        json={"email": "unbekannt-4@uni-beispiel.de", "password": "falsch123"},
        headers={"X-Forwarded-For": "203.0.113.20"},
    )
    assert andere_quelle.status_code == 401
    get_settings.cache_clear()
