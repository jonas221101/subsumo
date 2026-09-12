"""Zeitzonen-Hilfen.

SQLite speichert keine Zeitzone: was als aware datetime hineingeschrieben
wurde, kommt naiv zurueck. Jeder Vergleich mit ``datetime.now(timezone.utc)``
wuerde dann mit einem TypeError abbrechen. Alles, was aus der Datenbank kommt,
laeuft deshalb durch ``as_utc``.
"""

from __future__ import annotations

from datetime import UTC, datetime


def as_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
