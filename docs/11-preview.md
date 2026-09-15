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

## 7. Android-APK als CI-Artefakt bauen

Für einen Testbuild auf einem echten Android-Gerät gibt es einen manuell
auslösbaren Workflow (`.github/workflows/android-apk.yml`) — kein Signing,
keine Play-Store-Anbindung, reiner Debug-Testbuild. iOS ist bewusst
ausgeklammert (kostenpflichtiger Apple-Developer-Account nötig).

1. Im Repo auf GitHub zu **Actions → Android APK (manueller Build)**
   wechseln.
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
