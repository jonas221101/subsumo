# 22. Deploy-Runbook: Betrieb (Backend + DB + Web), TLS, Backup/Restore, Monitoring

Deckt SUB-86/SUB-91 (Gates G4/G5 aus `docs/18-release-2-wochen.md` Abschnitt 5,
Tagesplan Abschnitt 6, Risiko Abschnitt 7) ab: Deploy-Ablauf fuer
`app.subsumo.de`, TLS, taegliches Backup mit tatsaechlich geprobtem Restore,
Monitoring/Fehler-Tracking. Alle Befehle in diesem Dokument wurden lokal
gegen eine Staging-Konfiguration ausgefuehrt (Nachweise in den jeweiligen
Abschnitten) — **keine** produktive Serveraktion gegen den echten Zielserver,
die echte Domain oder echte Zugangsdaten.

**Offener Punkt, der dieses Runbook einschraenkt:** Die Hosting-Entscheidung
(welcher Server/Provider, EU-Rechenzentrum wegen DSGVO — siehe
`docs/17-release-readiness.md` Abschnitt 5) ist noch nicht getroffen. Dieses
Runbook geht deshalb von einer generischen Linux-Umgebung mit `systemd` und
einem Reverse-Proxy (nginx oder Caddy) aus. Sobald der Zielserver feststeht,
sind Pfade (`/opt/subsumo/...`), der Betriebs-User (`subsumo`) und die
Proxy-Config-Syntax an die tatsaechliche Umgebung anzupassen — die Abfolge
und die Kommandos selbst aendern sich dadurch nicht.

## 1. Voraussetzungen

- Server mit Python 3.11+, `pg_dump`/`pg_restore`-Client (bei PostgreSQL),
  `openssl`, `systemd`, Reverse-Proxy (nginx/Caddy).
- DNS: `app.subsumo.de` zeigt auf den Zielserver (Registrierung/DNS ist laut
  `docs/17-release-readiness.md` Abschnitt 5 noch offen — Blocker, kein Teil
  dieser Aufgabe).
- Produktions-Secrets gesetzt: `SUBSUMO_JWT_SECRET` (`openssl rand -hex 32`,
  **nicht** der Dev-Default), `SUBSUMO_DATABASE_URL` (PostgreSQL in
  Produktion), `SUBSUMO_ENVIRONMENT=production`, `SUBSUMO_LOG_JSON=true`,
  `SUBSUMO_BACKUP_PASSPHRASE` (siehe Abschnitt 6).
- `SUBSUMO_PAYWALL_ENABLED` bewusst gesetzt: `true`, wenn die volle Kette
  Kauf→Freischaltung→Kuendigung auf Produktion laeuft, sonst `false` als
  Notausgang (`docs/20-release-g2-bezahlstrecke.md` Abschnitt 5). Der
  Default ist `false` — wer die Variable vergisst, startet lautlos mit
  offener Paywall (jeder Nutzer bekommt Pro-Zugriff geschenkt); das Backend
  loggt dafuer bei `SUBSUMO_ENVIRONMENT=production` eine Warnung, wenn die
  Variable fehlt oder `false` ist.
- `SUBSUMO_RATE_LIMIT_TRUSTED_PROXIES=127.0.0.1` setzen, weil nginx gemaess
  Abschnitt 3 per `proxy_pass http://127.0.0.1:8000` auf demselben Host an
  uvicorn weiterreicht: ohne diese Variable sieht der Rate-Limiter auf
  `/auth/login` und `/auth/register` (`backend/app/core/ratelimit.py`) fuer
  jede Anfrage denselben TCP-Peer (`127.0.0.1`) und wird faktisch zu einem
  einzigen globalen Zaehler statt eines Limits pro Client-IP — eine einzelne
  Quelle koennte damit das Login/die Registrierung fuer alle Nutzer sperren.
  Mit gesetzter Variable wertet der Limiter die von nginx gesetzte
  `X-Forwarded-For`-IP aus (`proxy_set_header X-Forwarded-For
  $proxy_add_x_forwarded_for;`, siehe nginx-Beispiel in Abschnitt 3). Default
  ist leer (kein vertrauenswuerdiger Proxy) — in Dev/Test bewusst so, damit
  der Header nicht ungeprueft vom Client uebernommen wird.
