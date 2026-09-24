"""Warnung beim Start, wenn die Paywall in Produktion aus ist
(docs/22-deploy-runbook.md Abschnitt 1; docs/31-projektreview-sub254.md
Abschnitt 3.1, SUB-255): der Notausgang bleibt erlaubt, darf aber nicht
lautlos passieren."""

from __future__ import annotations

import logging

from app.config import get_settings


class _RecordingHandler(logging.Handler):
    def __init__(self) -> None:
        super().__init__()
        self.records: list[logging.LogRecord] = []

    def emit(self, record: logging.LogRecord) -> None:
        self.records.append(record)


def _create_app_and_collect_warnings(monkeypatch, *, environment: str, paywall_enabled: bool):
    # `create_app()` ruft `configure_logging()` auf, die `root.handlers`
    # komplett ersetzt (app/core/observability.py) - ein per caplog auf dem
    # Root-Logger installierter Handler wuerde dabei mit entfernt. Ein Handler
    # direkt am "subsumo"-Logger bleibt davon unberuehrt.
    monkeypatch.setenv("SUBSUMO_ENVIRONMENT", environment)
    monkeypatch.setenv("SUBSUMO_JWT_SECRET", "ein-echtes-secret")
    monkeypatch.setenv("SUBSUMO_PAYWALL_ENABLED", "true" if paywall_enabled else "false")
    get_settings.cache_clear()
    logger = logging.getLogger("subsumo")
    handler = _RecordingHandler()
    logger.addHandler(handler)
    try:
        import app.main as main_module

        main_module.create_app()
    finally:
        logger.removeHandler(handler)
        get_settings.cache_clear()
    return handler.records


def test_produktion_ohne_paywall_warnt(monkeypatch):
    records = _create_app_and_collect_warnings(
        monkeypatch, environment="production", paywall_enabled=False
    )
    assert any("PAYWALL_ENABLED" in r.getMessage() for r in records)


def test_produktion_mit_paywall_warnt_nicht(monkeypatch):
    records = _create_app_and_collect_warnings(
        monkeypatch, environment="production", paywall_enabled=True
    )
    assert not any("PAYWALL_ENABLED" in r.getMessage() for r in records)


def test_dev_ohne_paywall_warnt_nicht(monkeypatch):
    records = _create_app_and_collect_warnings(
        monkeypatch, environment="dev", paywall_enabled=False
    )
    assert not any("PAYWALL_ENABLED" in r.getMessage() for r in records)
