# Paperclip-Pilot

Dieses Verzeichnis startet eine getrennte, lokale Mission-Control-Instanz. Es
ist ausschließlich für den Pilot bestimmt und teilt weder Daten noch Secrets
mit dem Lern-Backend.

## Start

Aus der Repository-Wurzel in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\ops\mission-control\start-paperclip-pilot.ps1
```

Der Start pinnt Paperclip auf `v2026.831.1`, richtet einen privaten,
vertrauenswürdigen Loopback-Dienst ein und führt `onboard` aus. Paperclip
verwendet bevorzugt Port 3100 und meldet bei Belegung die tatsächlich gewählte
freie Loopback-Adresse im Startprotokoll. Der erzeugte Zustand liegt in
`work/mission-control/paperclip/` und ist über die Wurzel-`.gitignore`
ausgeschlossen. Die lokale Instanz darf nicht auf LAN oder Internet erweitert
werden; dafür ist später ein separater authentifizierter Betrieb nötig.

Nach dem Start im Board eine eigene Firma und ein Projekt
`Subsumo Mission Control Pilot` erstellen und
jeweils einen Planner-, Developer- und Reviewer-Agenten mit den Anweisungen
aus `ops/agents/` anlegen. Für Coding-Runs braucht der ausgewählte Adapter ein
explizit hinterlegtes Modell und dessen Zugangsdaten; im Docker-/lokalen
Adapter nur für den jeweiligen Agenten hinterlegen.

## Pilotablauf

1. Drei kleine Aufgaben anlegen, jeweils mit Abnahmekriterien und Reviewer.
2. Einen echten Agentenlauf starten und dessen von Paperclip gesetzte
   `PAPERCLIP_*`-Variablen verwenden. Keine IDs und Tokens per Hand erfinden.
3. In dessen Arbeitsbereich `python -m mission_control doctor` und anschließend
   `send`, `request-review` und `reconcile` ausführen.
4. Eine Rückfrage, eine Ablehnung mit Nacharbeit, einen Neustart und einen
   fehlgeschlagenen Pflichtcheck protokollieren.
5. Erst nach drei nachweisbar geprüften Merges den Pilot als bestanden markieren.

## Redaktionsteams je Fachrichtung

Die KI-Redaktion ist als Firmenagenten-Baum angelegt (siehe
`ops/agents/content/`): ein Content-Koordinator (Jura) mit drei
Rechtsgebiets-Redakteuren und einem Prüfagenten, darunter je ein Team pro
weiterer Fachrichtung (`docs/34-fachrichtungen.md`):

| Fachrichtung | Koordinator | Redakteure | Prüfagent |
|---|---|---|---|
| Jura | `content-koordinator.md` | `content-<gebiet>-redakteur.md` | `content-pruefagent.md` (Normzitat-Gate) |
| Elektrotechnik | `elektrotechnik/koordinator.md` | `elektrotechnik/redakteur-et-*.md` | `elektrotechnik/pruefagent.md` (Fach-Gate) |
| Maschinenbau | `maschinenbau/koordinator.md` | `maschinenbau/redakteur-mb-*.md` | `maschinenbau/pruefagent.md` (Fach-Gate) |
| Lehramt | `lehramt/koordinator.md` | `lehramt/redakteur-la-*.md` | `lehramt/pruefagent.md` (Fach-Gate) |

Beim Anlegen im Board: zuerst den Fachrichtungs-Koordinator (reportsTo
Content-Koordinator), dann seine Redakteure und den Prüfagenten (reportsTo
Fachrichtungs-Koordinator). Jeder Redakteur bekommt genau ein `--area` aus
`content/fachrichtungen/<slug>.yaml` als Zuständigkeit.

`start-paperclip-pilot.ps1 -Reset` löscht ausschließlich den Pilotzustand nach
einer interaktiven Eingabe von `yes`.
