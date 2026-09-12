#!/usr/bin/env python3
"""Validiert die Lerninhalte. Laeuft in der CI bei jedem Pull Request.

Exit 1 bei Fehlern. Warnungen (z. B. veraltete Inhalte) brechen den Lauf nicht
ab, werden aber ausgegeben - mit ``--strict`` auch sie.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import REPO_ROOT  # noqa: E402
from app.services.content import load_content  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--content-dir", type=Path, default=REPO_ROOT / "content")
    parser.add_argument("--strict", action="store_true", help="Warnungen als Fehler behandeln")
    args = parser.parse_args()

    bundle = load_content(args.content_dir)

    for warning in bundle.warnings:
        print(f"WARNUNG  {warning}")
    for error in bundle.errors:
        print(f"FEHLER   {error}")

    print(
        f"\n{len(bundle.topics)} Themen, {len(bundle.cards)} Karten, "
        f"{len(bundle.schemata)} Schemata, {len(bundle.cases)} Faelle "
        f"- {len(bundle.errors)} Fehler, {len(bundle.warnings)} Warnungen"
    )
    if bundle.errors or (args.strict and bundle.warnings):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
