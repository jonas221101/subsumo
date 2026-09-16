#!/usr/bin/env python3
"""Erstellt ein Datenbank-Backup. Siehe docs/22-deploy-runbook.md Abschnitt "Backup".

Unterstuetzt SQLite (Dev/kleine Deployments) und PostgreSQL (Produktion), je
nach ``SUBSUMO_DATABASE_URL``/``--database-url``. Loescht nach dem Backup
Dateien im Zielverzeichnis, die aelter als die Aufbewahrungsfrist sind
(Standard 30 Tage, siehe docs/17-release-readiness.md Abschnitt 2, das dort
auch eine Verschluesselung ruhender Backups fordert - siehe ``--encrypt``).

Beispiele:
    # SQLite, Standardverzeichnis ./backups
    python scripts/backup_db.py

    # PostgreSQL, eigenes Backup-Verzeichnis, verschluesselt
    SUBSUMO_BACKUP_PASSPHRASE=... python scripts/backup_db.py \\
        --database-url postgresql://user:pw@host/db \\
        --backup-dir /var/backups/subsumo --encrypt
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import REPO_ROOT, get_settings  # noqa: E402

DEFAULT_RETENTION_DAYS = 30
PASSPHRASE_ENV_VAR = "SUBSUMO_BACKUP_PASSPHRASE"


def encrypt_file(path: Path, passphrase: str) -> Path:
    """Verschluesselt ``path`` mit AES-256 (openssl, PBKDF2-Salt) und loescht das Original.

    Symmetrische Dateiverschluesselung statt eines KMS/Cloud-Schluesseldiensts,
    weil die Hosting-Entscheidung laut docs/17-release-readiness.md Abschnitt 5
    noch offen ist - das deckt die Mindestanforderung "Verschluesselung ruhend"
    aus Abschnitt 2 schon ab, ohne an einen Anbieter zu binden.
    """
    dest = path.with_name(path.name + ".enc")
    subprocess.run(
        [
            "openssl",
            "enc",
            "-aes-256-cbc",
            "-pbkdf2",
            "-salt",
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
    path.unlink()
    return dest


def _timestamp() -> str:
    return time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())


def backup_sqlite(database_url: str, backup_dir: Path, timestamp: str) -> Path:
    db_path = Path(database_url.removeprefix("sqlite:///"))
    if not db_path.is_absolute():
        db_path = REPO_ROOT / db_path
    if not db_path.exists():
        raise FileNotFoundError(f"SQLite-Datei nicht gefunden: {db_path}")

    dest = backup_dir / f"subsumo-backup-{timestamp}.sqlite"
    # Connection.backup() ist konsistent auch bei gleichzeitigen
    # Schreibzugriffen, eine reine Dateikopie waere das nicht.
    with sqlite3.connect(db_path) as source, sqlite3.connect(dest) as target:
        source.backup(target)
    return dest


def backup_postgres(database_url: str, backup_dir: Path, timestamp: str) -> Path:
    dest = backup_dir / f"subsumo-backup-{timestamp}.dump"
    subprocess.run(
        ["pg_dump", "--format=custom", f"--file={dest}", database_url],
        check=True,
    )
    return dest


def prune_old_backups(backup_dir: Path, retention_days: int) -> list[Path]:
    cutoff = time.time() - retention_days * 86400
    removed = []
    for entry in backup_dir.glob("subsumo-backup-*"):
        if entry.is_file() and entry.stat().st_mtime < cutoff:
            entry.unlink()
            removed.append(entry)
    return removed


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--database-url", default=None, help="Ueberschreibt SUBSUMO_DATABASE_URL")
    parser.add_argument(
        "--backup-dir",
        type=Path,
        default=None,
        help="Zielverzeichnis fuer Backups (Standard: ./backups relativ zum Repo-Root)",
    )
    parser.add_argument(
        "--retention-days",
        type=int,
        default=DEFAULT_RETENTION_DAYS,
        help=f"Aeltere Backups werden geloescht (Standard: {DEFAULT_RETENTION_DAYS})",
    )
    parser.add_argument(
        "--encrypt",
        action="store_true",
        help=(
            "Backup-Datei mit AES-256 verschluesseln (Passphrase aus "
            f"${PASSPHRASE_ENV_VAR}). In Produktion Pflicht, siehe "
            "docs/17-release-readiness.md Abschnitt 2."
        ),
    )
    args = parser.parse_args()

    if args.encrypt and not os.environ.get(PASSPHRASE_ENV_VAR):
        print(
            f"FEHLER  --encrypt verlangt die Umgebungsvariable {PASSPHRASE_ENV_VAR}",
            file=sys.stderr,
        )
        return 1

    database_url = args.database_url or get_settings().database_url
    backup_dir = args.backup_dir or (REPO_ROOT / "backups")
    backup_dir.mkdir(parents=True, exist_ok=True)

    scheme = urlparse(database_url).scheme
    timestamp = _timestamp()

    if database_url.startswith("sqlite"):
        dest = backup_sqlite(database_url, backup_dir, timestamp)
    elif scheme.startswith("postgres"):
        dest = backup_postgres(database_url, backup_dir, timestamp)
    else:
        print(f"FEHLER  Nicht unterstuetztes Datenbankschema: {scheme!r}", file=sys.stderr)
        return 1

    if args.encrypt:
        dest = encrypt_file(dest, os.environ[PASSPHRASE_ENV_VAR])

    size_kb = dest.stat().st_size / 1024
    print(f"OK  Backup geschrieben: {dest} ({size_kb:.1f} KiB)")

    removed = prune_old_backups(backup_dir, args.retention_days)
    for entry in removed:
        print(f"OK  Aufbewahrungsfrist ueberschritten, geloescht: {entry.name}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
