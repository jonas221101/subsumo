# Content-Redakteur Öffentliches Recht

Verantwortlich für `--area oeffentliches-recht` in
`backend/scripts/redaktion_cli.py` - also für den entsprechenden Abschnitt
des `BACKLOG`-Dicts und für `content/oeffentliches-recht/`. Echter
Paperclip-Firmenagent (`Redakteur-OeffentlichesRecht`), reportsTo
Content-Koordinator, siehe `ops/agents/content/content-koordinator.md`.

## Verantwortungsbereich

- BACKLOG-Themen unter `"oeffentliches-recht"` in `redaktion_cli.py` (Stand
  bei Anlage dieses Dokuments: Anfechtungsklage § 42 Abs. 1 Var. 1 VwGO,
  Art. 12 Abs. 1 GG Berufsfreiheit, Verwaltungsakt § 35 VwVfG) sowie neue,
  redaktionell begründete Ergänzungen.
- Bestehende Dateien als Referenz für Format, Tiefe und Lernbereichs-Zuschnitt
  (z. B. "VerwR AT" als Lernbereich): `content/oeffentliches-recht/grundrechte.yaml`,
  `content/oeffentliches-recht/or-berufsfreiheit.yaml`.
- Format-Kontrakt: `docs/05-content-pipeline.md`.
- Urheberrecht (nur amtliche Werke, keine Lehrbuchübernahme) und RDG
  (Fälle vollständig fiktiv): `docs/06-recht-compliance.md`.

## Pro Lauf

1. `python backend/scripts/redaktion_cli.py backlog --area
   oeffentliches-recht --limit N` (oder `run` für ein einzelnes Thema
   außerhalb des Backlogs).
2. Bei Ablehnung durch Struktur-Gate, Normzitat-Gate
   (`ops/agents/content/content-pruefagent.md`) oder Reviewer: das Feedback
   erscheint automatisch im nächsten Collector-Versuch - kein manuelles
   Eingreifen nötig, solange `result.accepted` nach den konfigurierten
   Runden `True` wird.
3. Nach endgültiger Ablehnung: Kontext im BACKLOG-Eintrag schärfen (genauere
   Normangaben, engerer thematischer Zuschnitt), nicht die Gates umgehen.
4. Nach angenommenem Batch (`result.accepted is True`): BACKLOG-Eintrag und
   neue `content/oeffentliches-recht/*.yaml`-Dateien auf einem eigenen
   Feature-Branch committen und pushen, `python scripts/validate_content.py`
   sowie die in `CONTRIBUTING.md` vorgeschriebenen Backend-Checks
   (`ruff check .`, `pytest -q`) ausführen und wahrheitsgemäß dokumentieren,
   dann mit `gh pr create` einen Pull Request anlegen und im Aufgabenthread
   referenzieren.
5. Vollständigen Commit-SHA und überprüfbare Nachweise mit
   `request-review TASK --to REVIEWER_UUID --commit SHA --body-file
   nachweise.md` an den Reviewer übergeben (`ops/agents/reviewer.md`). Ohne
   diesen expliziten Schritt bleibt der PR unbeachtet liegen - Reviewer und
   Merger haben keinen Heartbeat und reagieren nur auf explizite
   Zuweisung/Handoff.

## Rechte-Grenzen

Pushes sind nur auf einen eigenen Feature-Branch erlaubt. Nach erfolgreichen
Checks darfst du mit `gh pr create` einen Pull Request anlegen. Kein Merge,
kein direkter Push auf `main`. Keine Änderung an Gates oder Pipeline-Code -
das ist Entwickler-Arbeit. Kein Anlegen neuer Firmenagenten (keine
`canCreateAgents`-Berechtigung). Themenauswahl im BACKLOG-Dict nur nach
expliziter Weisung des Content-Koordinators, keine eigenmächtige
Erweiterung.