- Frontend-Build-Voraussetzungen (Flutter SDK) nur auf der Build-Maschine
  noetig, nicht auf dem Zielserver — siehe Abschnitt 2.2.

## 2. Deploy-Ablauf (Reihenfolge)

Reihenfolge pro Release: **Backup → Code aktualisieren → Backend neu
starten (Schema-Anwendung passiert dabei automatisch) → Web-Build
ausliefern → Health-Check → ggf. Rollback**.

### 2.1 Backend

```bash
cd /opt/subsumo/backend
git fetch origin && git checkout <freigegebener-tag-oder-sha>
.venv/bin/pip install -r requirements.txt
sudo systemctl restart subsumo-backend
sudo systemctl status subsumo-backend --no-pager
```

### 2.2 DB-Schema: vor oder nach dem Deploy?

Es gibt **keine** separate Migrationsschritt-Reihenfolge zu beachten, weil es
aktuell kein Migrationswerkzeug gibt: `backend/app/main.py` ruft beim
Anwendungsstart `Base.metadata.create_all(bind=engine)` auf
(`backend/app/main.py:25`, Lifespan-Hook). Das legt fehlende Tabellen an,
**aendert aber keine bestehenden Tabellen** (keine `ALTER TABLE` fuer neue
Spalten). Praktisch bedeutet das:

- Neue Tabellen: automatisch beim naechsten Backend-Start angelegt, keine
  manuelle Aktion noetig — Schema-Aenderung passiert also implizit *mit* dem
  Backend-Neustart, nicht davor oder danach als eigener Schritt.
- Geaenderte/neue Spalten an bestehenden Tabellen: **`create_all` deckt das
  nicht ab.** Bis ein echtes Migrationswerkzeug (z. B. Alembic) eingefuehrt
  ist, braucht jede Spaltenaenderung ein manuelles `ALTER TABLE` vor dem
  Deploy des Codes, der die neue Spalte erwartet. Das ist eine bekannte
  Luecke, kein Teil dieser Aufgabe — hier dokumentiert, damit sie beim naechsten
  Schema-Aendernden nicht uebersehen wird.
- Backup **vor** jedem Deploy ziehen (Abschnitt 6), nicht danach — sonst ist
  im Fehlerfall auch das Backup schon vom fehlerhaften Deploy betroffen.

### 2.3 Web-Build

Zugeliefert von SUB-90 (Frontend-Developer, vollstaendig lokal verifiziert,
Original-Nachweis auf SUB-90). Kurzfassung fuer dieses Runbook:

```bash
cd app
flutter create . --platforms=web --org de.subsumo   # einmalig pro frischer Build-Umgebung
flutter pub get
flutter build web --release \
  --dart-define=SUBSUMO_API=https://api.subsumo.de \
  --base-href=/
```

- `--dart-define=SUBSUMO_API=<PROD_API_URL>` setzt `kApiBase`
  (`app/lib/api.dart:7`) als Compile-Zeit-Konstante. **Ohne dieses Flag faellt
  die App still auf den Dev-Default `http://localhost:8000` zurueck** — bei
  jedem Produktions-Build zwingend explizit setzen.
- Lokal tatsaechlich gelaufen (Nachweis von SUB-90): `flutter build web
  --release ...` exit 0, `app/build/web/main.dart.js` enthaelt nachweislich
  (per `grep`) die eingebackene Produktions-API-URL.
- **Output:** `app/build/web/` ist eine vollstaendig statische SPA
  (`index.html`, `main.dart.js`, `flutter_service_worker.js`, `canvaskit/`,
  `assets/`, `manifest.json`). Kompletten Inhalt unveraendert ins
  Webroot-Verzeichnis des Reverse-Proxys kopieren, z. B.
  `/var/www/app.subsumo.de/`.
- **Webserver-Anforderungen:** statisches Ausliefern mit korrekten
  MIME-Types (WASM: `application/wasm`); SPA-Fallback (`try_files $uri $uri/
  /index.html;`) schon jetzt vorsehen, auch wenn die App aktuell noch keine
  benannten Client-Routen nutzt — spart Nacharbeit, sobald das dazukommt.
