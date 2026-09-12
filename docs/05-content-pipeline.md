# Content-Pipeline

Inhalte sind **versionierter Code**, keine Datenbankeintraege. Die Datenbank
ist ein Cache von `content/`.

## Format

Eine YAML-Datei je Thema, unter `content/<rechtsgebiet>/<thema>.yaml`:

```yaml
topic:
  slug: zr-bgb-at          # eindeutig ueber das ganze Repo
  area: zivilrecht         # zivilrecht | strafrecht | oeffentliches-recht
  title: BGB Allgemeiner Teil
  relevance: 5             # 1-5, kuratierte Pruefungsrelevanz
  stand: "2026-09"

cards:
  - slug: zr-at-angebot
    type: definition       # definition | schema_step | streitstand | norm | rechtsprechung
    front: "Definiere: Angebot"
    back: "Ein Angebot ist ..."
    norms: ["§ 145 BGB"]
    quellen: ["BGB, amtliche Fassung"]   # Pflicht
    stand: "2026-09"                      # erbt vom Thema, wenn weggelassen

schemata:
  - slug: zr-schema-433-ii
    title: "Anspruch auf Kaufpreiszahlung, § 433 Abs. 2 BGB"
    quellen: [...]
    steps:
      - label: "I. Anspruch entstanden"
        children:
          - label: "1. Wirksamer Kaufvertrag"
        hinweis: "Nur pruefen, wenn der Sachverhalt Anlass gibt."

faelle:
  - slug: zr-fall-sonderpreis
    title: "Der Sonderpreis"
    difficulty: 2          # 1 leicht - 5 Examen
    minutes: 45
    facts: "..."
    question: "..."
    quellen: [...]
    steps:                 # gefuehrter Modus, Schritt fuer Schritt
      - prompt: "Formuliere den Obersatz."
        erwartung: "..."
    expectation:           # Erwartungshorizont - Grundlage jeder Bewertung
      pruefpunkte:
        - id: p1
          label: "Richtige Anspruchsgrundlage genannt"
          weight: 2.0
          required: true   # fehlt er, ist die Arbeit gedeckelt
          norms: ["§ 433 Abs. 1 S. 1 BGB"]
          keywords: ["433"]
```

## Regeln, die die CI erzwingt

`python backend/scripts/validate_content.py` bricht ab bei:

- fehlenden Pflichtfeldern (`slug`, `front`/`back`, `quellen`, `stand`)
- unbekanntem Rechtsgebiet oder Kartentyp
- doppelten Slugs ueber das gesamte Repository
- `relevance` ausserhalb 1–5
- `stand` in einem anderen Format als `YYYY-MM` oder `YYYY-MM-TT`
- einem Fall **ohne** Erwartungshorizont oder mit nicht eindeutigen Pruefpunkt-IDs

Warnung (kein Abbruch): Inhalte, deren `stand` aelter als 18 Monate ist. Mit
`--strict` werden auch sie zum Fehler — gedacht fuer einen monatlichen
Redaktionslauf.

## Redaktionsworkflow

1. Autor legt einen Branch an und schreibt/aendert YAML
2. CI validiert Format und Quellenangaben
3. Fachliche Review durch eine zweite Person im Pull Request
4. Merge → Release → Clients ziehen das Delta ueber `GET /v1/content/manifest`

## Was beim Aendern eines Inhalts mit dem Lernfortschritt passiert

Nichts wird zurueckgesetzt. Der `content_hash` der Karte aendert sich, die
betroffenen Nutzerkarten werden als `content_changed` markiert und einmalig mit
Hinweis erneut vorgelegt. Siehe `docs/04-datenmodell.md`.

## Urheberrecht

Nur amtliche Werke (§ 5 UrhG: Gesetze, Entscheidungen mit amtlichen Leitsaetzen)
und Eigenproduktion. Keine Uebernahme aus Lehrbuechern oder Kommentaren.
Details in `docs/06-recht-compliance.md`.
