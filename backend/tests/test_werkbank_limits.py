"""Werkbank-Kontingent + Versuchslimit (SUB-367, docs/27-werkbank-spezifikation.md
Abschnitt 6.2).

Es gibt noch keinen Werkbank-Endpunkt (Ticket 3/7 sind auf die AVV- bzw.
Risikoentscheidung blockiert) - die Tests rufen die ``limits.py``-Funktionen
deshalb direkt auf, wie es das Muster in ``test_llm_kostenbremse.py`` fuer
Faelle ohne einfachen HTTP-Pfad vorgibt.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import pytest

import app.db as db_module
from app.models import User
from app.services import limits

AUTH_PASSWORD = "examen2029!"


def _register(client) -> str:
    email = f"{uuid.uuid4().hex[:10]}@uni-beispiel.de"
    response = client.post("/v1/auth/register", json={"email": email, "password": AUTH_PASSWORD})
    assert response.status_code == 201, response.text
    return email


def _grant_pro(email: str) -> None:
    with db_module.SessionLocal() as db:
        user = db.query(User).filter_by(email=email).one()
        user.pro_until = datetime.now(UTC) + timedelta(days=30)
        db.add(user)
        db.commit()


def _user(email: str, db) -> User:
    return db.query(User).filter_by(email=email).one()


# --------------------------------------------------------------------------- #
# Erstellungs-Kontingent - 1/rollierendem Monat
# --------------------------------------------------------------------------- #


def test_erstellungs_kontingent_greift_nach_platzhalterzahl(client):
    email = _register(client)
    now = datetime.now(UTC)
    with db_module.SessionLocal() as db:
        user = _user(email, db)
        for _ in range(limits.WERKBANK_FREE_CREATIONS_PER_MONTH):
            limits.enforce_tool_creation_quota(db, user, now=now)
            limits.record_tool_creation(db, user, now=now)

        with pytest.raises(Exception) as exc_info:
            limits.enforce_tool_creation_quota(db, user, now=now)

    detail = exc_info.value.detail
    assert detail["upgrade_required"] is True
    assert detail["reason"] == "werkbank_creation_limit_reached"
    assert isinstance(detail["message"], str) and detail["message"]
    assert "reset_at" in detail


def test_erstellungs_kontingent_zaehlt_nur_das_laufende_30_tage_fenster(client):
    email = _register(client)
    with db_module.SessionLocal() as db:
        user = _user(email, db)
        alt = datetime.now(UTC) - timedelta(days=31)
        for _ in range(limits.WERKBANK_FREE_CREATIONS_PER_MONTH):
            limits.record_tool_creation(db, user, now=alt)

        # Ausserhalb des rollierenden Fensters - darf wieder erstellen.
        limits.enforce_tool_creation_quota(db, user, now=datetime.now(UTC))


def test_pro_nutzer_ist_vom_erstellungs_kontingent_ausgenommen_wie_bei_has_pro_access(
    client, monkeypatch
):
    """Gate liegt beim Aufrufer (``is_free_tier``), genau wie bei den drei
    bestehenden Free-Tier-Limits - nicht in ``enforce_tool_creation_quota``
    selbst."""
    monkeypatch.setenv("SUBSUMO_PAYWALL_ENABLED", "true")
    from app.config import get_settings

    get_settings.cache_clear()
    try:
        email = _register(client)
        _grant_pro(email)
        settings = get_settings()
        now = datetime.now(UTC)
        with db_module.SessionLocal() as db:
            user = _user(email, db)
            for _ in range(limits.WERKBANK_FREE_CREATIONS_PER_MONTH + 3):
                if limits.is_free_tier(user, settings, now=now):
                    limits.enforce_tool_creation_quota(db, user, now=now)
                limits.record_tool_creation(db, user, now=now)
    finally:
        get_settings.cache_clear()


# --------------------------------------------------------------------------- #
# Versuchslimit - getrennt vom Erstellungs-Kontingent, 10/Kalendertag
# --------------------------------------------------------------------------- #


def test_versuchslimit_greift_unabhaengig_vom_erstellungs_kontingent(client):
    email = _register(client)
    now = datetime.now(UTC)
    with db_module.SessionLocal() as db:
        user = _user(email, db)
        # Nur fehlgeschlagene Versuche - zaehlen gegen das Versuchslimit, nicht
        # gegen das (noch unberuehrte) Erstellungs-Kontingent.
        for _ in range(limits.WERKBANK_ATTEMPTS_PER_DAY):
            limits.enforce_tool_attempt_quota(db, user, now=now)
            limits.record_tool_attempt(db, user, now=now)

        with pytest.raises(Exception) as exc_info:
            limits.enforce_tool_attempt_quota(db, user, now=now)

        # Erstellungs-Kontingent ist von den gescheiterten Versuchen unberuehrt.
        limits.enforce_tool_creation_quota(db, user, now=now)

    detail = exc_info.value.detail
    assert detail["upgrade_required"] is True
    assert detail["reason"] == "werkbank_attempt_limit_reached"
    assert isinstance(detail["message"], str) and detail["message"]


def test_erfolgreiche_erstellung_zaehlt_auch_gegen_das_versuchslimit(client):
    """Abschnitt 6.2: das Versuchslimit zaehlt Erfolg und Fehlschlag zusammen."""
    email = _register(client)
    now = datetime.now(UTC)
    with db_module.SessionLocal() as db:
        user = _user(email, db)
        limits.enforce_tool_attempt_quota(db, user, now=now)
        limits.enforce_tool_creation_quota(db, user, now=now)
        limits.record_tool_attempt(db, user, now=now)
        limits.record_tool_creation(db, user, now=now)

        attempts_today = (
            db.query(limits.WerkbankGenerationAttempt)
            .filter_by(user_id=user.id)
            .count()
        )
    assert attempts_today == 1


def test_versuchslimit_resettet_am_naechsten_kalendertag(client):
    email = _register(client)
    with db_module.SessionLocal() as db:
        user = _user(email, db)
        gestern = datetime.now(UTC).replace(
            hour=12, minute=0, second=0, microsecond=0
        ) - timedelta(days=1)
        for _ in range(limits.WERKBANK_ATTEMPTS_PER_DAY):
            limits.record_tool_attempt(db, user, now=gestern)

        # Neuer Kalendertag - Kontingent ist zurueckgesetzt.
        limits.enforce_tool_attempt_quota(db, user, now=datetime.now(UTC))


# --------------------------------------------------------------------------- #
# Einheitliches Fehlerformat
# --------------------------------------------------------------------------- #


def test_beide_werkbank_limits_nutzen_dasselbe_fehlerformat_wie_die_bestehenden_sperren(
    client,
):
    email = _register(client)
    now = datetime.now(UTC)
    with db_module.SessionLocal() as db:
        user = _user(email, db)
        for _ in range(limits.WERKBANK_FREE_CREATIONS_PER_MONTH):
            limits.record_tool_creation(db, user, now=now)
        for _ in range(limits.WERKBANK_ATTEMPTS_PER_DAY):
            limits.record_tool_attempt(db, user, now=now)

        with pytest.raises(Exception) as creation_exc:
            limits.enforce_tool_creation_quota(db, user, now=now)
        with pytest.raises(Exception) as attempt_exc:
            limits.enforce_tool_attempt_quota(db, user, now=now)

    for exc_info in (creation_exc, attempt_exc):
        detail = exc_info.value.detail
        assert detail["upgrade_required"] is True
        assert isinstance(detail["reason"], str) and detail["reason"]
        assert isinstance(detail["message"], str) and detail["message"]
