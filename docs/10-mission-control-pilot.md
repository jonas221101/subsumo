# Mission Control — erster Implementierungsschritt

Stand: 13. September 2026. Die interne Anbindung liegt in
`backend/mission_control/`, getrennt von den Routen und Daten der Lern-App.
Paperclip verwaltet Aufgaben, Kommentare und Agentenläufe. Diese Implementierung
erstellt keine zweite Aufgaben-Datenbank und startet keine Modellaufrufe selbst.

## Was funktioniert

- Aufgaben auflisten und mit Abnahmekriterien, Zuständigkeit und Elternaufgabe anlegen.
- Eigene Aufgaben atomar beanspruchen; Konflikte werden als Fehler zurückgegeben.
- Gespeicherte Aufgabenthreads seitenweise lesen.
- Agenten direkt per strukturierter Erwähnung adressieren, Fragen und Antworten
  mit eindeutigen Nachrichten- und Kommentarreferenzen austauschen.
- Einen konkreten Commit samt Nachweisen an einen Reviewer übergeben: Eine
  Review-Interaction öffnen und danach Status, Zuständigkeit und
  Übergabenachricht in einem PATCH ändern.
- Identitäten, Firmenzuordnung, Kommentarautor und Empfänger vor dem Senden prüfen.
- Keine automatische Wiederholung von Schreibzugriffen bei unklaren Ergebnissen.
- Jede beabsichtigte Änderung landet **vor** dem Absenden in einem lokalen,
  append-only Journal (`.mission-control/outbox.jsonl`); `reconcile` gleicht
  offene Einträge rein lesend gegen den Server ab und sendet niemals nach.
- Eine Review-Übergabe verlangt einen Commit, der lokal wirklich existiert und
  von einem Remote-Branch aus erreichbar ist — sonst könnte der Reviewer ihn
  gar nicht abrufen.
- Bestehende Redaktionsfreigaben strikt validieren: echte Booleans, erforderliche
  Felder, gültige Schweregrade, keine widersprüchlichen Freigaben oder doppelten Keys.

Die API-Verträge sind mit `httpx.MockTransport` getestet. Ein echter Paperclip-
Server, Modellzugänge und GitHub-Zugänge sind noch nicht für den Pilot konfiguriert.
Es wurde kein bezahlter Modelllauf durch diese neue Anwendung gestartet.

## Voraussetzungen und Trennung

Benötigt werden Python >= 3.11, die Backend-Abhängigkeiten und eine separat
betriebene Paperclip-Instanz. Installiere und fixiere Paperclip gemäß dessen
offizieller Anleitung; der Pilot muss anschließend gegen die eingesetzte Version
geprüft werden. Hier wird kein ungeprüftes `latest` im Hintergrund installiert.

Die CLI verwendet die von Paperclip in einen Agentenlauf injizierten Variablen:

| Variable | Bedeutung |
|---|---|
| `PAPERCLIP_API_URL` | Serverbasis, z. B. `http://localhost:3100`, ohne `/api` |
| `PAPERCLIP_API_KEY` | Authentifizierung; niemals einchecken oder als Argument übergeben |
| `PAPERCLIP_COMPANY_ID` | Zugehörige Firma |
| `PAPERCLIP_AGENT_ID` | Identität des ausführenden Agenten |
| `PAPERCLIP_RUN_ID` | Aktueller, von Paperclip vergebener Lauf |

Agenten- und Run-IDs niemals für einen echten Lauf erfinden. Operatoren können
mit ihrem Board-Token Aufgaben lesen und anlegen; Agentenkommunikation und
Checkout benötigen einen echten Agentenlauf. Die CLI liest Variablen aus der
Prozessumgebung; sie lädt keine `.env`-Datei automatisch.

Auch lokal ist ein Token erforderlich. HTTPS ist verpflichtend außer für
Loopback-Adressen. Redirects werden nicht verfolgt. Konfiguration und kontrollierte
HTTP-Fehler geben keine Tokens oder Server-Antworttexte aus. Rechte und Locks
muss Paperclip serverseitig erzwingen; Rollenbeschreibungen ersetzen das nicht.

## Lokal starten und testen

Regulär die Projektumgebung nach `README.md` einrichten. In dieser Arbeitssitzung
war `backend/.venv` an eine nicht mehr vorhandene Python-3.11-Installation gebunden.
Deshalb wurde separat `work/mission-control/.venv` mit Python 3.14 erstellt; die
bestehende Umgebung wurde nicht überschrieben. Aus der Repository-Wurzel:

