"""Tests fuer Backup/Restore-Tooling (SUB-91/SUB-86).

Deckt den SQLite-Pfad automatisiert ab (kein externes Tooling noetig). Der
PostgreSQL-Pfad ist gegen eine echte lokale Postgres-Instanz geprobt worden -
Befehle und Ergebnis stehen in docs/22-deploy-runbook.md Abschnitt "Restore
tatsaechlich geprobt (Nachweis)", nicht hier, weil das CI-Environment keine
Postgres-Instanz bereitstellt.
"""

from __future__ import annotations

import sqlite3
import time
from pathlib import Path

from scripts.backup_db import backup_sqlite, encrypt_file, prune_old_backups
from scripts.restore_db import decrypt_file, restore_sqlite


def _make_sqlite_db(path: Path) -> None:
    conn = sqlite3.connect(path)
    conn.execute("CREATE TABLE nutzer (id INTEGER PRIMARY KEY, email TEXT)")
    conn.execute("INSERT INTO nutzer (email) VALUES ('probe@uni-beispiel.de')")
    conn.commit()
    conn.close()


def test_sqlite_backup_dann_restore_stellt_daten_korrekt_wieder_her(tmp_path):
    db_path = tmp_path / "subsumo.db"
    _make_sqlite_db(db_path)

    backup_dir = tmp_path / "backups"
    backup_dir.mkdir()
    dest = backup_sqlite(f"sqlite:///{db_path}", backup_dir, "20260921T030000Z")

    assert dest.exists()

    restore_target = tmp_path / "restored.db"
    restored_path = restore_sqlite(dest, f"sqlite:///{restore_target}")

    conn = sqlite3.connect(restored_path)
    rows = conn.execute("SELECT email FROM nutzer").fetchall()
    conn.close()

    assert rows == [("probe@uni-beispiel.de",)]


def test_restore_sichert_bestehende_zieldatei_statt_sie_zu_loeschen(tmp_path):
    db_path = tmp_path / "subsumo.db"
    _make_sqlite_db(db_path)
    backup_dir = tmp_path / "backups"
    backup_dir.mkdir()
    dest = backup_sqlite(f"sqlite:///{db_path}", backup_dir, "20260921T030000Z")

    existing_target = tmp_path / "ziel.db"
    existing_target.write_text("alte-daten-platzhalter")

    restore_sqlite(dest, f"sqlite:///{existing_target}")

    moved_aside = existing_target.with_suffix(existing_target.suffix + ".vor-restore")
    assert moved_aside.read_text() == "alte-daten-platzhalter"
    assert sqlite3.connect(existing_target).execute("SELECT email FROM nutzer").fetchall() == [
        ("probe@uni-beispiel.de",)
    ]


def test_verschluesseltes_backup_entschluesselt_und_restauriert_korrekt(tmp_path):
    db_path = tmp_path / "subsumo.db"
    _make_sqlite_db(db_path)
    backup_dir = tmp_path / "backups"
    backup_dir.mkdir()
    dest = backup_sqlite(f"sqlite:///{db_path}", backup_dir, "20260921T030000Z")

    encrypted = encrypt_file(dest, "probe-passphrase")

    assert encrypted.name == dest.name + ".enc"
    assert not dest.exists()

    decrypt_dir = tmp_path / "decrypted"
    decrypt_dir.mkdir()
    decrypted = decrypt_file(encrypted, "probe-passphrase", decrypt_dir)

    restore_target = tmp_path / "restored.db"
    restored_path = restore_sqlite(decrypted, f"sqlite:///{restore_target}")

    conn = sqlite3.connect(restored_path)
    rows = conn.execute("SELECT email FROM nutzer").fetchall()
    conn.close()

    assert rows == [("probe@uni-beispiel.de",)]


def test_prune_old_backups_loescht_nur_dateien_ueber_der_aufbewahrungsfrist(tmp_path):
    backup_dir = tmp_path / "backups"
    backup_dir.mkdir()

    frisch = backup_dir / "subsumo-backup-frisch.sqlite"
    alt = backup_dir / "subsumo-backup-alt.sqlite"
    frisch.write_text("x")
    alt.write_text("x")

    alt_zeitpunkt = time.time() - 40 * 86400
    import os

    os.utime(alt, (alt_zeitpunkt, alt_zeitpunkt))

    removed = prune_old_backups(backup_dir, retention_days=30)

    assert removed == [alt]
    assert frisch.exists()
    assert not alt.exists()
