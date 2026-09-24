"""Freischaltcode-Redeem (SUB-270, docs/28-freischaltcode-spezifikation.md Abschnitt 3)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta


def _create_code(
    code: str,
    *,
    campaign_slug: str = "fachschaft-lmu",
    pro_duration_days: int = 180,
    max_redemptions: int | None = None,
    expires_at: datetime | None = None,
    active: bool = True,
) -> None:
    import app.db as db_module
    from app.models import RedeemCode

    with db_module.SessionLocal() as db:
        db.add(
            RedeemCode(
                code=code,
                campaign_slug=campaign_slug,
                pro_duration_days=pro_duration_days,
                max_redemptions=max_redemptions,
                expires_at=expires_at,
                active=active,
            )
        )
        db.commit()


def _user_id(client) -> int:
    return client.get("/v1/auth/me").json()["id"]


def test_redeem_erfolgsfall_setzt_pro_until(auth_client):
    _create_code("FACHSCHAFT-LMU-2026", pro_duration_days=180)

    response = auth_client.post("/v1/account/redeem", json={"code": "FACHSCHAFT-LMU-2026"})
    assert response.status_code == 200
    pro_until = datetime.fromisoformat(response.json()["pro_until"])
    expected = datetime.now(UTC) + timedelta(days=180)
    assert abs((pro_until - expected).total_seconds()) < 60

    me = auth_client.get("/v1/auth/me").json()
    assert me["pro_active"] is True


def test_redeem_normalisiert_trim_und_case(auth_client):
    _create_code("FACHSCHAFT-LMU-2026")

    response = auth_client.post(
        "/v1/account/redeem", json={"code": "  fachschaft-lmu-2026  "}
    )
    assert response.status_code == 200


def test_redeem_verlaengert_bestehenden_zugang_statt_ihn_zu_verkuerzen(auth_client):
    user_id = _user_id(auth_client)
    future = datetime.now(UTC) + timedelta(days=300)

    import app.db as db_module
    from app.models import User

    with db_module.SessionLocal() as db:
        user = db.get(User, user_id)
        user.pro_until = future
        db.add(user)
        db.commit()

    _create_code("FACHSCHAFT-LMU-2026", pro_duration_days=180)
    response = auth_client.post("/v1/account/redeem", json={"code": "FACHSCHAFT-LMU-2026"})
    assert response.status_code == 200
    pro_until = datetime.fromisoformat(response.json()["pro_until"])
    expected = future + timedelta(days=180)
    assert abs((pro_until - expected).total_seconds()) < 60


def test_redeem_unbekannter_code_ist_404(auth_client):
    response = auth_client.post("/v1/account/redeem", json={"code": "UNBEKANNT"})
    assert response.status_code == 404


def test_redeem_inaktiver_code_ist_404_wie_unbekannt(auth_client):
    _create_code("GESPERRT-CODE", active=False)
    response = auth_client.post("/v1/account/redeem", json={"code": "GESPERRT-CODE"})
    assert response.status_code == 404


def test_redeem_abgelaufener_code_ist_410(auth_client):
    _create_code(
        "ABGELAUFEN-2025", expires_at=datetime.now(UTC) - timedelta(days=1)
    )
    response = auth_client.post("/v1/account/redeem", json={"code": "ABGELAUFEN-2025"})
    assert response.status_code == 410


def test_redeem_erschoepfter_code_ist_410(auth_client):
    _create_code("EINZEL-INVITE-042", max_redemptions=1)

    import app.db as db_module
    from app.models import RedeemCode, RedeemCodeRedemption, User

    with db_module.SessionLocal() as db:
        code = db.query(RedeemCode).filter_by(code="EINZEL-INVITE-042").one()
        other_user = User(
            email="andere-person@uni-beispiel.de",
            password_hash="irrelevant",
        )
        db.add(other_user)
        db.flush()
        db.add(RedeemCodeRedemption(redeem_code_id=code.id, user_id=other_user.id))
        db.commit()

    response = auth_client.post("/v1/account/redeem", json={"code": "EINZEL-INVITE-042"})
    assert response.status_code == 410


def test_redeem_retry_vom_selben_nutzer_auf_erschoepften_code_ist_409(auth_client):
    """SUB-281: eigene Einloesung zaehlt in redemption_count mit - Duplikat-Check

    muss vor dem Erschoepft-Check greifen, sonst bekommt die eingeladene
    Person bei einem Retry auf ihren eigenen ``max_redemptions=1``-Code
    faelschlich 410 statt 409.
    """
    _create_code("EINZEL-INVITE-042", max_redemptions=1)

    first = auth_client.post("/v1/account/redeem", json={"code": "EINZEL-INVITE-042"})
    assert first.status_code == 200

    second = auth_client.post("/v1/account/redeem", json={"code": "EINZEL-INVITE-042"})
    assert second.status_code == 409


def test_redeem_doppelt_vom_selben_nutzer_ist_409(auth_client):
    _create_code("FACHSCHAFT-LMU-2026")

    first = auth_client.post("/v1/account/redeem", json={"code": "FACHSCHAFT-LMU-2026"})
    assert first.status_code == 200

    second = auth_client.post("/v1/account/redeem", json={"code": "FACHSCHAFT-LMU-2026"})
    assert second.status_code == 409


def test_redeem_ohne_max_redemptions_kann_von_mehreren_nutzern_eingeloest_werden(
    auth_client, client
):
    _create_code("FACHSCHAFT-LMU-2026")

    first = auth_client.post("/v1/account/redeem", json={"code": "FACHSCHAFT-LMU-2026"})
    assert first.status_code == 200

    register = client.post(
        "/v1/auth/register",
        json={"email": "zweite-person@uni-beispiel.de", "password": "examen2029!"},
    )
    client.headers["Authorization"] = f"Bearer {register.json()['access_token']}"
    second = client.post("/v1/account/redeem", json={"code": "FACHSCHAFT-LMU-2026"})
    assert second.status_code == 200


def test_redeem_ohne_auth_ist_401(client):
    response = client.post("/v1/account/redeem", json={"code": "FACHSCHAFT-LMU-2026"})
    assert response.status_code == 401
