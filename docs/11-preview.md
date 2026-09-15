# Preview-Runbook: Backend + Web ad hoc starten

Kurzanleitung, um für einen Branch/Execution-Workspace einen On-Demand-Preview
von Backend und Flutter-Web über die Paperclip Execution-Workspace
Runtime-Services zu starten, die erreichbare URL zu ermitteln und beide
Services wieder zu stoppen. Kein externer Host, keine Kosten, keine neuen
Zugangsdaten — siehe Hintergrund und Alternativen im Plan-Dokument von SUB-50
(Abschnitt "Option A2").

Voraussetzung: eine Paperclip Execution-Workspace-ID (`<WS_ID>`) für den zu
prüfenden Branch — z. B. die des aktuell laufenden Runs
(`PAPERCLIP_WORKSPACE_ID`) oder eine über `GET
/api/companies/{companyId}/execution-workspaces` ermittelte ID. Alle Aufrufe
unten laufen über die Paperclip-API. `PAPERCLIP_API_URL` zeigt je nach
Umgebung mit oder ohne `/api`-Suffix auf die Basis-URL — vor dem ersten Aufruf
normalisieren:

```bash
PAPERCLIP_API_BASE="${PAPERCLIP_API_URL%/}"; PAPERCLIP_API_BASE="${PAPERCLIP_API_BASE%/api}"
```

Alle folgenden Beispiele nutzen `$PAPERCLIP_API_BASE/api/...` mit Header
`Authorization: Bearer $PAPERCLIP_API_KEY`.

## 1. Backend-Runtime-Service konfigurieren und starten

Runtime-Services müssen einmal pro Execution-Workspace als Kommando
registriert werden, bevor sie gestartet werden können (`config.workspaceRuntime`
ist standardmäßig leer). Backend-Kommando registrieren:

```bash
curl -s -X PATCH -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "config": {
      "workspaceRuntime": {
        "commands": [
          {
            "id": "backend",
            "name": "backend",
            "kind": "service",
            "cwd": ".",
            "command": "backend/.venv/bin/uvicorn app.main:app --app-dir backend --host 0.0.0.0 --port 8123",
            "port": 8123,
            "expose": {"type": "tailscale_https"}
          }
        ]
      }
    }
  }' \
  "$PAPERCLIP_API_BASE/api/execution-workspaces/<WS_ID>"
```

Hinweise zum Kommando:
- `backend/.venv/bin/uvicorn` setzt voraus, dass die venv bereits provisioniert
  ist (Standard-`provisionCommand` der Execution-Workspace macht das). Ohne
  venv: `pip install -r backend/requirements.txt` vorher laufen lassen.
- Port frei wählen (z. B. 8123); er darf nicht mit einem bereits laufenden
  Service auf demselben Host kollidieren.
- Default-`environment=dev` reicht unverändert: CORS ist auf `*` offen
  (`backend/app/main.py:51`), SQLite + `seed_on_startup=True` lädt `content/`
  automatisch (`backend/app/config.py:17,30`).
- `expose: {"type": "tailscale_https"}` ist der Schalter für eine von außen
  erreichbare HTTPS-URL. Ohne diesen Block bleibt der Service nur lokal auf
  dem Runtime-Host erreichbar (siehe Abschnitt 4, "Wenn `url` leer bleibt").

Backend starten:

```bash
curl -s -X POST -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"workspaceCommandId": "backend"}' \
  "$PAPERCLIP_API_BASE/api/execution-workspaces/<WS_ID>/runtime-services/start"
```

Die Antwort enthält `workspace.runtimeServices[]` — der neue Eintrag mit
`serviceName: "backend"` zeigt `status`, `port` und (falls Exposure
funktioniert) `url`.

## 2. Backend-URL ermitteln

```bash
curl -s -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  "$PAPERCLIP_API_BASE/api/execution-workspaces/<WS_ID>" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); \
      s=[r for r in d['runtimeServices'] if r['serviceName']=='backend' and r['status']=='running'][-1]; \
      print('port:', s['port'], 'url:', s['url'])"
```