```powershell
work/mission-control/.venv/Scripts/python.exe -m pip install -r backend/requirements-dev.txt
cd backend
../work/mission-control/.venv/Scripts/python.exe -m mission_control --help
../work/mission-control/.venv/Scripts/python.exe -m pytest -q
../work/mission-control/.venv/Scripts/python.exe -m ruff check .
```

Die CI bleibt auf Python 3.11 konfiguriert. Nachfolgende Beispiele nutzen `python`
aus der jeweils aktivierten Projektumgebung und werden aus `backend/` ausgeführt.

Eine Aufgabe zunächst vollständig offline ansehen, ohne Token oder Server:

```powershell
python -m mission_control create --title "Content-Deltas laden" --criteria "Cache bleibt nach Netzfehler erhalten; Offline-Test besteht" --dry-run
```

Nach Bereitstellung der Paperclip-Variablen die Verbindung prüfen und Aufgaben lesen:

```powershell
python -m mission_control doctor
python -m mission_control tasks --mine --status todo,in_progress,in_review
python -m mission_control thread SUB-101 --limit 100
```

Bei mehr Kommentaren mit `--after KOMMENTAR_ID` weiterblättern. Die vollständige
Serverantwort bleibt erhalten; die CLI liest nicht stillschweigend nur den ersten
Abschnitt eines Threads als vollständiges Gespräch.

Aufgaben anlegen und zuweisen:

```powershell
python -m mission_control create --title "Delta-Sync implementieren" --criteria "Geänderte Karten werden synchronisiert; Outbox bleibt erhalten" --assignee DEVELOPER_UUID --ready
python -m mission_control claim SUB-101
```

Ohne `--ready` wird `backlog` verwendet. Bereits eine Zuweisung kann abhängig von
der Paperclip-Konfiguration einen Agenten aktivieren; `backlog` allein ist keine
Garantie für einen kostenfreien Ruhezustand. Änderungen mit `--dry-run` führen
keine API-Aufrufe aus. `claim --resume` kann einen verwaisten eigenen Lauf übernehmen;
ein tatsächlich noch aktiver Lauf muss vom Server weiter mit 409 geschützt werden.

## Agentenkommunikation

Fragen und Nachweise als UTF-8-Datei im Arbeitsbereich vorbereiten. Die Nachricht
geht an eine konkrete Agent-ID und verändert die Aufgabenzuständigkeit nicht:

```powershell
python -m mission_control send SUB-101 --to BACKEND_AGENT_UUID --kind question --body-file frage.md
python -m mission_control send SUB-101 --to FRAGENDER_AGENT_UUID --kind answer --reply-to KOMMENTAR_UUID --body-file antwort.md
```

`--to` und `--reply-to` erwarten echte UUIDs; die Namen oben sind Platzhalter.
Die Antwort prüft den tatsächlichen Autor des referenzierten Kommentars.
Der Server bestätigt den gespeicherten Kommentar; das ist noch keine Bestätigung,
dass der Empfänger bereits geantwortet hat. Paperclip steuert Aktivierung und Lauf.

Der Kommentar enthält genau eine strukturierte Erwähnung und eine versionierte
JSON-Nutzlast (`subsumo.message.v1`). Darin stehen Absender, Empfänger, Aufgabe,
Lauf, Nachrichtentyp, Zeit und Antwortbezug. Weitere Erwähnungen und Markdown-
Codezäune im Inhalt werden im JSON escaped, damit der Text keine zusätzlichen
Empfänger aktiviert. Die Originalnachricht bleibt per JSON-Dekodierung erhalten.

Eine Rückfrage an einen pausierten oder beendeten Empfänger wird in dieser ersten
Version lokal abgelehnt. Eine dauerhafte Inbox für solche Empfänger, automatische
Antwortfristen und Zustellquittungen sind noch offen. Rollenbeschreibungen fordern
Agenten auf, nach Rückfragen den Lauf zu beenden; Endlosschleifen werden bislang
nicht durch einen zusätzlichen Subsumo-Scheduler kontrolliert.

## Übergabe zum Review

```powershell
python -m mission_control request-review SUB-101 --to REVIEWER_UUID --commit VOLLSTAENDIGER_40STELLIGER_SHA --body-file nachweise.md
```

