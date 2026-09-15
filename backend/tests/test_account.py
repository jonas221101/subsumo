"""DSGVO-Betroffenenrechte: Selbstauskunft (Art. 15) und Loeschung (Art. 17)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

AUTH_PASSWORD = "examen2029!"


def _seed_lerndaten(auth_client) -> dict:
    """Legt einen Review- und einen Gutachten-Datensatz fuer den Nutzer an."""
    card = auth_client.get("/v1/cards/due", params={"limit": 1}).json()[0]
    auth_client.post(
        "/v1/reviews/batch",
        json={
            "reviews": [
                {
                    "client_id": uuid.uuid4().hex,
                    "card_slug": card["slug"],
                    "rating": 3,
                    "reviewed_at": datetime.now(UTC).isoformat(),
                    "elapsed_ms": 1500,
                }
            ]
        },
    )
    submission = auth_client.post(
        "/v1/cases/zr-fall-sonderpreis/submit",
        json={"text": "K könnte gegen V einen Anspruch haben.", "mode": "uebung"},
    ).json()
    return {"card_slug": card["slug"], "submission_id": submission["submission_id"]}


# --------------------------------------------------------------------------- #
# Export (Art. 15)
# --------------------------------------------------------------------------- #


def test_export_erfordert_authentifizierung(client):
    assert client.get("/v1/account/export").status_code == 401


def test_export_liefert_konto_lernfortschritt_und_gutachten_vollstaendig(auth_client):
    seed = _seed_lerndaten(auth_client)
    export = auth_client.get("/v1/account/export").json()

    assert export["account"]["email"]
    assert "password_hash" not in export["account"]
    assert "password" not in export["account"]

    assert len(export["user_cards"]) == 1
    assert export["user_cards"][0]["card_slug"] == seed["card_slug"]
    assert export["user_cards"][0]["reps"] == 1

    assert len(export["reviews"]) == 1
    assert export["reviews"][0]["card_slug"] == seed["card_slug"]
    assert export["reviews"][0]["rating"] == 3

    assert len(export["submissions"]) == 1
    submission = export["submissions"][0]
    assert submission["case_slug"] == "zr-fall-sonderpreis"
    assert "Anspruch" in submission["text"]
    assert "evaluation" in submission["report"]


def test_export_zeigt_nur_das_eigene_konto(client):
    a = client.post(
        "/v1/auth/register", json={"email": "a-export@uni-beispiel.de", "password": AUTH_PASSWORD}
    ).json()
    client.post(
        "/v1/auth/register", json={"email": "b-export@uni-beispiel.de", "password": AUTH_PASSWORD}
    )
    client.headers["Authorization"] = f"Bearer {a['access_token']}"
    export = client.get("/v1/account/export").json()
    assert export["account"]["email"] == "a-export@uni-beispiel.de"


# --------------------------------------------------------------------------- #
# Loeschung (Art. 17)
# --------------------------------------------------------------------------- #


def test_loeschung_erfordert_authentifizierung(client):
    response = client.post("/v1/account/delete", json={"password": "x", "confirm": True})
    assert response.status_code == 401


def test_loeschung_ohne_bestaetigung_wird_abgelehnt(auth_client):
    response = auth_client.post(
        "/v1/account/delete", json={"password": AUTH_PASSWORD, "confirm": False}
    )
    assert response.status_code == 400
    # Konto bleibt erhalten - sofort danach ist /me weiterhin erreichbar.
    assert auth_client.get("/v1/auth/me").status_code == 200


def test_loeschung_mit_falschem_passwort_wird_abgelehnt(auth_client):
    response = auth_client.post(
        "/v1/account/delete", json={"password": "falsches-passwort", "confirm": True}
    )
    assert response.status_code == 401
    assert auth_client.get("/v1/auth/me").status_code == 200


def test_loeschung_entfernt_daten_und_sperrt_login_endgueltig(client):
    email = f"{uuid.uuid4().hex[:10]}@uni-beispiel.de"
    reg = client.post("/v1/auth/register", json={"email": email, "password": AUTH_PASSWORD}).json()
    client.headers["Authorization"] = f"Bearer {reg['access_token']}"
    _seed_lerndaten(client)

    response = client.post(
        "/v1/account/delete", json={"password": AUTH_PASSWORD, "confirm": True}
    )
    assert response.status_code == 200
    assert response.json()["deleted"] is True

    # Das bisherige Token ist tot - der Nutzer existiert nicht mehr.
    assert client.get("/v1/auth/me").status_code == 401

    # Login mit den alten Zugangsdaten ist endgueltig nicht mehr moeglich.
    client.headers.pop("Authorization")
    login = client.post("/v1/auth/login", json={"email": email, "password": AUTH_PASSWORD})
    assert login.status_code == 401

    # Die E-Mail ist wieder frei - keine Karteileiche blockiert die Neuregistrierung.
    neu = client.post("/v1/auth/register", json={"email": email, "password": AUTH_PASSWORD})
    assert neu.status_code == 201


def test_loeschung_wirkt_nur_auf_das_eigene_konto(client):
    a = client.post(
        "/v1/auth/register", json={"email": "a-delete@uni-beispiel.de", "password": AUTH_PASSWORD}
    ).json()
    b = client.post(
        "/v1/auth/register", json={"email": "b-delete@uni-beispiel.de", "password": AUTH_PASSWORD}
    ).json()

    client.headers["Authorization"] = f"Bearer {a['access_token']}"
    client.post("/v1/account/delete", json={"password": AUTH_PASSWORD, "confirm": True})

    client.headers["Authorization"] = f"Bearer {b['access_token']}"
    assert client.get("/v1/auth/me").status_code == 200
    assert client.get("/v1/auth/me").json()["email"] == "b-delete@uni-beispiel.de"