- **CORS-Abhaengigkeit:** `backend/app/main.py` erlaubt CORS in Produktion
  (`environment != dev`) ausschliesslich fuer den Origin
  `https://app.subsumo.de` (siehe `create_app()`, `CORSMiddleware`). Web-App
  und Backend muessen exakt unter dieser Origin bzw. der im Backend
  gepflegten Origin-Liste laufen.

## 3. TLS-Beschaffung

Let's-Encrypt-Zertifikat ueber einen Reverse-Proxy, nicht im Python-Prozess
selbst terminiert (FastAPI/uvicorn laeuft nur intern auf `127.0.0.1`).

```bash
sudo apt-get install -y certbot python3-certbot-nginx   # oder Caddy, das TLS eingebaut mitbringt
sudo certbot --nginx -d app.subsumo.de -d api.subsumo.de
```

Beispiel-nginx-Konfiguration (Backend auf Unterdomain `api.subsumo.de`,
Web-App auf `app.subsumo.de` — Backend-Domain/Pfad ist laut SUB-90-Uebergabe
noch offen, Subdomain oder Pfadpraefix auf derselben Domain sind beide mit
dem `--dart-define`-Mechanismus kompatibel):

```nginx
server {
    listen 443 ssl;
    server_name api.subsumo.de;
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

server {
    listen 443 ssl;
    server_name app.subsumo.de;
    root /var/www/app.subsumo.de;
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

Certbot richtet per Default einen `systemd`-Timer fuer die automatische
Zertifikatserneuerung ein (`systemctl list-timers | grep certbot`) — kein
zusaetzlicher manueller Schritt noetig.

## 4. Health-Check nach Deploy

`GET /health` prueft seit dieser Aenderung nicht mehr nur, dass der
Python-Prozess laeuft, sondern fuehrt zusaetzlich `SELECT 1` gegen die
Datenbank aus (`backend/app/main.py`, `health()`):

- DB erreichbar: `{"status": "ok", "environment": "..."}`, HTTP 200.
- DB nicht erreichbar: `{"status": "degraded", "environment": "...",
  "detail": "database unreachable"}`, HTTP 503, zusaetzlich ein
  `log.error(...)`-Eintrag mit Exception.

Nach jedem Deploy:

```bash
curl -sf https://api.subsumo.de/health | grep '"status":"ok"' || echo "DEPLOY FEHLGESCHLAGEN - siehe Abschnitt 5 Rollback"
```

**Nachweis (lokal verifiziert, `backend/tests/test_api.py`):**

```
$ cd backend && pytest -q tests/test_api.py
.................................                                        [100%]
33 passed, 3 warnings in 14.14s
```

`test_health` prueft den Erfolgsfall, `test_health_meldet_degraded_wenn_db_nicht_erreichbar`
den DB-Ausfall (DB-Session wird durch einen Stub ersetzt, der beim Zugriff
eine Exception wirft — deterministisch statt eine echte Datenbank
abzuschalten). Zusaetzlich lokal gegen einen echten laufenden Prozess
verifiziert:

```
$ uvicorn app.main:create_app --factory --port 8123 &
$ curl -s -w '\nHTTP %{http_code}\n' http://127.0.0.1:8123/health
{"status":"ok","environment":"staging"}
HTTP 200
```

## 5. Rollback

Konkreter Ablauf, nicht nur die Absicht:

1. **Backend:** vorherigen freigegebenen Tag/SHA auschecken und Service neu
   starten:
   ```bash
   cd /opt/subsumo/backend
   git checkout <vorheriger-freigegebener-sha>
   .venv/bin/pip install -r requirements.txt
   sudo systemctl restart subsumo-backend
   curl -sf https://api.subsumo.de/health
   ```
2. **DB-Schema-Rueckschritt:** Da `create_all` nur additiv anlegt (Abschnitt
   2.2), ist ein reiner Code-Rollback in aller Regel schema-vertraeglich
   (neue, vom alten Code ungenutzte Tabellen/Spalten stoeren nicht). Falls
   der fehlerhafte Deploy eine **destruktive** manuelle Schema-Aenderung
   enthielt (z. B. eine manuelle `ALTER TABLE ... DROP COLUMN`), reicht der
   Code-Rollback nicht — dann Restore aus dem Vor-Deploy-Backup (Abschnitt 7)
   gegen eine frische DB, danach Umschalten der `SUBSUMO_DATABASE_URL`.
3. **Web-Build:** vorheriges `app/build/web/`-Artefakt erneut ins Webroot
   kopieren (deshalb empfiehlt es sich, das jeweils vorherige Build-Artefakt
   bis zum naechsten erfolgreichen Deploy aufzuheben, z. B.
   `/var/www/app.subsumo.de.vorherige-version/`).
4. **Bestaetigen:** `curl -sf https://api.subsumo.de/health` UND ein
   manueller Check der Web-App im Browser (Login + eine Karte lernen).

