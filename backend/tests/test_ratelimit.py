"""Unit-Tests fuer den IP-basierten Rate-Limiter (docs/26-projektreview-sub254.md
Abschnitt 3.2, SUB-255)."""

from __future__ import annotations

from app.core.ratelimit import RateLimiter


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
