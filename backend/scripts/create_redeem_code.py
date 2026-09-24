#!/usr/bin/env python3
"""Legt einen Freischaltcode an (docs/28-freischaltcode-spezifikation.md Abschnitt 4).

Bei der geplanten Groessenordnung (2-5 Fachschafts-Kooperationen) lohnt keine
Admin-Oberflaeche - ein Aufruf dieses Skripts genuegt. Codes werden
ausschliesslich serverseitig ueber dieses Skript erzeugt, nie ueber einen
Client-Endpoint (analog zur Regel fuer ``stripe_customer_id`` in
app/models.py).

Beispiel:
    python scripts/create_redeem_code.py FACHSCHAFT-LMU-2026 fachschaft-lmu \\
        --pro-duration-days 180 --expires-at 2026-12-31

    # Einzel-Invite, nur einmal insgesamt einloesbar
    python scripts/create_redeem_code.py EINZEL-INVITE-042 kooperation-x \\
        --max-redemptions 1
"""

from __future__ import annotations

import argparse
import sys
from datetime import UTC, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.db import Base, SessionLocal, engine  # noqa: E402
from app.models import RedeemCode  # noqa: E402


def create_redeem_code(
    code: str,
    campaign_slug: str,
    *,
    pro_duration_days: int = 180,
    max_redemptions: int | None = None,
    expires_at: datetime | None = None,
) -> RedeemCode:
    normalized = code.strip().upper()
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        if db.query(RedeemCode).filter_by(code=normalized).one_or_none() is not None:
            raise ValueError(f"Code {normalized!r} existiert bereits")

        redeem_code = RedeemCode(
            code=normalized,
            campaign_slug=campaign_slug,
            pro_duration_days=pro_duration_days,
            max_redemptions=max_redemptions,
            expires_at=expires_at,
        )
        db.add(redeem_code)
        db.commit()
        db.refresh(redeem_code)
        return redeem_code


def _parse_date(value: str) -> datetime:
    return datetime.strptime(value, "%Y-%m-%d").replace(tzinfo=UTC)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("code", help="Freischaltcode, z. B. FACHSCHAFT-LMU-2026")
    parser.add_argument("campaign_slug", help="Kampagnen-Zuordnung, z. B. fachschaft-lmu")
    parser.add_argument(
        "--pro-duration-days", type=int, default=180, help="Standard: 180 (sechs Monate)"
    )
    parser.add_argument(
        "--max-redemptions",
        type=int,
        default=None,
        help="Obergrenze an Gesamteinloesungen. Ohne Angabe: unbegrenzt viele Nutzer:innen",
    )
    parser.add_argument(
        "--expires-at", type=_parse_date, default=None, help="Verfallsdatum, Format: YYYY-MM-DD"
    )
    args = parser.parse_args()

    try:
        redeem_code = create_redeem_code(
            args.code,
            args.campaign_slug,
            pro_duration_days=args.pro_duration_days,
            max_redemptions=args.max_redemptions,
            expires_at=args.expires_at,
        )
    except ValueError as exc:
        print(f"FEHLER  {exc}", file=sys.stderr)
        return 1

    print(
        f"OK  Code {redeem_code.code!r} angelegt "
        f"(Kampagne {redeem_code.campaign_slug!r}, id={redeem_code.id}, "
        f"pro_duration_days={redeem_code.pro_duration_days}, "
        f"max_redemptions={redeem_code.max_redemptions}, "
        f"expires_at={redeem_code.expires_at})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