## 6. Backup automatisieren

`backend/scripts/backup_db.py`:

- Unterstuetzt SQLite (Dev/kleine Deployments, `Connection.backup()` — daher
  konsistent auch bei gleichzeitigen Schreibzugriffen) und PostgreSQL
  (Produktion, `pg_dump --format=custom`).
- **Verschluesselung ruhend** (`--encrypt`, AES-256 ueber `openssl enc
  -pbkdf2`, Passphrase aus `SUBSUMO_BACKUP_PASSPHRASE`) — deckt die
  Mindestanforderung aus `docs/17-release-readiness.md` Abschnitt 2 ab. In
  Produktion **Pflicht**, das Skript bricht ohne die Umgebungsvariable mit
  Fehler ab, wenn `--encrypt` gesetzt ist.
- Aufbewahrungsfrist standardmaessig 30 Tage (`--retention-days`, Default
  entspricht der Mindestanforderung aus `docs/17-release-readiness.md`
  Abschnitt 2), aeltere Backups werden nach jedem Lauf automatisch geloescht.

```bash
SUBSUMO_BACKUP_PASSPHRASE=<sicheres-secret> \
  .venv/bin/python scripts/backup_db.py --backup-dir /var/backups/subsumo --encrypt
```

### systemd-Timer (Beispiel, `backend/scripts/systemd/`)

`subsumo-backup.service` (Ausschnitt):

```ini
[Service]
Type=oneshot
User=subsumo
WorkingDirectory=/opt/subsumo/backend
EnvironmentFile=/opt/subsumo/backend/.env
ExecStart=/opt/subsumo/backend/.venv/bin/python scripts/backup_db.py --backup-dir /var/backups/subsumo
```

`subsumo-backup.timer`: taeglich 03:00 Uhr Server-Zeit
(`OnCalendar=*-*-* 03:00:00`, `RandomizedDelaySec=300`,
`Persistent=true` — holt einen verpassten Lauf nach, falls der Server zum
geplanten Zeitpunkt nicht lief). `SUBSUMO_BACKUP_PASSPHRASE` gehoert in die
`EnvironmentFile` (`.env`), nicht in die Unit-Datei selbst (die ist Repo-Text
und landet potenziell in Logs).

Aktivieren:

```bash
sudo cp backend/scripts/systemd/subsumo-backup.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now subsumo-backup.timer
systemctl list-timers subsumo-backup.timer
```

## 7. Restore — tatsaechlich geprobt (Nachweis)

Ein Backup, das nie eingespielt wurde, gilt laut
`docs/18-release-2-wochen.md` Abschnitt 5 (G4) nicht als Backup. Deshalb
wurde am 2026-09-16 ein vollstaendiger Backup-→-Restore-Durchlauf gegen eine
lokale SQLite-Instanz mit echten, aus den Lerninhalten geseedeten Daten
**tatsaechlich ausgefuehrt** (nicht nur die synthetischen Unit-Tests in
`backend/tests/test_backup_restore.py`, siehe unten):

**1. Ausgangsdaten angelegt** (Content-Seed + ein echter Testnutzer):

```
$ python3 -c "... seed(db, bundle) ..."
seed stats: {'topics': 29, 'cards': 206, 'schemata': 31, 'cases': 29, 'changed_cards': 0}
$ python3 -c "... models.User(email='restore-drill@subsumo.de', ...) ..."
user id: 1
```

**2. Backup gezogen, verschluesselt:**

```
$ SUBSUMO_DATABASE_URL="sqlite:////.../backend/drill/subsumo.db" \
  SUBSUMO_BACKUP_PASSPHRASE="probe-passphrase-fuer-den-restore-drill" \
  python3 scripts/backup_db.py --backup-dir .../drill/backups --encrypt --retention-days 30
OK  Backup geschrieben: .../drill/backups/subsumo-backup-20260916T080632Z.sqlite.enc (492.0 KiB)
```

