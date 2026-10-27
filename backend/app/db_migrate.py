"""Idempotente Start-Migrationen fuer bestehende Datenbanken.

``Base.metadata.create_all`` legt nur fehlende Tabellen an und aendert keine
bestehenden (docs/22 Abschnitt 2.2). Dieses Modul gleicht die wenigen
nachtraeglichen Schema-Aenderungen am Lernkern beim Start ab - SQLite und
PostgreSQL, mehrfach ausfuehrbar, ohne Datenverlust:

* ``user_cards.step`` (Lernschritt-Index) - ``ADD COLUMN`` mit Default 0.
* ``reviews``: der globale Unique-Index auf ``client_id`` wird durch einen
  nicht-eindeutigen Index ersetzt, dazu kommt ein eindeutiger Index auf
  ``(user_id, client_id)`` (Idempotenz pro Nutzer).

Scheitert ein Schritt (z. B. fehlende DDL-Rechte), wird er geloggt und der
Start geht weiter; docs/22 nennt die Statements fuer den manuellen Lauf.
"""

from __future__ import annotations

import logging

from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine

log = logging.getLogger("subsumo")


def _run(engine: Engine, statement: str) -> None:
    try:
        with engine.begin() as conn:
            conn.execute(text(statement))
        log.info("Migration ausgefuehrt: %s", statement)
    except Exception:  # noqa: BLE001 - Start darf an DDL-Rechten nicht scheitern
        log.exception("Migration fehlgeschlagen (manuell nachholen, docs/22): %s", statement)


def migrate(engine: Engine) -> None:
    insp = inspect(engine)
    tables = set(insp.get_table_names())

    if "user_cards" in tables:
        columns = {c["name"] for c in insp.get_columns("user_cards")}
        if "step" not in columns:
            _run(engine, "ALTER TABLE user_cards ADD COLUMN step INTEGER NOT NULL DEFAULT 0")

    if "reviews" in tables:
        indexes = {i["name"]: i for i in insp.get_indexes("reviews")}
        old = indexes.get("ix_reviews_client_id")
        if old is not None and old.get("unique"):
            _run(engine, "DROP INDEX ix_reviews_client_id")
            _run(engine, "CREATE INDEX ix_reviews_client_id ON reviews (client_id)")
        if "uq_reviews_user_client" not in indexes:
            uniques = {u["name"] for u in insp.get_unique_constraints("reviews")}
            if "uq_reviews_user_client" not in uniques:
                _run(
                    engine,
                    "CREATE UNIQUE INDEX uq_reviews_user_client ON reviews (user_id, client_id)",
                )
