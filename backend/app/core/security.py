"""Passwort-Hashing und JWT - bewusst nur mit der Standardbibliothek.

Keine nativen Krypto-Abhaengigkeiten im Kern: das haelt Builds auf allen
CI-Runnern und Plattformen reproduzierbar. PBKDF2-HMAC-SHA256 mit 600.000
Iterationen entspricht der OWASP-Empfehlung; der Wechsel auf Argon2id ist fuer
M3 vorgesehen und durch das ``algo$...``-Praefix im Hash vorbereitet.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import time
from typing import Any

from app.config import get_settings

_PBKDF2_ITERATIONS = 600_000
_SALT_BYTES = 16


def _b64e(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def _b64d(data: str) -> bytes:
    return base64.urlsafe_b64decode(data + "=" * (-len(data) % 4))


# --------------------------------------------------------------------------- #
# Passwoerter
# --------------------------------------------------------------------------- #


def hash_password(password: str, *, iterations: int = _PBKDF2_ITERATIONS) -> str:
    salt = secrets.token_bytes(_SALT_BYTES)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return f"pbkdf2_sha256${iterations}${_b64e(salt)}${_b64e(dk)}"


def verify_password(password: str, stored: str) -> bool:
    try:
        algo, iterations, salt_b64, hash_b64 = stored.split("$")
    except ValueError:
        return False
    if algo != "pbkdf2_sha256":
        return False
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), _b64d(salt_b64), int(iterations))
    return hmac.compare_digest(dk, _b64d(hash_b64))


# --------------------------------------------------------------------------- #
# JWT (HS256)
# --------------------------------------------------------------------------- #


class TokenError(Exception):
    pass


def create_access_token(subject: str, *, ttl_minutes: int | None = None, **claims: Any) -> str:
    settings = get_settings()
    ttl = ttl_minutes if ttl_minutes is not None else settings.access_token_ttl_minutes
    now = int(time.time())
    payload = {"sub": subject, "iat": now, "exp": now + ttl * 60, **claims}
    header = {"alg": "HS256", "typ": "JWT"}

    segments = [
        _b64e(json.dumps(header, separators=(",", ":"), sort_keys=True).encode()),
        _b64e(json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()),
    ]
    signing_input = ".".join(segments).encode("ascii")
    signature = hmac.new(settings.jwt_secret.encode(), signing_input, hashlib.sha256).digest()
    segments.append(_b64e(signature))
    return ".".join(segments)


def decode_access_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    try:
        header_b64, payload_b64, signature_b64 = token.split(".")
    except ValueError as exc:
        raise TokenError("Token hat kein gueltiges JWT-Format") from exc

    signing_input = f"{header_b64}.{payload_b64}".encode("ascii")
    expected = hmac.new(settings.jwt_secret.encode(), signing_input, hashlib.sha256).digest()
    if not hmac.compare_digest(expected, _b64d(signature_b64)):
        raise TokenError("Signatur ungueltig")

    payload = json.loads(_b64d(payload_b64))
    if payload.get("exp", 0) < time.time():
        raise TokenError("Token abgelaufen")
    return payload
