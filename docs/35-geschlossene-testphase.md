# Geschlossene Testphase: Zugang fuer zwei Personen, Feedback ueber den Server

Ziel: Eine Testerin (Jura) und der Betreiber nutzen die App ueber das
Internet, sonst niemand. Alles laeuft ueber den eigenen Server - kein
Drittdienst fuer Login oder Feedback. Dieses Dokument ist das Runbook dafuer;
der allgemeine Deploy steht in `docs/22-deploy-runbook.md` und wird hier
nur dort wiederholt, wo die Testphase abweicht.

---

## 1. Was der Server erzwingt

| Mechanismus | Wo | Wirkung |
|---|---|---|
| Allowlist `SUBSUMO_BETA_ALLOWED_EMAILS` | `backend/app/config.py` | Ist sie gesetzt, ist `POST /v1/auth/register` fuer alle geschlossen (403), `POST /v1/auth/login` akzeptiert nur gelistete Adressen (sonst dieselbe 401-Meldung wie bei falschem Passwort), und jedes Bearer-Token wird bei jedem Aufruf gegen die Liste geprueft (`app/api/deps.py`). Eine Adresse von der Liste nehmen sperrt sofort, auch laufende Sitzungen. |
| Konten nur per Skript | `backend/scripts/beta_users.py` | Konten und Passwoerter entstehen ausschliesslich auf dem Server (`set-password`). Niemand kann ein Konto unter fremder Adresse anlegen, auch nicht unter einer gelisteten. |
| Passwoerter | `app/core/security.py` | PBKDF2-Hash, nie im Klartext gespeichert; mindestens 8 Zeichen. |
| Rate-Limit auf Login | `app/core/ratelimit.py` | Wie bisher (20 Versuche pro Fenster je IP); `SUBSUMO_RATE_LIMIT_TRUSTED_PROXIES=127.0.0.1` setzen, sonst zaehlt nginx als einzige IP. |
| TLS | Reverse-Proxy | Nur `https://` nach aussen; uvicorn lauscht auf `127.0.0.1`. |
| CORS | `SUBSUMO_CORS_ORIGINS` | Browser-Zugriff nur von der eigenen App-Domain. |
| Feedback | `POST /v1/feedback`, `GET /v1/feedback/mine` | Nur angemeldet, maximal `SUBSUMO_FEEDBACK_MAX_PER_DAY` (Default 30) je Tag. Lesen fremder Rueckmeldungen gibt es nicht ueber die API - der Betreiber liest auf dem Server. |
| App | `GET /v1/public/config` → `registration_open: false` | Die App blendet "Konto erstellen" aus und zeigt den Hinweis zur Testphase. |

Ohne gesetzte Allowlist verhaelt sich alles wie vorher (Registrierung offen).
Die Testphase ist also ein Schalter, kein Umbau.

## 2. Server einrichten (einmalig)

Voraussetzung: Backend laeuft nach `docs/22` Abschnitt 2 unter
`/opt/subsumo/backend` mit `EnvironmentFile=/opt/subsumo/backend/.env`.

### 2.1 Umgebungsvariablen

In `/opt/subsumo/backend/.env` (Datei nur fuer den Dienst-User lesbar,
`chmod 600`):

```bash
SUBSUMO_ENVIRONMENT=production
SUBSUMO_JWT_SECRET=<openssl rand -hex 32>
SUBSUMO_DATABASE_URL=sqlite:////var/lib/subsumo/subsumo.db   # oder PostgreSQL
SUBSUMO_PAYWALL_ENABLED=false                                # Testphase: alles frei, bewusst
SUBSUMO_RATE_LIMIT_TRUSTED_PROXIES=127.0.0.1
SUBSUMO_LOG_JSON=true

# Testphase (docs/35)
SUBSUMO_BETA_ALLOWED_EMAILS=jonas@example.org,christina@example.org
SUBSUMO_CORS_ORIGINS=https://app.example.org
SUBSUMO_FEEDBACK_MAX_PER_DAY=30
```

Die beiden Adressen sind die einzigen, die sich anmelden koennen. Nach jeder
Aenderung der `.env`: `sudo systemctl restart subsumo-backend`.

### 2.2 Datenbank-Spalten (nur bei bestehender Datenbank)

`create_all` legt die neue Tabelle `feedback` beim Start selbst an. Die
Spalten aus docs/22 Abschnitt 2.2 (Examen, Lernprofil, Fachrichtungen)
muessen auf einer aelteren Datenbank vorher per `ALTER TABLE` nachgezogen
sein. Eine frische Datenbank braucht nichts.

### 2.3 Konten anlegen

Auf dem Server, als Dienst-User, mit derselben `.env`:

```bash
cd /opt/subsumo/backend
set -a; . ./.env; set +a
.venv/bin/python scripts/beta_users.py set-password jonas@example.org --display-name Jonas
.venv/bin/python scripts/beta_users.py set-password christina@example.org --display-name Christina
.venv/bin/python scripts/beta_users.py list
```

`set-password` fragt das Passwort zweimal ab (keine Shell-History). Das
Skript lehnt Adressen ab, die nicht in `SUBSUMO_BETA_ALLOWED_EMAILS`
stehen. Passwort vergessen: denselben Befehl erneut ausfuehren.

Das Passwort fuer Christina auf einem zweiten Kanal uebergeben (muendlich,
Messenger mit Ablauf), nicht in derselben Nachricht wie die URL.