Das setzt eine eigene Aufgabe in `in_progress` voraus. Gegen die echte, lokal
laufende Pilotinstanz lehnt der Server einen reinen Status- und
Zuständigkeitswechsel nach `in_review` mit HTTP 422
(`invalid_issue_disposition`) ab: Ein Agentenschreibzugriff nach `in_review`
braucht einen echten, vom Server erkannten Review-Pfad. Deshalb öffnet die
CLI zuerst per `POST /api/issues/{id}/interactions` eine
`request_confirmation`-Interaction an den Reviewer und übergibt deren `id`
im anschließenden PATCH als `reviewInteractionId` — das erfüllt die
Disposition `pending_issue_thread_interaction`. Commit und Nachweise
bleiben wie bisher im `comment`-Feld desselben PATCH.

Das bislang ebenfalls im PATCH vorgesehene Feld `reviewRequest` (Freitext-
Anweisungen für den Reviewer) wird hier bewusst **nicht** gesetzt: Live gegen
den Pilotserver getestet, verlangt `reviewRequest` zusätzlich eine bereits
bestehende Review- oder Freigabe-Stage (z. B. aus einer `executionPolicy`);
ohne diese lehnt der Server auch die Kombination mit einer gültigen
`reviewInteractionId` mit `reviewRequest requires an active review or
approval stage` ab. `client.update_issue()` unterstützt den Parameter
weiterhin für Aufrufer, die eine solche Stage bereits eingerichtet haben.

Der Reviewer nimmt die Aufgabe in seinem eigenen Lauf mit `claim SUB-101 --review` an.
Seine fachlichen Rückfragen und Befunde laufen wieder über `send`.

Der angegebene SHA wird lokal gegen das Repository geprüft (`--repo`, Standard:
aktuelles Verzeichnis): Existiert der Commit nicht, wird die Übergabe abgelehnt
und ist auch nicht erzwingbar. Existiert er nur lokal, ist er für den Reviewer
nicht abrufbar — das bricht ebenfalls ab, lässt sich aber mit `--allow-unpushed`
bewusst zur Warnung herabstufen. `--no-verify-commit` überspringt die Prüfung
für den Einsatz außerhalb eines Git-Checkouts und sagt das auch deutlich.

Noch **nicht** geprüft wird, ob für diesen Commit CI-Ergebnisse vorliegen und
grün sind; das bleibt am Reviewer und an den übergebenen Nachweisen. Ein
Kommentar vom Typ `decision` löst keinen Merge und keine Erledigung aus.

## Zustellfehler und Wiederholungen

Nach Schreib-Timeout oder Serverfehler kann die Aktion bereits gespeichert sein.
Die CLI wiederholt den Request deshalb nicht. Bei Nachricht und Review-Übergabe
meldet sie die erzeugte Nachrichten-ID: Thread und Aufgabenstatus damit abgleichen,
bevor erneut gesendet wird. Die ID ist eine Korrelationshilfe, kein serverseitiger
Idempotenzschlüssel. Bei fehlendem Nachweis nicht blind erneut senden.

Auch `create` wird bei Fehlern nicht automatisch wiederholt. 409 bei Checkout
bedeutet Konflikt, keine Erlaubnis, einen zweiten Worker für dieselbe Aufgabe
zu starten.

Damit ein unklarer Ausgang nachträglich aufklärbar bleibt, schreibt die CLI
jede beabsichtigte Änderung **vor** dem Absenden in ein append-only Journal
(`<state-dir>/outbox.jsonl`, Standard `.mission-control/`, umlenkbar über
`--state-dir` oder `MISSION_CONTROL_STATE_DIR`). Statusänderungen hängen eine
neue Zeile an, statt bestehende zu überschreiben; ein abgebrochener Schreibvorgang
kostet höchstens die letzte Zeile:

```powershell
python -m mission_control reconcile            # alle offenen Eintraege
python -m mission_control reconcile SUB-101 --dry-run
```

`reconcile` sucht die Korrelations-ID des Eintrags im gespeicherten Thread —
seitenweise über den ganzen Thread, nicht nur auf der ersten Seite — und setzt
den Eintrag nur dann auf bestätigt. Es sendet nichts nach: Alle Aufrufe sind
GET. Lässt sich eine Serverantwort nicht lesen, wird der Eintrag als
*nicht abgleichbar* gemeldet statt stillschweigend als "nie angekommen" — sonst
wäre genau der doppelte Versand die Folge, den das Journal verhindern soll.

Solange für eine Aufgabe ein offener Eintrag existiert, verweigert die CLI
einen weiteren `send` bzw. `request-review` auf dieselbe Aufgabe und nennt die
Eintrags-ID. `--force` umgeht das bewusst. Das ersetzt keinen serverseitigen
Idempotenzschlüssel; Paperclip bleibt die maßgebliche Instanz.