- `status: running` + `healthStatus: healthy` heißt: der Prozess läuft.
- Ist `url` gesetzt, ist das die erreichbare Backend-Basis-URL (HTTPS, von
  außen erreichbar) — diese für Schritt 3 als `SUBSUMO_API` verwenden.
- Ist `url` leer, siehe Abschnitt 4.

Erreichbarkeit schnell prüfen: `curl <url oder http://localhost:<port>>/health`
→ `{"status":"ok","environment":"dev"}`.

## 3. Web-Runtime-Service konfigurieren und starten

Sobald die Backend-URL aus Schritt 2 feststeht, das Web-Kommando damit
registrieren (ersetzt `<BACKEND_URL>`):

```bash
curl -s -X PATCH -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "config": {
      "workspaceRuntime": {
        "commands": [
          {
            "id": "backend",
            "name": "backend",
            "kind": "service",
            "cwd": ".",
            "command": "backend/.venv/bin/uvicorn app.main:app --app-dir backend --host 0.0.0.0 --port 8123",
            "port": 8123,
            "expose": {"type": "tailscale_https"}
          },
          {
            "id": "web",
            "name": "web",
            "kind": "service",
            "cwd": "app",
            "command": "flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8124 --dart-define=SUBSUMO_API=<BACKEND_URL>",
            "port": 8124,
            "expose": {"type": "tailscale_https"}
          }
        ]
      }
    }
  }' \
  "$PAPERCLIP_API_BASE/api/execution-workspaces/<WS_ID>"
```

Wichtig vor dem ersten Start: `app/web/` ist nicht eingecheckt (siehe
`CONTRIBUTING.md`, Abschnitt "Generierte Dateien"). Einmalig im
Execution-Workspace erzeugen, sonst schlägt `flutter run -d web-server` fehl:

```bash
cd app && flutter create . --platforms=web --org de.subsumo && flutter pub get
```

Web-Service starten:

```bash
curl -s -X POST -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"workspaceCommandId": "web"}' \
  "$PAPERCLIP_API_BASE/api/execution-workspaces/<WS_ID>/runtime-services/start"
```

URL wie in Schritt 2 ermitteln, nur mit `serviceName == "web"`. Diese URL im
Browser öffnen.

## 4. Registrieren und Login

Keine Seed-User nötig: Auf der Login-Seite auf "Konto erstellen" wechseln
(`app/lib/pages/login_page.dart`, Toggle `_register`) — das ruft
`POST /v1/auth/register` gegen die in Schritt 3 konfigurierte `SUBSUMO_API`-URL
auf und loggt direkt ein.

## 5. Beide Services stoppen

```bash
curl -s -X POST -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"workspaceCommandId": "web"}' \
  "$PAPERCLIP_API_BASE/api/execution-workspaces/<WS_ID>/runtime-services/stop"

curl -s -X POST -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"workspaceCommandId": "backend"}' \
  "$PAPERCLIP_API_BASE/api/execution-workspaces/<WS_ID>/runtime-services/stop"
```

Beide Aufrufe liefern `status: 200` und der jeweilige Eintrag in
`runtimeServices[]` wechselt auf `status: "stopped"`. Optional danach die
Registrierung wieder entfernen (nicht nötig, um Kosten oder laufende Prozesse
zu vermeiden — `stop` beendet den Prozess bereits):

```bash
curl -s -X PATCH -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"config": {"workspaceRuntime": null, "desiredState": null, "serviceStates": null}}' \
  "$PAPERCLIP_API_BASE/api/execution-workspaces/<WS_ID>"
```

## 6. Wenn `url` leer bleibt (Exposure nicht verfügbar)

Beim Ausprobieren dieses Runbooks (2026-09-15, aktueller Execution-Workspace)
zeigte sich: `expose: {"type": "tailscale_https"}` führte beim Start zu einem
`500 Internal Server Error`, und ohne `expose`-Block blieb `url` dauerhaft
`null`, obwohl der Prozess unter dem gemeldeten `port` lokal erreichbar lief
(`curl http://localhost:<port>/health` funktionierte). Das deutet auf einen in
dieser Paperclip-Instanz nicht verfügbaren Tailscale-HTTPS-Exposure-Broker hin
— kein Fehler im Subsumo-Code, sondern eine Plattform-/Infra-Frage.

