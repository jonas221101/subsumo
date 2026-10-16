"""Legt ein Test-Konto an oder setzt dessen Passwort neu.

    PYTHONPATH=backend backend/.venv/bin/python ops/beta/set_password.py <email> [anzeigename]

Das Passwort wird zufaellig erzeugt und einmalig ausgegeben. Die E-Mail muss
auf der Allowlist (SUBSUMO_BETA_EMAILS) stehen, sonst kann sich das Konto
ohnehin nicht anmelden.
"""

from __future__ import annotations

import os
import secrets
import sys

from app.core.security import hash_password
from app.db import Base, SessionLocal, engine
from app.models import User

_WORDS = "".join(chr(c) for c in range(ord("a"), ord("z") + 1)) + "23456789"


def main() -> None:
    email = sys.argv[1].strip().lower()
    allowed = {e.strip().lower() for e in os.environ.get("SUBSUMO_BETA_EMAILS", "").split(",")}
    if email not in allowed:
        sys.exit(f"{email} steht nicht auf SUBSUMO_BETA_EMAILS")
    password = "-".join("".join(secrets.choice(_WORDS) for _ in range(5)) for _ in range(4))
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        user = db.query(User).filter_by(email=email).first()
        if user is None:
            user = User(email=email, display_name=sys.argv[2] if len(sys.argv) > 2 else email.split("@")[0])
        user.password_hash = hash_password(password)
        db.add(user)
        db.commit()
    print(f"{email}\t{password}")


if __name__ == "__main__":
    main()
