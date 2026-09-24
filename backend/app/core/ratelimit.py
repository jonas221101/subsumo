"""Einfacher IP-basierter Rate-Limiter fuer die Auth-Routen (docs/26-projektreview-sub254.md
Abschnitt 3.2).

In-Memory, pro Prozess: reicht fuer eine einzelne Backend-Instanz und bremst
Credential-Stuffing gegen ``/auth/login`` sowie Massen-Registrierung gegen
``/auth/register``. Kein verteiltes Rate-Limiting ueber mehrere Instanzen
hinweg - dafuer braeuchte es einen gemeinsamen Speicher (z. B. Redis), der
aktuell nicht Teil des Stacks ist.

Hinter dem in ``docs/22-deploy-runbook.md`` dokumentierten nginx-Reverse-Proxy
(auf demselben Host, kein ``--proxy-headers``) ist ``request.client.host``
fuer jede Anfrage identisch - ohne die ``X-Forwarded-For``-Behandlung unten
waere der Limiter kein IP-Limiter mehr, sondern ein einziger globaler
Zaehler, den eine einzelne Quelle als Denial-of-Service gegen alle Nutzer
missbrauchen koennte (SUB-255-Review, docs/26 Abschnitt 3.2).
"""

from __future__ import annotations

import threading
import time
from collections import defaultdict

from fastapi import HTTPException, Request, status

from app.config import get_settings


class RateLimiter:
    """Sliding-Window-Limiter: hoechstens ``max_requests`` pro ``window_seconds`` je Key."""

    def __init__(self, max_requests: int, window_seconds: float) -> None:
        self._max_requests = max_requests
        self._window_seconds = window_seconds
        self._hits: dict[str, list[float]] = defaultdict(list)
        self._lock = threading.Lock()

    def allow(self, key: str, *, now: float | None = None) -> bool:
        now = time.monotonic() if now is None else now
        cutoff = now - self._window_seconds
        with self._lock:
            hits = self._hits[key]
            while hits and hits[0] < cutoff:
                hits.pop(0)
            if len(hits) >= self._max_requests:
                return False
            hits.append(now)
            return True


def _trusted_proxies() -> frozenset[str]:
    raw = get_settings().rate_limit_trusted_proxies
    return frozenset(ip.strip() for ip in raw.split(",") if ip.strip())


def _client_ip(request: Request) -> str:
    peer = request.client.host if request.client is not None else "unknown"
    if peer not in _trusted_proxies():
        return peer
    # Der unmittelbare Peer ist ein vertrauenswuerdiger Reverse-Proxy: dessen
    # eigener Hop haengt sich per ``X-Forwarded-For`` selbst als letzten
    # Eintrag an (nginx: ``$proxy_add_x_forwarded_for``). Vorherige Eintraege
    # koennte ein Client selbst gesetzt haben - nur der letzte stammt
    # nachweislich vom Proxy.
    forwarded = request.headers.get("x-forwarded-for")
    if not forwarded:
        return peer
    candidate = forwarded.split(",")[-1].strip()
    return candidate or peer


def _enforce(request: Request, scope: str) -> None:
    limiter: RateLimiter = request.app.state.auth_rate_limiter
    if not limiter.allow(f"{scope}:{_client_ip(request)}"):
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Zu viele Versuche. Bitte spaeter erneut probieren.",
        )


def enforce_login_rate_limit(request: Request) -> None:
    _enforce(request, "login")


def enforce_register_rate_limit(request: Request) -> None:
    _enforce(request, "register")
