# Content-Prüfagent

Beschreibt eine deterministische Zusatzprüfung in der KI-Redaktion
(`docs/08-ki-redaktion.md`), unabhängig von Collector und Reviewer - kein
weiterer LLM-Aufruf, kein eigener Paperclip-Firmenagent. Code:
`backend/app/services/redaktion/norm_gate.py`, eingebunden in
`backend/app/services/redaktion/pipeline.py` zwischen Struktur-Gate und
Reviewer.

## Was geprüft wird

1. **Normzitate** (`norms:`-Felder in Karten, Schemata und Prüfpunkten):
   gegen eine kuratierte Positivliste bekannter Gesetzeskürzel und
   plausibler Paragraphen-/Artikelbereiche (`GESETZE` in `norm_gate.py`:
   mindestens BGB, StGB, GG, VwGO, VwVfG, StPO, BVerfGG). Geprüft werden
   bekanntes Kürzel, plausible Nummer, korrektes Zitierformat (§ vs. Art.,
   Abs./S./Nr./Var.-Struktur).
2. **Quellenpflicht** (`docs/06-recht-compliance.md`: nur amtliche Werke,
   Pflichtfeld `quellen`): das Pflichtfeld selbst wird bereits vom
   Struktur-Gate (`app.services.content.load_content`) erzwungen, bevor ein
   Entwurf hier ankommt - der Prüfagent dupliziert das nicht, sondern
   dokumentiert diese Verantwortung als Teil seines Prüfradius, weil sie
   inhaltlich zusammengehört (beides sind belegbarkeits-/nachweisbezogene
   Checks, kein fachliches Urteil wie beim Reviewer).

## Warum eine eigene, dritte Instanz

Der Reviewer (`docs/08-ki-redaktion.md`, "Was der Reviewer nicht leistet")
kann einen erfundenen, aber plausibel klingenden Paragraphen nicht
zuverlässig von einem echten unterscheiden - dieselbe Schwäche, die ihn
selbst als LLM-Aufruf trifft. Eine deterministische Prüfung ist hier
robuster: sie erfindet nichts und variiert nicht zwischen Läufen.

## Grenze, explizit benannt

Die Positivliste **ersetzt keinen vollständigen Normindex** (M2,
`docs/03-roadmap.md`, Import von gesetze-im-internet.de). Sie fängt
offensichtlich erfundene oder falsch zugeordnete Paragraphen/Gesetze ab
(unbekanntes Kürzel, Nummer außerhalb des bekannten Bereichs, falsches
Zitierformat), prüft aber nicht, ob ein syntaktisch korrektes Zitat
inhaltlich zum behaupteten Sachverhalt passt. Bis M2 bleibt die
menschliche Stichprobe vor der ersten Nutzung eines KI-Inhalts empfohlen
(siehe "Grenzen, ehrlich benannt" in `docs/08-ki-redaktion.md`).

## Pro Lauf

Diese Prüfung läuft automatisiert als Teil von `RedaktionPipeline.run()` -
es gibt keinen manuellen "Lauf" dieser Rolle. Wer an der Positivliste
arbeitet (neues Gesetz ergänzen, Paragraphenbereich korrigieren), tut das
als Entwickler-Aufgabe:

1. `GESETZE`-Dict in `backend/app/services/redaktion/norm_gate.py` erweitern
   oder korrigieren.
2. Unit-Test in `backend/tests/test_norm_gate.py` ergänzen (Erfolgs- und
   Ablehnungsfall).
3. `cd backend && python -m pytest tests/test_norm_gate.py
   tests/test_redaktion.py` und `python scripts/validate_content.py`
   (Regressionscheck gegen bestehenden Content) ausführen.

## Rechte-Grenzen

Keine Freigabe- oder Merge-Entscheidung - das Gate lehnt nur strukturell ab
oder lässt durch, es urteilt nicht inhaltlich (das bleibt Aufgabe des
Reviewers). Erweiterungen der Positivliste laufen über denselben PR-Workflow
wie jede andere Code-Änderung (`CONTRIBUTING.md`), nicht über eine
eigenmächtige Anpassung zur Laufzeit.
