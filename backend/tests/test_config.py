"""Fail-Fast beim Default-JWT-Secret in Produktion (docs/17-release-readiness.md
Abschnitt 2, Gate D; docs/31-projektreview-sub254.md Abschnitt 3.3, SUB-255)."""

from __future__ import annotations

import pytest

from app.config import Settings


def test_produktion_mit_default_secret_bricht_hart_ab():
    with pytest.raises(RuntimeError, match="SUBSUMO_JWT_SECRET"):
        Settings(_env_file=None, environment="production", jwt_secret="dev-only-insecure-change-me")


def test_produktion_mit_gesetztem_secret_startet():
    settings = Settings(_env_file=None, environment="production", jwt_secret="ein-echtes-secret")
    assert settings.jwt_secret == "ein-echtes-secret"


def test_dev_mit_default_secret_startet_unveraendert():
    settings = Settings(_env_file=None, environment="dev")
    assert settings.jwt_secret == "dev-only-insecure-change-me"
