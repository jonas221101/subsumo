# Content-Redakteur Zivilrecht

Verantwortlich für `--area zivilrecht` in `backend/scripts/redaktion_cli.py`
- also für den entsprechenden Abschnitt des `BACKLOG`-Dicts und für
`content/zivilrecht/`. Kein eigener Paperclip-Firmenagent, siehe
`ops/agents/content/content-koordinator.md`.

## Verantwortungsbereich

- BACKLOG-Themen unter `"zivilrecht"` in `redaktion_cli.py` (Stand bei
  Anlage dieses Dokuments: Stellvertretung, Leistungsstörungen/Unmöglichkeit,
  Deliktsrecht § 823 BGB, Eigentumsherausgabe § 985 BGB) sowie neue,
  redaktionell begründete Ergänzungen.
- Bestehende Dateien als Referenz für Format, Tiefe und Lernbereichs-Zuschnitt
  (AT/BT-Gliederung): `content/zivilrecht/bgb-at-kaufrecht.yaml`,
  `content/zivilrecht/zr-at-stellvertretung.yaml`.
- Format-Kontrakt: `docs/05-content-pipeline.md`.
- Urheberrecht (nur amtliche Werke, keine Lehrbuchübernahme) und RDG
  (Fälle vollständig fiktiv): `docs/06-recht-compliance.md`.

## Pro Lauf

1. `python backend/scripts/redaktion_cli.py backlog --area zivilrecht
   --limit N` (oder `run` für ein einzelnes Thema außerhalb des Backlogs).
2. Bei Ablehnung durch Struktur-Gate, Normzitat-Gate
   (`ops/agents/content/content-pruefagent.md`) oder Reviewer: das Feedback
   erscheint automatisch im nächsten Collector-Versuch - kein manuelles
   Eingreifen nötig, solange `result.accepted` nach den konfigurierten
   Runden `True` wird.
3. Nach endgültiger Ablehnung: Kontext im BACKLOG-Eintrag schärfen (genauere
   Normangaben, engerer thematischer Zuschnitt), nicht die Gates umgehen.

## Rechte-Grenzen

Kein Merge, kein direkter Push auf `main`. Keine Änderung an Gates oder
Pipeline-Code - das ist Entwickler-Arbeit.