### 2.4 Web-App bauen und ausliefern

Auf der Build-Maschine (Flutter SDK), nicht auf dem Server:

```bash
cd app
flutter build web --release \
  --dart-define=SUBSUMO_API=https://api.example.org \
  --dart-define=SUBSUMO_FACH=jura \
  --dart-define=SUBSUMO_VERSION=$(git rev-parse --short HEAD) \
  --base-href=/
rsync -a --delete build/web/ server:/var/www/app.example.org/
```

`SUBSUMO_VERSION` landet in jeder Rueckmeldung (`app_version`), damit klar
ist, welchen Stand Christina gesehen hat. Alternativ liefert der manuelle
Build-Workflow (`.github/workflows/manual-builds.yml`, Inputs `api_base`
und `fach`) ein Windows-Artefakt, das gegen denselben Server laeuft.

### 2.5 Reverse-Proxy

nginx wie in docs/22 Abschnitt 3 (zwei `server`-Bloecke: `api.` auf
`127.0.0.1:8000`, `app.` auf das Webroot mit SPA-Fallback), Zertifikat ueber
certbot. Zusaetzlich sinnvoll fuer die Testphase:

```nginx
# im api.-Block: nichts cachen, Methoden durchreichen
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
# im app.-Block: Suchmaschinen fernhalten
add_header X-Robots-Tag "noindex, nofollow" always;
```

Wer es schlanker will, nimmt Caddy (TLS automatisch):

```caddyfile
api.example.org {
    reverse_proxy 127.0.0.1:8000
}
app.example.org {
    root * /var/www/app.example.org
    file_server
    try_files {path} /index.html
    header X-Robots-Tag "noindex, nofollow"
}
```

### 2.6 Pruefen

```bash
curl -sf https://api.example.org/health
curl -s https://api.example.org/v1/public/config | grep -o '"registration_open":false'
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://api.example.org/v1/auth/register \
  -H 'content-type: application/json' -d '{"email":"x@y.de","password":"abcdefgh"}'   # 403
```

Dann im Browser `https://app.example.org` oeffnen: Login-Seite ohne "Konto
erstellen", mit Hinweis zur Testphase; Anmeldung mit den angelegten Daten.

## 3. Was Christina bekommt

- Die Adresse `https://app.example.org`, ihre E-Mail-Adresse und das
  Passwort (getrennt uebermittelt).
- Den Hinweis, dass nur sie und der Betreiber Zugang haben und dass der
  Lernfortschritt auf dem Server liegt (Backup laut docs/22 Abschnitt 6).
- Den Feedback-Button (Sprechblasen-Symbol oben rechts, auf jeder Seite)
  und die Karte "Feedback" unter "Konto". Kategorien: Fehler, Idee, Inhalt,
  Sonstiges. Die Stelle in der App (aktiver Tab) wird automatisch
  mitgeschickt; sie sieht ihre bisherigen Rueckmeldungen und ob eine
  erledigt ist.

Was bewusst nicht dabei ist: Bezahlstrecke (Paywall aus), KI-Korrektur
(ohne `SUBSUMO_LLM_API_KEY` laeuft die Heuristik), Selbstregistrierung.

## 4. Feedback lesen und abarbeiten

Auf dem Server:

```bash
cd /opt/subsumo/backend && set -a; . ./.env; set +a
.venv/bin/python scripts/beta_users.py feedback            # Markdown, neueste zuerst
.venv/bin/python scripts/beta_users.py feedback --offen    # nur unerledigte
.venv/bin/python scripts/beta_users.py feedback --json --since 2026-10-14 > feedback.json
.venv/bin/python scripts/beta_users.py feedback --done 12  # als erledigt markieren
```

Jeder Eintrag traegt Absender, Kategorie, Stelle in der App, Plattform,
App-Version und Zeitpunkt. "Erledigt" sieht Christina in ihrer Liste - ein
kleines Signal, dass die Rueckmeldung angekommen ist. Inhaltliche
Rueckmeldungen (Kategorie `inhalt`) gehen als Thema in die KI-Redaktion
(`docs/08`, `redaktion_cli.py`), nicht direkt in eine YAML-Datei.

## 5. Testphase beenden oder erweitern

- Weitere Person: Adresse an `SUBSUMO_BETA_ALLOWED_EMAILS` anhaengen,
  Backend neu starten, `set-password` ausfuehren.
- Person entfernen: Adresse aus der Liste nehmen, Backend neu starten -
  Login und laufende Sitzungen sind sofort gesperrt; das Konto bleibt
  (Loeschung ueber `DELETE /v1/me` durch die Person selbst oder per
  SQL).
- Oeffnen: `SUBSUMO_BETA_ALLOWED_EMAILS` leeren oder entfernen, dann gilt
  wieder `docs/17` (Release-Readiness) mit Paywall-Entscheidung und
  Rechtstexten.

## 6. Datenschutz, kurz

Feedback enthaelt freien Text von einer bekannten Person; er liegt in der
Datenbank des Betreibers, wird nicht an Dritte uebermittelt und gehoert zum
Datenexport (`GET /v1/account/export`, Feld `feedback`) und zur Kontoloeschung
(`POST /v1/account/delete`) wie alle anderen Nutzerdaten. Wird eine Person nur
von der Allowlist genommen, bleiben ihre Rueckmeldungen erhalten, bis sie
ihr Konto loescht oder der Betreiber es per SQL tut.