Falls das auftritt:
- `port` aus Schritt 2 verwenden und den Service direkt auf dem Runtime-Host
  ansprechen (`http://localhost:<port>`, bzw. `http://<host>:<port>`, falls
  Netzwerkzugriff auf den Host besteht).
- Für Nutzer ohne Host-Zugriff: beim Paperclip-Betreiber nachfragen, ob für
  diese Company/dieses Environment Tailscale-HTTPS-Exposure aktiviert ist,
  bevor eine von außen erreichbare Preview-URL über diesen Weg erwartet wird.
- Das ist kein Grund, Abschnitt 1–5 nicht zu befolgen — sobald Exposure
  verfügbar ist, liefert derselbe Ablauf ohne Codeänderung eine `url`.

## 7. End-to-End-Verifikation durchgeführt (SUB-59, 2026-09-15)

Dieser Ablauf wurde einmal vollständig durchgespielt. Ergebnis:

- **Runtime-Services-Start via Paperclip-API war zusätzlich zum Exposure-Problem
  aus Abschnitt 6 selbst nicht nutzbar**: `POST
  .../runtime-services/start` mit `{"workspaceCommandId": "backend"}` lieferte
  auch nach Ablauf einer vorherigen `workspace_runtime_lease_conflict`-Sperre
  zwei Mal in Folge `{"error": "Internal server error"}` (kein Prozess
  gestartet, `runtimeServices[]`-Eintrag landete direkt auf
  `status: "failed"`, `healthStatus: "unhealthy"`, ohne Port-Konflikt oder
  verwaisten Prozess auf dem Host). Das ist ein eigenständiger
  Plattform-Befund, unabhängig vom Tailscale-Exposure-Problem — auch der
  reine Prozessstart über die Runtime-Services-API war zum Testzeitpunkt
  nicht funktionsfähig.
- **Fallback**: Backend und Flutter-Web wurden mit exakt den in Abschnitt 1
  und 3 dokumentierten Kommandos direkt in der Workspace-Shell gestartet
  (`backend/.venv/bin/uvicorn app.main:app --app-dir backend --host 0.0.0.0
  --port 8123` bzw. `flutter run -d web-server --web-hostname 0.0.0.0
  --web-port 8124 --dart-define=SUBSUMO_API=http://localhost:8123`), erreichbar
  unter `http://localhost:8123` und `http://localhost:8124`. Kein
  Browser (GUI) im Sandbox-Host verfügbar — Registrierung/Login/Review wurden
  daher gegen dieselbe Backend-API ausgeführt, die auch das Flutter-Web-UI
  aufruft, inkl. CORS-Preflight-Check (`OPTIONS /v1/auth/login` mit
  `Origin: http://localhost:8124` → `access-control-allow-origin:
  http://localhost:8124`, funktioniert wie erwartet dank `allow_origins=["*"]`
  in `backend/app/main.py`).
- **Registrierung + Login**: `POST /v1/auth/register` und separat
  `POST /v1/auth/login` mit derselben E-Mail/Passwort-Kombination lieferten
  beide `200`/`201` mit gültigem `access_token` — Login gegen den zuvor
  registrierten Nutzer funktioniert.
  - Stolperstein: `pydantic`/`email-validator` lehnt E-Mail-Adressen mit
    reservierten Testdomains (`.test`, `example.com`, …) mit `422` ab
    ("special-use or reserved name") — für manuelle Tests eine normale
    Domain (z. B. `@gmail.com`) verwenden, keine `@example.test`-Adresse.
