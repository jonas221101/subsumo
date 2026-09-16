#!/usr/bin/env python3
"""Spielt ein Backup zurueck. Siehe docs/22-deploy-runbook.md Abschnitt "Restore".

Fuer SQLite wird die Zieldatei durch die Backup-Datei ersetzt (die alte
Zieldatei wird vorher nach ``<ziel>.vor-restore`` verschoben, nicht
geloescht). Fuer PostgreSQL wird ``pg_restore --clean --if-exists`` gegen die
Ziel-Datenbank ausgefuehrt - die Ziel-Datenbank muss existieren und leer oder
ueberschreibbar sein. Dateien mit ``.enc``-Endung (siehe ``backup_db.py
--encrypt``) werden vor dem Restore automatisch entschluesselt (Passphrase
aus ``SUBSUMO_BACKUP_PASSPHRASE``).

Beispiele:
    python scripts/restore_db.py backups/subsumo-backup-20260921T030000Z.sqlite \\
        --database-url sqlite:///./restore-drill.db

    SUBSUMO_BACKUP_PASSPHRASE=... python scripts/restore_db.py \\
        backups/subsumo-backup-20260921T030000Z.dump.enc \\
        --database-url postgresql://user:pw@host/restore_drill_db
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlparse

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import REPO_ROOT, get_settings  # noqa: E402
from scripts.backup_db import PASSPHRASE_ENV_VAR  # noqa: E402


def decrypt_file(path: Path, passphrase: str, dest_dir: Path) -> Path:
    """Entschluesselt ein mit ``backup_db.encrypt_file`` erzeugtes ``.enc``-Backup."""
    dest = dest_dir / path.stem
    subprocess.run(
        [
            "openssl",
            "enc",
            "-d",
            "-aes-256-cbc",
            "-pbkdf2",
            "-in",
            str(path),
            "-out",
            str(dest),
            "-pass",
            f"env:{PASSPHRASE_ENV_VAR}",
        ],
        check=True,
        env={**os.environ, PASSPHRASE_ENV_VAR: passphrase},
    )
    return dest


def restore_sqlite(backup_file: Path, database_url: str) -> Path:
    db_path = Path(database_url.removeprefix("sqlite:///"))
    if not db_path.is_absolute():
        db_path = REPO_ROOT / db_path

    if db_path.exists():
        moved_aside = db_path.with_suffix(db_path.suffix + ".vor-restore")
        shutil.move(str(db_path), str(moved_aside))
        print(f"OK  Bestehende Datei gesichert nach: {moved_aside}")

    shutil.copy(str(backup_file), str(db_path))
    return db_path


def restore_postgres(backup_file: Path, database_url: str) -> None:
    subprocess.run(
        [
            "pg_restore",
            "--clean",
            "--if-exists",
            "--no-owner",
            f"--dbname={database_url}",
            str(backup_file),
        ],
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("backup_file", type=Path, help="Pfad zur Backup-Datei")
    parser.add_argument(
        "--database-url", default=None, help="Ziel-Datenbank (Standard: SUBSUMO_DATABASE_URL)"
    )
    args = parser.parse_args()

    if not args.backup_file.exists():
        print(f"FEHLER  Backup-Datei nicht gefunden: {args.backup_file}", file=sys.stderr)
        return 1

    database_url = args.database_url or get_settings().database_url
    scheme = urlparse(database_url).scheme

    with tempfile.TemporaryDirectory() as tmp_dir:
        backup_file = args.backup_file
        if backup_file.suffix == ".enc":
            passphrase = os.environ.get(PASSPHRASE_ENV_VAR)
            if not passphrase:
                print(
                    f"FEHLER  Verschluesseltes Backup, aber {PASSPHRASE_ENV_VAR} nicht gesetzt",
                    file=sys.stderr,
                )
                return 1
            backup_file = decrypt_file(backup_file, passphrase, Path(tmp_dir))
            print(f"OK  Backup entschluesselt: {backup_file.name}")

        if database_url.startswith("sqlite"):
            dest = restore_sqlite(backup_file, database_url)
            print(f"OK  Restore abgeschlossen: {dest}")
        elif scheme.startswith("postgres"):
            restore_postgres(backup_file, database_url)
            print(f"OK  Restore abgeschlossen gegen: {database_url}")
        else:
            print(f"FEHLER  Nicht unterstuetztes Datenbankschema: {scheme!r}", file=sys.stderr)
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
