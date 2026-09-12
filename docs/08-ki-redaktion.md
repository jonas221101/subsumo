# KI-Redaktion

Löst den Engpass aus Challenge 10 ("Content ist der Engpass, nicht der
Code", siehe `docs/03-roadmap.md`) direkt an der Wurzel: Statt auf eine
menschliche Fachredaktion zu warten, erzeugen zwei unabhängige Agenten den
Rohentwurf und prüfen ihn gegenseitig. Menschliche Stichprobe bleibt
vorgesehen, ist aber keine Voraussetzung für die Veröffentlichung — sonst
wäre sie wieder derselbe Flaschenhals.

## Architektur: drei Instanzen müssen zustimmen

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
`pipeline.py`, `prompts.py`). CLI: `backend/scripts/redaktion_cli.py`.
Tests mit einem Fake-LLM-Client, ohne Netz: `backend/tests/test_redaktion.py`.

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
LLM-Aufruf zuverlässig auffängt. Sobald der Norm-Explorer aus `docs/03-roadmap.md`
(M2, Import von gesetze-im-internet.de) steht, wird eine dritte,
deterministische Prüfstufe ergänzt: jedes `norms:`-Zitat wird gegen den
echten Gesetzestext-Index abgeglichen, bevor ein Inhalt freigegeben wird. Bis
dahin ist **jeder KI-erzeugte Inhalt vor der ersten Nutzung stichprobenartig
von einer Person mit juristischer Vorbildung zu prüfen** — die Pipeline
markiert dafür jeden Inhalt eindeutig (siehe unten), verhindert die
Freigabe aber nicht technisch.

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
```

`status: in-pruefung` lässt die CI durchlaufen, erzeugt aber eine Warnung
(`app/services/content.py`) — gedacht für Inhalte, die vor der ersten
Nutzung noch eine menschliche Prüfung durchlaufen sollen, ohne den
automatisierten Fluss zu blockieren. Inhalte ohne `redaktion`-Block (der
gesamte M0-Bestand) gelten unverändert als regulär redigiert.

## Betrieb

```bash
cd backend
export SUBSUMO_LLM_PROVIDER=anthropic
export SUBSUMO_LLM_API_KEY=sk-ant-...

# Ein einzelnes Thema
python scripts/redaktion_cli.py run --area zivilrecht \
  --title "Stellvertretung" \
  --context "BGB AT, §§ 164 ff. BGB, Vollmacht und Vertretungsmacht"

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

## Grenzen, ehrlich benannt

- **Kein Ersatz für M2 (Norm-Explorer).** Ohne echten Normindex bleibt eine
  Lücke bei Halluzinationen in Paragraphenzitaten (siehe oben).
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
