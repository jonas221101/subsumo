# KI-Redaktion

Löst den Engpass aus Challenge 10 ("Content ist der Engpass, nicht der
Code", siehe `docs/03-roadmap.md`) direkt an der Wurzel: Statt auf eine
menschliche Fachredaktion zu warten, erzeugen zwei unabhängige Agenten den
Rohentwurf und prüfen ihn gegenseitig. Menschliche Stichprobe bleibt
vorgesehen, ist aber keine Voraussetzung für die Veröffentlichung — sonst
wäre sie wieder derselbe Flaschenhals. (Warum sie trotzdem empfohlen bleibt
und wie sie technisch nicht erzwungen wird: siehe unten, Abschnitt „Grenze
der Positivliste".)

## Architektur: vier Instanzen müssen zustimmen

```
TopicRequest (Rechtsgebiet, Arbeitstitel, Kontext)
        │
        ▼
┌───────────────────┐   Entwurf (YAML)   ┌──────────────────────┐
│  Collector-Agent   │ ─────────────────▶ │   Struktur-Gate       │
│  (LLM)              │                    │  (deterministisch,    │
│  schreibt Karten,   │                    │   app.services.       │
│  Schemata, Fälle    │                    │   content.load_content)│
└─────────▲──────────┘                    └──────────┬────────────┘
          │  Formatfehler als Feedback                │ strukturell gültig
          │  (zurueck an Collector)                    ▼
          │                                 ┌──────────────────────┐
          │                                 │   Normzitat-Gate       │
          │      Normzitat-Gate lehnt ab    │  (deterministisch,     │
          │◀────────────────────────────────│   app.services.        │
          │                                 │   redaktion.norm_gate) │
          │                                 └──────────┬────────────┘
          │                                             │ Zitate plausibel
          │                                             ▼
          │                                 ┌──────────────────────┐
          │        Reviewer lehnt ab        │   Reviewer-Agent      │
          └─────────────────────────────────│   (LLM, unabhängiger  │
                                             │    Aufruf)            │
                                             └──────────┬────────────┘
                                                         │ approved
                                                         ▼
                                          content/<gebiet>/<slug>.yaml
                                          + topic.redaktion-Herkunftsblock
```

Quellcode: `backend/app/services/redaktion/` (`collector.py`, `reviewer.py`,
`norm_gate.py`, `pipeline.py`, `prompts.py`). CLI:
`backend/scripts/redaktion_cli.py`. Tests mit einem Fake-LLM-Client, ohne
Netz: `backend/tests/test_redaktion.py`, `backend/tests/test_norm_gate.py`.

## Warum zwei Agenten und nicht einer

Ein Modell, das seinen eigenen Entwurf im selben Gespräch bewertet, neigt zur
Selbstbestätigung (Anchoring). Der Reviewer läuft deshalb als **komplett
neuer Aufruf ohne den Entstehungskontext** des Entwurfs — er sieht nur das
fertige YAML, nicht die Überlegungen, die dazu geführt haben. Das ist
derselbe Grund, aus dem Klausurkorrektoren in der Praxis nicht ihre eigene
Musterlösung gegenkorrigieren.

## Warum die Formatprüfung nicht dem LLM überlassen wird

Das Struktur-Gate ruft **dieselbe Funktion auf, die auch die CI für
menschlich geschriebene Inhalte nutzt** (`load_content`). Ein Sprachmodell
darum zu bitten, ein YAML-Schema strikt einzuhalten, ist ein Bitten, kein
Erzwingen — ein deterministischer Parser ist beides. Der Reviewer bekommt
einen Entwurf nie zu sehen, der das Struktur-Gate nicht besteht: das spart
Kosten und hält die Trennung sauber — der Reviewer urteilt über Inhalte,
nicht über YAML-Syntax.

## Was der Reviewer konkret prüft (und was nicht)

Der Reviewer-Prompt (`prompts.py::reviewer_prompt`) verlangt eine begründete
Stellungnahme zu fünf Punkten:

1. **Urheberrecht** — liest sich ein Text wie eine wörtliche oder nur leicht
   umformulierte Übernahme aus einem bekannten Lehrbuch/Kommentar?
2. **RDG** — ist jeder Fall zweifelsfrei fiktiv (keine realen Namen, Firmen,
   Aktenzeichen, keine Bezugnahme auf ein tatsächliches Verfahren)?
3. **Fachliche Plausibilität** — wirkt eine Norm, Definition oder ein
   Prüfungsschritt falsch, veraltet oder erfunden?
4. **Erwartungshorizont** — hat jeder Fall mindestens einen zwingenden
   Prüfpunkt, und sind die Prüfpunkte klausurrelevant statt trivial?
5. **Slug-Kollisionen** mit bereits vorhandenem Content.

**Was der Reviewer nicht leistet:** eine verlässliche Prüfung, ob ein
zitierter Paragraph tatsächlich existiert und den behaupteten Inhalt hat.
Ein Sprachmodell kann einen plausibel klingenden, aber falschen oder
erfundenen Paragraphen genauso überzeugend vortragen wie einen echten — das
ist eine bekannte Schwäche von LLMs bei Zitaten, nicht etwas, das ein zweiter
LLM-Aufruf zuverlässig auffängt. Deshalb übernimmt das **Normzitat-Gate**
(`app.services.redaktion.norm_gate`, deterministisch, kein LLM-Aufruf) einen
Zwischenschritt: jedes `norms:`-Zitat wird gegen eine kuratierte Positivliste
bekannter Gesetzeskürzel und plausibler Paragraphen-/Artikelbereiche geprüft
(mindestens BGB, StGB, GG, VwGO, VwVfG, StPO, BVerfGG) — nach demselben
Prinzip wie das Struktur-Gate (siehe oben): ein deterministischer Check ist
ein Erzwingen, ein Bitten an das Modell wäre es nicht. Verstößt ein Zitat
(unbekanntes Kürzel, Nummer außerhalb des Bereichs, falsches Zitierformat),
geht der Entwurf mit konkretem Feedback zurück an den Collector, bevor der
Reviewer ihn je sieht.

**Grenze der Positivliste:** Sie ersetzt keinen vollständigen Normindex. Ein
erfundener § 999999 BGB oder ein nicht existentes Gesetzeskürzel wird
abgefangen; ein *falsch zugeordneter, aber plausibel liegender* Paragraph
(z. B. eine Norm mit falschem Inhalt, aber gültiger Nummer) nicht — dafür
bräuchte es den echten Gesetzestext. Sobald der Norm-Explorer aus
`docs/03-roadmap.md` (M2, Import von gesetze-im-internet.de) steht, löst ein
Abgleich gegen den echten Gesetzestext-Index diese Positivliste ab.

Bis dahin bleibt die menschliche Stichprobe (siehe Einleitung) die einzige
Instanz, die eine solche inhaltliche Fehlzuordnung überhaupt finden kann —
deshalb ist sie **empfohlen, vor der ersten Nutzung jeden KI-erzeugten
Inhalt stichprobenartig von einer Person mit juristischer Vorbildung zu
prüfen**. Das ist wie in der Einleitung festgehalten aber **kein
technisches Gate**: Die Pipeline markiert geprüften wie ungeprüften Inhalt
eindeutig (`redaktion.status`, siehe unten), verhindert die Freigabe
ungeprüften Inhalts aber nicht technisch. Ob eine konkrete Content-Charge
die Stichprobe durchlaufen hat, ist damit pro Release offen zu
dokumentieren, keine automatische Voraussetzung — für v1.0 wurde sie
bewusst ausgesetzt (`SUB-225`, Interaktion `f754f609`); das Restrisiko
dieser Aussetzung ist in `docs/17-release-readiness.md` Abschnitt 7.1
dokumentiert.

## Herkunftsangabe

Jeder von der Pipeline erzeugte Inhalt trägt einen `topic.redaktion`-Block:

```yaml
topic:
  slug: zr-stellvertretung
  ...
  redaktion:
    erzeugt_von: collector-agent-v1
    geprueft_von: reviewer-agent-v1
    geprueft_am: "2026-09-12"
    status: ki-freigegeben   # ki-freigegeben | mensch-freigegeben | in-pruefung
    normzitate_geprueft: true   # Normzitat-Gate bestanden, siehe unten
```

`status: in-pruefung` lässt die CI durchlaufen, erzeugt aber eine Warnung
(`app/services/content.py`) — gedacht für Inhalte, die vor der ersten
Nutzung noch eine menschliche Prüfung durchlaufen sollen, ohne den
automatisierten Fluss zu blockieren. Inhalte ohne `redaktion`-Block (der
gesamte M0-Bestand) gelten unverändert als regulär redigiert.

## Redaktionsrollen und "Lernbereiche"

Die Redaktionsarbeit rund um diese Pipeline ist auf drei Rollen aufgeteilt,
dokumentiert unter `ops/agents/content/` (analog zu `ops/agents/coordinator.md`
& Co.): ein **Content-Koordinator** organisiert die Arbeit je Rechtsgebiet und
pflegt den `BACKLOG`-Fortschritt in `redaktion_cli.py`, drei
**Gebiets-Redakteure** (Zivilrecht, Strafrecht, Öffentliches Recht) sind je
für ihr `--area`-Segment verantwortlich, und der **Content-Prüfagent**
(`ops/agents/content/content-pruefagent.md`) ist die in diesem Dokument
beschriebene Rolle rund um das Normzitat-Gate — unabhängig von Collector und
Reviewer.

Klarstellung zu "Lernbereichen" (Begriff aus dem ursprünglichen Auftrag,
SUB-51): Das sind **keine neue Datenmodell-Ebene**, sondern die fachliche
Untergliederung, die im `BACKLOG` (`redaktion_cli.py`) und in `content/`
bereits über Titel und Kontext-Stichworte abgebildet ist — z. B. AT/BT bei
Zivil- und Strafrecht, "VerwR AT" beim Öffentlichen Recht (siehe die
bestehenden Dateien `content/strafrecht/strafrecht-at.yaml`,
`content/zivilrecht/bgb-at-kaufrecht.yaml`). Kartentypen
(`definition`/`schema_step`/`streitstand`/`norm`/`rechtsprechung`, siehe
`docs/05-content-pipeline.md`) sind eine orthogonale, bereits bestehende
Klassifikation und nicht gemeint. Es gibt keinen Schema-Änderungsbedarf an
`content/`-YAML dafür — nur an der redaktionellen Planung (BACKLOG-Struktur,
ggf. ein Kommentar, welcher Lernbereich ein Thema abdeckt).

## Betrieb

```bash
cd backend
export SUBSUMO_LLM_PROVIDER=anthropic
export SUBSUMO_LLM_API_KEY=sk-ant-...

# Ein einzelnes Thema
python scripts/redaktion_cli.py run --area zivilrecht \
  --title "Leistungsstoerungen: Unmoeglichkeit" \
  --context "Schuldrecht AT, § 275 BGB, § 283 BGB"

# Den kuratierten Rückstand abarbeiten (BACKLOG in redaktion_cli.py)
python scripts/redaktion_cli.py backlog --area strafrecht --limit 3

# Nur Alterskontrolle, kein LLM noetig
python scripts/redaktion_cli.py audit-staleness
```

**Was der Collector bekommt, ist bewusst nicht "erfinde irgendein Thema".**
Die Liste der zu bearbeitenden Themen (`BACKLOG` in `redaktion_cli.py`)
wird von Hand gepflegt — *welcher* Stoff examensrelevant und als Nächstes
dran ist, bleibt eine redaktionelle/fachliche Entscheidung. Die Agenten
entscheiden nicht über den Lehrplan, nur über die Ausarbeitung.

## Lokaler Brücken-Modus (kein API-Key nötig)

`--engine bridge` ersetzt den Anthropic-Aufruf durch einen Dateiaustausch:
Der Agent, mit dem gerade im Gespräch gearbeitet wird, beantwortet Collector-
und Reviewer-Prompts direkt — kein Netz, kein Key. Code:
`backend/app/services/redaktion/bridge_client.py`.

```bash
python scripts/redaktion_cli.py run --engine bridge \
  --area zivilrecht --title "Stellvertretung" \
  --context "BGB AT, §§ 164 ff. BGB, Vollmacht und Vertretungsmacht" \
  --bridge-dir /tmp/redaktion-bridge
```

Der Prozess pausiert nach jedem Prompt und wartet auf eine Antwortdatei:

1. `request_001.txt` erscheint im Bridge-Verzeichnis (der Collector-Prompt)
2. Der Prompt wird beantwortet — ein vollständiges YAML-Dokument nach dem
   Schema aus `docs/05-content-pipeline.md`, exakt nach den Vorgaben im
   Prompt (Urheberrecht, RDG, Normzitate) — als `response_001.txt` +
   `response_001.ready` abgelegt
3. Besteht der Entwurf das Struktur-Gate, erscheint `request_002.txt` (der
   Reviewer-Prompt mit dem Entwurf) — unabhängig und kritisch beantwortet,
   als JSON (`{"approved": ..., "issues": [...], "severity": ...}`)
4. Bei Ablehnung (Struktur- oder Reviewer-Gate) beginnt eine neue Runde mit
   konkretem Feedback im nächsten Collector-Prompt

**So entstanden**, real erprobt und nicht nur simuliert: Das Thema
`zr-at-stellvertretung` (7 Karten, 1 Schema, 1 Fall) im ersten Durchlauf
dieses Modus — beide Gates im ersten Anlauf bestanden, ohne
API-Key. Dabei wurde beim ersten echten End-to-End-Test der Bewertung gegen
diesen Fall ein realer Bug in `evaluator.py` gefunden und behoben: Stichworte
in ASCII-Umlaut-Schreibweise (`ausdruecklich`) trafen keinen Text mit echtem
Umlaut (`ausdrücklich`) und umgekehrt — siehe `_digraph_fold()` und die
Regressionstests in `tests/test_evaluator.py`. Genau der Wert eines echten
End-to-End-Laufs gegenüber reinen Unit-Tests mit Fake-Antworten.

**Grenzen des Brücken-Modus:** Er ersetzt keinen echten API-Aufruf für den
Produktivbetrieb (`--engine anthropic` bleibt der Weg für `backlog`-Läufe im
großen Maßstab) und ist an eine laufende Unterhaltung gebunden — für
automatisierte, unbeaufsichtigte Läufe (z. B. ein CI-Workflow) ungeeignet.

## Grenzen, ehrlich benannt

- **Normzitat-Gate ist eine kuratierte Positivliste, kein Normindex (M2).**
  Fängt erfundene Gesetzeskürzel und unplausible Paragraphennummern ab
  (siehe oben, `app.services.redaktion.norm_gate`), prüft aber nicht, ob ein
  Zitat inhaltlich zum behaupteten Sachverhalt passt. Ohne den echten
  Normindex aus M2 bleibt hier eine Lücke.
- **Das Gate läuft nur beim Erzeugen, nicht rückwirkend.** Themen, die vor
  der Einführung des Gates (SUB-53, 14.09.) entstanden sind, haben es nie
  durchlaufen. Der Bestand vom 12.-14.09. (8 Themen) wurde per Nachlauf
  gegen `check_norms()` geprüft und mit `normzitate_geprueft: true`
  nachgetragen (SUB-250); der M0-Grundbestand bleibt ohne `redaktion`-Block
  und gilt laut Definition oben unverändert als regulär redigiert.
- **Kalibrierung fehlt noch.** Anders als beim Klausur-Evaluator
  (`docs/03-roadmap.md`, M3: 30 von Dozenten bewertete Referenzgutachten,
  Ziel-MAE ≤ 2 Punkte) gibt es für die Redaktions-Reviewer-Entscheidung noch
  keinen kalibrierten Referenzsatz. Vorgesehen für M2, sobald genug
  KI-erzeugter Content vorliegt, um eine Stichprobe sinnvoll gegen
  menschliches Urteil zu prüfen.
- **Kosten pro Thema.** Ein Collector-Aufruf mit bis zu drei Korrekturrunden
  plus je ein Reviewer-Aufruf pro Runde — bei `MAX_ROUNDS = 3`
  (`pipeline.py`) im ungünstigsten Fall sechs LLM-Aufrufe für ein einziges
  Thema. Das ist bei aktuellen API-Preisen unkritisch, aber kein Grund, die
  `BACKLOG`-Liste unkuratiert wachsen zu lassen.
- **Kein automatischer Merge.** Die Pipeline schreibt eine Datei ins lokale
  `content/`-Verzeichnis; ob sie committed und gepusht wird, entscheidet
  weiterhin ein Mensch (oder ein CI-Workflow mit PR-Erstellung, siehe
  `.github/workflows/content-redaktion.yml` — inaktiv, bis das Projekt in
  ein eigenes Repository ausgegliedert ist, siehe Haupt-README).