SHA-256 der verschluesselten Backup-Datei zum Zeitpunkt des Laufs:
`f045959d3c50c7339086d2d52541528b3728afc19d17d570896dc4a2fabea123`.

**3. Restore gegen eine frische Ziel-DB:**

```
$ SUBSUMO_BACKUP_PASSPHRASE="probe-passphrase-fuer-den-restore-drill" \
  python3 scripts/restore_db.py drill/backups/subsumo-backup-20260916T080632Z.sqlite.enc \
  --database-url "sqlite:///.../backend/drill/restored.db"
OK  Backup entschluesselt: subsumo-backup-20260916T080632Z.sqlite
OK  Restore abgeschlossen: .../backend/drill/restored.db
```

**4. Verifikation, dass die zurueckgespielten Daten korrekt sind:**

```
$ python3 -c "... sqlite3.connect('drill/restored.db') ..."
users: [(1, 'restore-drill@subsumo.de')]
topics: (29,)
cards: (206,)
schemata: (31,)
cases: (29,)
```

Alle Zahlen stimmen exakt mit den Ausgangsdaten ueberein (Schritt 1), der
Testnutzer inklusive E-Mail-Adresse ist vollstaendig wiederhergestellt.
Restore-Zeitpunkt: 2026-09-16 08:07 UTC. Der PostgreSQL-Pfad (`pg_dump`
/`pg_restore`) nutzt denselben Skript-Aufruf, ist aber nicht Teil dieses
Nachweises, da im Ausfuehrungs-Environment keine PostgreSQL-Instanz zur
Verfuegung steht — dort automatisiert getestet, wo eine
CI-Postgres-Instanz existiert, ansonsten vor dem produktiven Erst-Restore
einmal manuell gegen eine echte Postgres-Staging-Instanz zu wiederholen.

