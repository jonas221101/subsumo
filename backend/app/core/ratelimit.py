"""Einfacher IP-basierter Rate-Limiter fuer die Auth-Routen (docs/26-projektreview-sub254.md
Abschnitt 3.2).

In-Memory, pro Prozess: reicht fuer eine einzelne Backend-Instanz und bremst
Credential-Stuffing gegen ``/auth/login`` sowie Massen-Registrierung gegen
``/auth/register``. Kein verteiltes Rate-Limiting ueber mehrere Instanzen
hinweg - dafuer braeuchte es einen gemeinsamen Speicher (z. B. Redis), der
aktuell nicht Teil des Stacks ist.
"""

from __future__ import annotations

import threading
import time
from collections import defaultdict

from fastapi import HTTPException, Request, status


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


def _client_ip(request: Request) -> str:
    return request.client.host if request.client is not None else "unknown"


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