## Günstige Agenten einsetzen

Die Implementierung wurde mit drei `gpt-5.6-luna`-Subagenten für Entwicklung und
unabhängiges Review erarbeitet. Das ist die Modellauswahl dieser Coding-Sitzung.
Die Paperclip-Laufzeiten sind separat zu konfigurieren; interne Modellnamen dieser
Sitzung sind nicht automatisch gültige Modell-IDs eines API-Anbieters.

Vorbereitete Rollen: `ops/agents/planner.md`, `developer.md`, `reviewer.md`.
Diese Texte im gewählten Paperclip-Adapter als Arbeitsanweisung hinterlegen.
Ein günstiges verfügbares Modell explizit auswählen, höchstens zwei Worker
gleichzeitig starten und kleine Aufgaben verwenden. Lauf- und Kostenlimits im
Server konfigurieren und messen. Die CLI selbst ruft kein Modell auf und
erzwingt keine Tokenbudgets. Eine automatische Hochstufung zu teureren Modellen
ist nicht implementiert.

## Nächste Integration

1. **Vorbereitet:** Paperclip `v2026.831.1` ist über
   `ops/mission-control/start-paperclip-pilot.ps1` für eine getrennte,
   lokale Loopback-Pilotinstanz fixiert. Die tatsächliche Pilot-Firma wird im
   lokalen Board angelegt.
2. Rollen, Modell, Budgets, isolierte Workspaces und echte Run-Authentifizierung verbinden.
3. ~~Einen realen Frage-/Antwortlauf sowie eine Review-Übergabe nachweisen~~
   **erledigt** (SUB-21, gegen die echte lokale Pilotinstanz, nichts gemockt):
   Frage an den Reviewer-Agenten (`965fee47-…`) über
   `mission_control send SUB-21 --kind question`, Kommentar
   `7b7a2302-e092-450f-a46c-471149d6e413` (message_id
   `377101c7-850e-4d16-ab6e-b1b18438735e`); Antwort per `--kind answer
   --reply-to` in Kommentar `120b8f22-d0cb-4141-87d8-51866e58a870`
   (message_id `cd3ab99e-b074-4b1f-ba2b-951e3a2f7267`). Anschließend
   `request-review SUB-21 --to 965fee47-… --commit <SHA des Docs-Commits>`
   für die Review-Übergabe; der Reviewer hat mit `claim SUB-21 --review`
   angenommen, den Commit unabhängig gegen den echten Thread geprüft und in
   Kommentar `e9f5aba5-a02c-421d-80b8-7aadc2e8d949` freigegeben (dazu ein
   nicht blockierender Befund in Kommentar
   `1c4c73de-f6c8-46b1-a5ef-9689c6913e3f`). `reconcile` bestätigt beide
   Vorgänge gegen den echten Thread. Details und alle IDs im
   SUB-21-Kommentar auf SUB-10.
4. ~~Persistente Zustellgarantien~~ **erledigt** (Journal + `reconcile`); offen
   bleiben Antwortfristen, Zustellquittungen und Nacharbeit.
5. ~~Software-Review an aktuellen Commit binden~~ **erledigt**; offen bleibt die
   Bindung an erforderliche CI-Ergebnisse.
6. GitHub-PR, kontrollierten Merge und Abschlussverifikation anbinden.
7. ~~Mission-Control-Oberfläche auf die echten Zustände und Threads umstellen~~
   **zurückgestellt, keine Priorität:** Auf Nutzerrückfrage zu SUB-10
   (Interaction `c64cc55a-9630-4560-b142-ff76152fbc12`) hin klargestellt, dass
   damit nicht dieses interne Tooling-Dashboard gemeint war, sondern UI und CI
   der eigentlichen Lern-App (`app/`). Ein separates Mission-Control-Dashboard
   wird vorerst nicht verfolgt. Scoping des Lernapp-UI/CI-Bedarfs läuft unter
   SUB-29.

## Referenzen

- [Paperclip Issues API](https://docs.paperclip.ing/reference/api/issues/)
- [Paperclip Authentifizierung](https://docs.paperclip.ing/reference/api/authentication/)
- [Aufgabenthreads und strukturierte Erwähnungen](https://docs.paperclip.ing/guides/day-to-day/issues/)
- [Agentenlebenszyklus](https://github.com/paperclipai/paperclip/blob/master/docs/guides/agent-developer/how-agents-work.md)
