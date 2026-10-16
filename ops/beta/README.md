# Geschlossener Test-Zugang (Private Beta)

Eigene Instanz fuer einzelne Testerinnen/Tester, getrennt von Entwicklungs-DB
und Agenten-Worktrees.

- Code: Worktree `/home/paperclip/subsumo-beta`, Branch `beta/private-test`
- Daten: `/home/paperclip/subsumo-beta-data/` (chmod 700) - `beta.env`
  (Secrets, Allowlist), `beta.db`, `feedback.jsonl`, `web/` (Flutter-Build)
- Dienst: `systemctl --user {status,restart} subsumo-beta` (127.0.0.1:8095)
- Oeffentlich: `tailscale funnel --bg --https=8443 http://127.0.0.1:8095`

Sicherheit: siehe Docstring in `gateway.py` (Allowlist, Registrierung/Doku/
Billing gesperrt, alle Inhalte nur mit Token eines Allowlist-Kontos).

## Konto anlegen / Passwort neu setzen

    set -a; . /home/paperclip/subsumo-beta-data/beta.env; set +a
    PYTHONPATH=backend backend/.venv/bin/python ops/beta/set_password.py <email> [name]

## Web-Build aktualisieren

    cd app && flutter build web --release --dart-define=SUBSUMO_API=/api \
      --dart-define=SUBSUMO_BETA=true --base-href=/
    rm -rf /home/paperclip/subsumo-beta-data/web && cp -r build/web /home/paperclip/subsumo-beta-data/web

## Feedback lesen

    jq . /home/paperclip/subsumo-beta-data/feedback.jsonl

oder eingeloggt als Admin (`SUBSUMO_BETA_ADMINS`): `GET /api/beta/feedback`.