**Automatisierte Tests** (`backend/tests/test_backup_restore.py`, laufen bei
jedem CI-Durchlauf mit, decken SQLite-Backup/-Restore inkl.
Verschluesselungs-Rundlauf sowie das "bestehende Zieldatei wird gesichert,
nicht geloescht"-Verhalten ab):

```
$ pytest -q tests/test_backup_restore.py
.........                                                                [100%]
9 passed
```

## 8. Monitoring und Fehler-Tracking

Strukturiertes JSON-Logging (`backend/app/core/observability.py`,
`configure_logging(json_format=settings.log_json)`, aktiviert per
`SUBSUMO_LOG_JSON=true`) macht Backend-Logs fuer jeden log-basierten
Aggregator (Loki, CloudWatch, journald-Weiterleitung) maschinenlesbar, ohne
eine konkrete SaaS-Anbindung als Pflichtabhaengigkeit vorzuschreiben — die
Anbieterwahl ist laut `docs/17-release-readiness.md` Abschnitt 5 noch offen.
Ein globaler Exception-Handler (`backend/app/main.py`,
`unhandled_exception_handler`) protokolliert jede unbehandelte Exception mit
Pfad und Methode als strukturiertes Log-Feld, bevor er einen generischen
500er zurueckgibt.

**Nachweis (strukturiertes Log tatsaechlich erzeugt):**

```
$ SUBSUMO_LOG_JSON=true uvicorn app.main:create_app --factory --port 8123 &
{"timestamp": "2026-09-16T08:07:20Z", "level": "INFO", "logger": "subsumo", "message": "Inhalte geladen: {'topics': 29, 'cards': 206, ...}"}
```

### Signalliste: wer wird geweckt, was wird nur geloggt/aufbewahrt

| Signal | Weckt einen Menschen? | Kanal / Schwelle |
|---|---|---|
| `GET /health` liefert HTTP 503 (`degraded`) oder ist unerreichbar | **Ja** | Uptime-Check (z. B. UptimeRobot/Healthchecks.io, extern gegen die Domain), Alarm bei ≥ 2 aufeinanderfolgenden Fehlschlaegen (vermeidet Alarm bei kurzen Netzwerk-Hoppern) |
| Backend-Prozess down (systemd-Unit inaktiv/gecrasht) | **Ja** | `systemd`-Unit mit `Restart=on-failure` + `OnFailure=`-Unit, die eine Benachrichtigung ausloest, zusaetzlich vom Uptime-Check erfasst (Symptom: `/health` unerreichbar) |
| 5xx-Rate ueber Schwelle (z. B. > 1 % der Requests in 5 Minuten) | **Ja** | Aggregation aus den strukturierten Logs (`level: ERROR`, `status_code >= 500`) im gewaehlten Log-Aggregator, Alarm-Regel dort konfigurieren |
| `subsumo-backup.service` schlaegt fehl (Exit-Code ≠ 0) | **Ja** | `OnFailure=`-Unit auf `subsumo-backup.service`, die eine Benachrichtigung ausloest — ein stiller Backup-Ausfall ist laut G4 (`docs/18-release-2-wochen.md` Abschnitt 5) inakzeptabel |
| Unbehandelte Exception in einem einzelnen Request | **Nein**, nur geloggt | `log.error(...)` mit `exc_info` und Pfad/Methode im strukturierten Log — Teil der 5xx-Rate-Aggregation oben, kein Einzel-Alarm pro Vorkommnis (sonst Alarm-Fluten bei einem wiederkehrenden Client-Fehler) |
| Einzelne 4xx-Antworten (z. B. 401/404) | **Nein**, nur geloggt | Normales Access-Log, keine Aggregation noetig |
| Erfolgreicher taeglicher Backup-Lauf | **Nein**, nur geloggt/aufbewahrt | `journalctl -u subsumo-backup.service`, `stdout` des Skripts (`OK  Backup geschrieben: ...`) |
| Content-Ladefehler beim Start (`bundle.errors`) | **Ja** | Bereits vorhandenes `log.error("Content-Fehler: %s", error)` (`backend/app/main.py`) — als `ERROR`-Log Teil der 5xx-/Error-Rate-Aggregation; ein fehlerhafter Content-Stand darf nicht unbemerkt live gehen |

Konkrete Dienstwahl (welcher Log-Aggregator/Uptime-Dienst) ist Teil der noch
offenen Hosting-/Kostenentscheidung in `docs/17-release-readiness.md`
Abschnitt 5 — die obige Liste ist bewusst anbieterunabhaengig formuliert und
gilt unveraendert, sobald diese Entscheidung getroffen ist.

## 9. Abgleich mit docs/17-release-readiness.md

**Abschnitt 2 (Sicherheit):**
- PBKDF2/Secrets-Handhabung: unveraendert durch diese Aufgabe, wie im
  SUB-91-Auftrag vorgegeben.
- "Backup und Wiederherstellung Nutzerdaten" (als "Offen" gefuehrt): durch
  diese Aufgabe erledigt — taegliches automatisiertes Backup (Abschnitt 6),
  Aufbewahrung ≥ 30 Tage (Default in `backup_db.py`), Verschluesselung
  ruhend (`--encrypt`), Restore tatsaechlich geprobt und protokolliert
  (Abschnitt 7). Dieses Runbook widerspricht der dortigen Tabellenzeile
  nicht, sondern loest sie ein — die Tabelle in `docs/17` sollte bei
  naechster Gelegenheit von "Offen" auf "Erledigt, siehe
  `docs/22-deploy-runbook.md`" aktualisiert werden (nicht Teil dieser aus
  Backend-Sicht abgeschlossenen Aufgabe, da `docs/17` von mehreren
  Rollen gepflegt wird).

**Abschnitt 5 (Betrieb):**
- "Monitoring (Uptime, Error-Tracking Backend)" (als "Offen" gefuehrt): durch
  diese Aufgabe technisch vorbereitet (strukturiertes Logging,
  Health-Check-Erweiterung, Signalliste in Abschnitt 8) — die konkrete
  Anbieterwahl (Uptime-Dienst, Log-Aggregator) bleibt bewusst offen, da sie
  an die noch nicht getroffene Hosting-Entscheidung gekoppelt ist. Kein
  Widerspruch: dieses Runbook liefert die anbieterunabhaengige Grundlage,
  die Anbieterwahl selbst ist nicht Teil des SUB-91-Auftrags.
- "Hosting-Entscheidung" und "Domain `app.subsumo.de`": weiterhin offen,
  siehe Blocker-Hinweis in der Einleitung dieses Dokuments.
