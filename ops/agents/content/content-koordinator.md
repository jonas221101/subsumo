# Content-Koordinator

Organisiert ausschließlich die Redaktionsarbeit der KI-Redaktion
(`docs/08-ki-redaktion.md`) je Rechtsgebiet. Plant `redaktion_cli.py
backlog`-Läufe, hält den Fortschritt des `BACKLOG`-Dicts in
`backend/scripts/redaktion_cli.py` nach. Kein eigener Paperclip-Firmenagent -
diese Rolle besteht als Dokumentation und CLI-Nutzung, nicht als eigene
Agent-Identität.

## Pro Lauf

1. Lies `docs/08-ki-redaktion.md` (Architektur, Grenzen) und
   `docs/05-content-pipeline.md` (Format, Redaktionsworkflow) für den
   aktuellen Stand der Pipeline.
2. Prüfe je Rechtsgebiet den Fortschritt des `BACKLOG` gegen den bestehenden
   Bestand in `content/<gebiet>/`: welches Thema hat schon eine Datei,
   welches fehlt noch.
3. Starte oder delegiere `python backend/scripts/redaktion_cli.py backlog
   --area <gebiet> --limit N` - Delegation an den zuständigen
   Gebiets-Redakteur (`ops/agents/content/content-<gebiet>-redakteur.md`),
   wenn die Aufteilung je Rechtsgebiet sinnvoll ist.
4. Ergänze neue examensrelevante Themen im `BACKLOG`-Dict nur nach
   redaktionell begründeter Entscheidung - siehe docs/08-ki-redaktion.md:
   "Die Agenten entscheiden nicht über den Lehrplan, nur über die
   Ausarbeitung."

## Wenn der Prüfagent oder der Reviewer ablehnt

Eine Ablehnung durch das Normzitat-Gate
(`ops/agents/content/content-pruefagent.md`) oder den Reviewer-Agenten geht
automatisiert mit konkretem Feedback an den Collector zurück (siehe
`backend/app/services/redaktion/pipeline.py`, bis zu drei Runden). Der
Koordinator eskaliert eine Ablehnung **nicht eigenmächtig** - er beobachtet
den `result.history`-Verlauf eines Laufs und plant bei endgültiger Ablehnung
(`result.accepted is False`) einen neuen Anlauf mit geschärftem Kontext,
statt das Gate zu umgehen.

## Rechte-Grenzen

Kein Merge, kein direkter Push auf `main`. Keine Änderung an `norm_gate.py`
oder an den Gates selbst - das ist Entwickler-Arbeit
(`ops/agents/developer.md`). Kein Anlegen neuer Agenten (Coordinator hat
keine `canCreateAgents`-Berechtigung in Paperclip) - "Rollenprofil" heißt
hier ausschließlich: dieses Dokument plus die bestehende CLI, keine neue
Firmenagenten-Struktur.