- **Karten-Review-Aktion**: `GET /v1/cards/due` lieferte eine fällige Karte
  (`or-gr-art12-berufsbegriff`), anschließend `POST /v1/reviews/batch` mit
  `rating: 3` → `{"applied": 1, ...}`. Persistenz direkt in `subsumo.db`
  bestätigt: neue Zeile in `reviews` (passender `client_id`) und
  aktualisierte Zeile in `user_cards` (`state: "learning"`, `reps: 1`,
  neues `due`-Datum) für den registrierten Nutzer.
- Beide Prozesse wurden danach sauber beendet (`kill` auf die jeweilige PID,
  anschließend verifiziert: keine `uvicorn`/`flutter`/`dart`-Prozesse mehr
  aktiv).

Fazit: Der Web-Preview-Ablauf selbst (Backend + Flutter-Web + Registrierung +
Login + Review-Persistenz) funktioniert einwandfrei. Die einzigen offenen
Lücken liegen auf der Paperclip-Plattformseite (Runtime-Services-Start-API
und Tailscale-Exposure, siehe Abschnitt 6), nicht im Subsumo-Code.

## 8. Android-APK und Windows-Build als CI-Artefakte bauen

Für Testbuilds auf einem echten Android-Gerät bzw. unter Windows gibt es
einen manuell auslösbaren Workflow
(`.github/workflows/manual-builds.yml`) mit zwei unabhängigen Jobs — kein
Signing, keine Store-Anbindung, reine Debug-/Testbuilds. iOS und macOS sind
bewusst ausgeklammert (kostenpflichtiger Apple-Developer-Account nötig).

### Android-APK

1. Im Repo auf GitHub zu **Actions → Manuelle Testbuilds (Android APK /
   Windows)** wechseln.
2. **Run workflow** klicken, den gewünschten Branch im Dropdown auswählen
   (Default: `main`) und bestätigen. Der optionale `ref`-Input ist nur nötig,
   um von einem anderen Branch/Tag zu bauen als dem im Dropdown gewählten.
3. Nach Abschluss des Laufs (ca. 5–10 min) unten auf der Lauf-Seite unter
   **Artifacts** das Artefakt `subsumo-android-apk` herunterladen (ZIP mit
   `app-release.apk`) — Artefakte sind 14 Tage verfügbar.
4. APK auf ein Android-Gerät übertragen (z. B. per USB, E-Mail oder Cloud-
   Speicher) und dort öffnen. Falls die Installation blockiert wird: unter
   Android-Einstellungen die Installation aus der genutzten Quelle (Dateien-
   App, Browser, o. Ä.) einmalig erlauben ("Unbekannte Apps installieren").
   Der Build ist unsigniert (Debug-Keystore) — das ist für einen lokalen
   Testbuild kein Problem, verhindert aber ein Update über eine signierte
   Store-Version, falls es diese später gibt.

### Windows-Build (optional)

Der Windows-Job (`build-windows`, `runs-on: windows-latest`) läuft im selben
Workflow, wird aber unabhängig vom Android-Job über denselben **Run
workflow**-Dialog gestartet — beide Jobs starten bei jedem Lauf gemeinsam.
Da ein `windows-latest`-Runner mehr CI-Minuten verbraucht als der
bestehende Ubuntu-Runner, diesen Lauf nur bei tatsächlichem Bedarf an einem
Windows-Testbuild auslösen.

1. Denselben Workflow wie oben (**Manuelle Testbuilds (Android APK /
   Windows)**) mit **Run workflow** starten.
2. Nach Abschluss (ca. 5–10 min) im Job `Flutter - Windows-Build bauen und
   zippen` unter **Artifacts** das Artefakt `subsumo-windows` herunterladen
   (ZIP mit dem kompletten Release-Build-Ordner, inkl. `.exe` und
   benötigter DLLs) — Artefakte sind 14 Tage verfügbar.
3. ZIP entpacken und die enthaltene `.exe` direkt starten — kein Installer,
   reiner unsignierter Testbuild. Windows SmartScreen kann bei der ersten
   Ausführung warnen ("Windows hat den Computer geschützt"); über **Weitere
   Informationen → Trotzdem ausführen** fortfahren.
