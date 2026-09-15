# Content-Prüfagent

Beschreibt zwei zusammengehörige, aber getrennte Prüfinstanzen in der
KI-Redaktion (`docs/08-ki-redaktion.md`), beide unabhängig von Collector und
Reviewer:

1. Das automatisierte, deterministische Normzitat-Gate im Code
   (`backend/app/services/redaktion/norm_gate.py`, eingebunden in
   `backend/app/services/redaktion/pipeline.py` zwischen Struktur-Gate und
   Reviewer) - kein LLM-Aufruf, läuft bei jedem Pipeline-Durchlauf
   automatisch, unabhängig davon ob ein Firmenagent existiert.
2. Der echte Paperclip-Firmenagent `Content-Pruefagent` (reportsTo
   Content-Koordinator), der als zusätzliche, unabhängige Instanz fertige
   Entwürfe (nach bestandenem Struktur- und Normzitat-Gate) inhaltlich auf
   Normzitat-Passung und Quellenpflicht prüft - siehe "Warum zwei
   zusätzliche Instanzen" unten.

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

## Warum zwei zusätzliche Instanzen

Der Reviewer (`docs/08-ki-redaktion.md`, "Was der Reviewer nicht leistet")
kann einen erfundenen, aber plausibel klingenden Paragraphen nicht
zuverlässig von einem echten unterscheiden - dieselbe Schwäche, die ihn
selbst als LLM-Aufruf trifft. Das automatisierte Gate ist hier robuster für
die Syntax-Ebene: es erfindet nichts und variiert nicht zwischen Läufen.
Für die semantische Ebene - passt ein syntaktisch korrektes Zitat auch
inhaltlich zum behaupteten Sachverhalt - reicht Determinismus allein nicht;
dafür existiert der Firmenagent `Content-Pruefagent` als eigenständige
vierte Perspektive neben Collector, Reviewer und Code-Gate.

## Grenze, explizit benannt

Die Positivliste im Code **ersetzt keinen vollständigen Normindex** (M2,
`docs/03-roadmap.md`, Import von gesetze-im-internet.de). Sie fängt
offensichtlich erfundene oder falsch zugeordnete Paragraphen/Gesetze ab
(unbekanntes Kürzel, Nummer außerhalb des bekannten Bereichs, falsches
Zitierformat), prüft aber nicht, ob ein syntaktisch korrektes Zitat
inhaltlich zum behaupteten Sachverhalt passt. Bis M2 übernimmt diese
inhaltliche Stichprobe der Firmenagent `Content-Pruefagent` (reportsTo
Content-Koordinator) - siehe "Grenzen, ehrlich benannt" in
`docs/08-ki-redaktion.md`.

## Pro Lauf

Zwei getrennte Arbeitsweisen, je nachdem wer an dieser Prüfinstanz
arbeitet:

**Firmenagent `Content-Pruefagent` (fachliche Prüfung je Content-Batch):**
prüft nach bestandenem Struktur- und automatisiertem Normzitat-Gate jeden
Entwurf inhaltlich auf Normzitat-Passung und Quellenpflicht und postet ein
Pass/Fail je Datei. Details, Domain-Lenses und Zusammenarbeit siehe die
Agent-Instruktionen des Firmenagenten (`AGENTS.md`, verwaltet über
Paperclip, nicht in diesem Repo-Dokument).

**Entwickler-Aufgabe (Pflege der Positivliste im Code):** das
automatisierte Gate läuft ohnehin bei jedem `RedaktionPipeline.run()`
automatisch. Wer an der Positivliste arbeitet (neues Gesetz ergänzen,
Paragraphenbereich korrigieren), tut das als Entwickler-Aufgabe:

1. `GESETZE`-Dict in `backend/app/services/redaktion/norm_gate.py` erweitern
   oder korrigieren.
2. Unit-Test in `backend/tests/test_norm_gate.py` ergänzen (Erfolgs- und
   Ablehnungsfall).
3. `cd backend && python -m pytest tests/test_norm_gate.py
   tests/test_redaktion.py` und `python scripts/validate_content.py`
   (Regressionscheck gegen bestehenden Content) ausführen.

## Rechte-Grenzen

Das automatisierte Code-Gate trifft keine Freigabe- oder Merge-Entscheidung
- es lehnt nur strukturell/syntaktisch ab oder lässt durch. Der Firmenagent
`Content-Pruefagent` urteilt fachlich (Pass/Fail mit Begründung je Datei),
trifft aber ebenfalls keine Merge-Entscheidung - das bleibt beim Reviewer
und beim PR-Workflow. Erweiterungen der Positivliste im Code laufen über
denselben PR-Workflow wie jede andere Code-Änderung (`CONTRIBUTING.md`),
nicht über eine eigenmächtige Anpassung zur Laufzeit durch den Firmenagenten.
Kein Merge, kein direkter Push auf `main`, kein Anlegen neuer Firmenagenten
(keine `canCreateAgents`-Berechtigung) durch den Content-Pruefagent selbst.
