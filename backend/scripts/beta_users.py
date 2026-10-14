#!/usr/bin/env python3
"""Konten und Feedback der geschlossenen Testphase (docs/35).

Laeuft ausschliesslich auf dem Server mit derselben ``SUBSUMO_DATABASE_URL``
wie das Backend. Konten entstehen in der Testphase nur hier - die
Registrierung ueber die API ist bei gesetzter ``SUBSUMO_BETA_ALLOWED_EMAILS``
geschlossen.

Beispiele:
    # Konto anlegen oder Passwort neu setzen (Passwort wird abgefragt)
    python scripts/beta_users.py set-password christina@example.org

    # Passwort ueber stdin (fuer Skripte), Anzeigename optional
    echo 'geheim-und-lang' | python scripts/beta_users.py set-password \\
        jonas@example.org --password-stdin --display-name Jonas

    # Wer darf rein, wer ist angelegt?
    python scripts/beta_users.py list

    # Rueckmeldungen lesen (neueste zuerst), als Markdown oder JSON
    python scripts/beta_users.py feedback
    python scripts/beta_users.py feedback --json --since 2026-10-01
    python scripts/beta_users.py feedback --done 12
"""

from __future__ import annotations

import argparse
import getpass
import json
import sys
from datetime import UTC, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import app.db as db_module  # noqa: E402
from app.config import get_settings  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.models import Feedback, User  # noqa: E402

MIN_PASSWORD = 8


def set_password(email: str, password: str, *, display_name: str | None = None) -> str:
    """Legt das Konto an oder setzt das Passwort neu. Gibt 'angelegt'/'aktualisiert' zurueck."""
    normalized = email.strip().lower()
    if "@" not in normalized:
        raise ValueError(f"Keine E-Mail-Adresse: {email!r}")
    if len(password) < MIN_PASSWORD:
        raise ValueError(f"Passwort braucht mindestens {MIN_PASSWORD} Zeichen")
    allowlist = get_settings().beta_allowlist()
    if allowlist and normalized not in allowlist:
        raise ValueError(
            f"{normalized} steht nicht in SUBSUMO_BETA_ALLOWED_EMAILS - zuerst dort "
            "eintragen, sonst kann sich das Konto nicht anmelden."
        )
    db_module.Base.metadata.create_all(bind=db_module.engine)
    with db_module.SessionLocal() as db:
        user = db.query(User).filter_by(email=normalized).one_or_none()
        if user is None:
            user = User(
                email=normalized,
                password_hash=hash_password(password),
                display_name=display_name or normalized.split("@")[0],
            )
            db.add(user)
            ergebnis = "angelegt"
        else:
            user.password_hash = hash_password(password)
            if display_name:
                user.display_name = display_name
            ergebnis = "aktualisiert"
        db.commit()
    return ergebnis


def list_users() -> list[dict]:
    allowlist = get_settings().beta_allowlist()
    db_module.Base.metadata.create_all(bind=db_module.engine)
    with db_module.SessionLocal() as db:
        users = db.query(User).order_by(User.email).all()
        vorhanden = {u.email for u in users}
        zeilen = [
            {
                "email": u.email,
                "display_name": u.display_name,
                "zugang": (not allowlist) or u.email in allowlist,
                "created_at": u.created_at.isoformat() if u.created_at else "",
            }
            for u in users
        ]
    for email in sorted(allowlist - vorhanden):
        zeilen.append(
            {"email": email, "display_name": "", "zugang": True, "created_at": "(kein Konto)"}
        )
    return zeilen


def list_feedback(*, since: datetime | None = None, offen: bool = False) -> list[dict]:
    db_module.Base.metadata.create_all(bind=db_module.engine)
    with db_module.SessionLocal() as db:
        query = db.query(Feedback, User.email).join(User, User.id == Feedback.user_id)
        if since is not None:
            query = query.filter(Feedback.created_at >= since)
        if offen:
            query = query.filter(Feedback.erledigt_at.is_(None))
        rows = query.order_by(Feedback.created_at.desc(), Feedback.id.desc()).all()
        return [
            {
                "id": f.id,
                "von": email,
                "kategorie": f.category,
                "nachricht": f.message,
                "kontext": f.context,
                "plattform": f.platform,
                "app_version": f.app_version,
                "erstellt": f.created_at.isoformat() if f.created_at else "",
                "erledigt": f.erledigt_at is not None,
            }
            for f, email in rows
        ]


def mark_done(feedback_id: int) -> bool:
    with db_module.SessionLocal() as db:
        row = db.get(Feedback, feedback_id)
        if row is None:
            return False
        row.erledigt_at = datetime.now(UTC)
        db.commit()
        return True


def _markdown(eintraege: list[dict]) -> str:
    if not eintraege:
        return "Keine Rueckmeldungen."
    teile = []
    for e in eintraege:
        status = "erledigt" if e["erledigt"] else "offen"
        kopf = f"## #{e['id']} - {e['kategorie']} - {e['von']} - {e['erstellt'][:16]} ({status})"
        meta = ", ".join(x for x in (e["kontext"], e["plattform"], e["app_version"]) if x)
        teile.append(kopf + (f"\n_{meta}_" if meta else "") + f"\n\n{e['nachricht']}\n")
    return "\n".join(teile)


def _read_password(args: argparse.Namespace) -> str:
    if args.password_stdin:
        return sys.stdin.readline().rstrip("\r\n")
    erstes = getpass.getpass("Passwort: ")
    if erstes != getpass.getpass("Passwort wiederholen: "):
        raise ValueError("Die Passwoerter stimmen nicht ueberein")
    return erstes


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_set = sub.add_parser("set-password", help="Konto anlegen oder Passwort neu setzen")
    p_set.add_argument("email")
    p_set.add_argument("--display-name", default=None)
    p_set.add_argument("--password-stdin", action="store_true", help="Passwort aus stdin lesen")

    sub.add_parser("list", help="Konten und Allowlist anzeigen")

    p_fb = sub.add_parser("feedback", help="Rueckmeldungen lesen")
    p_fb.add_argument("--json", action="store_true")
    p_fb.add_argument("--since", default=None, help="YYYY-MM-DD")
    p_fb.add_argument("--offen", action="store_true", help="nur unerledigte")
    p_fb.add_argument(
        "--done", type=int, default=None, metavar="ID", help="Eintrag als erledigt markieren"
    )

    args = parser.parse_args(argv)
    try:
        if args.cmd == "set-password":
            ergebnis = set_password(
                args.email, _read_password(args), display_name=args.display_name
            )
            print(f"Konto {args.email.strip().lower()} {ergebnis}.")
            return 0
        if args.cmd == "list":
            allowlist = get_settings().beta_allowlist()
            print(
                "Testphase: "
                + (
                    f"geschlossen, {len(allowlist)} Adresse(n) erlaubt"
                    if allowlist
                    else "offen (keine Allowlist)"
                )
            )
            for z in list_users():
                zugang = "Zugang" if z["zugang"] else "GESPERRT"
                print(f"  {z['email']:40} {zugang:9} {z['display_name']:20} {z['created_at']}")
            return 0
        if args.done is not None:
            if mark_done(args.done):
                print(f"#{args.done} als erledigt markiert.")
                return 0
            print(f"#{args.done} nicht gefunden.")
            return 1
        since = (
            datetime.strptime(args.since, "%Y-%m-%d").replace(tzinfo=UTC) if args.since else None
        )
        eintraege = list_feedback(since=since, offen=args.offen)
        print(
            json.dumps(eintraege, ensure_ascii=False, indent=2)
            if args.json
            else _markdown(eintraege)
        )
        return 0
    except ValueError as exc:
        print(f"Fehler: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
