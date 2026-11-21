# Lernmodul "Neues Thema erlernen": Skripte, interaktive Lernerlebnisse, Visualisierungen

> **Auftrag** ([SUB-810](/SUB/issues/SUB-810), wörtlich): „Bitte baue auch
> Lerninhalte zum Erlernen von neuen Themen. Baue dafür Skripte, interaktive
> Lernerlebnisse und Visualisierungen." Dieses Dokument ist die Zerlegung
> ([SUB-811](/SUB/issues/SUB-811)): Abnahmekriterien, Content-Format,
> App-Darstellung, Pilotumfang und Tickets.
>
> **Einordnung:** `docs/13-lernarchitektur.md` und der bestehende Content
> (`content/zivilrecht|strafrecht|oeffentliches-recht|landesrecht|examen`)
> decken die Kompetenzhierarchie Karte → Schema → Fall → Gutachten ab —
> **Wiederholen und Anwenden** von Stoff, der bereits einmal erklärt wurde.
> Es fehlt der Schritt davor: ein Thema **zum ersten Mal verstehen**. Dieses
> Dokument spezifiziert genau diesen fehlenden Einstieg, nicht einen Ersatz
> für die bestehende Lernarchitektur.
>
> **Randbedingungen aus dem Auftrag:** KI-Korrektur/LLM bleibt aus
> (`llm_provider=none`, `docs/23-llm-provider-avv.md`) — alle Inhalte sind
> redaktionell verfasst, keine Laufzeit-LLM-Generierung. Keine produktiven
> Serveraktionen in diesem Ticket. Scope bewusst klein: Pilot mit 3 Themen,
> Ausbau auf weitere Themen als Folgeticket.

---

## 1. Abnahmekriterien (SUB-810, prüfbar)

| # | Kriterium | Prüfung |
|---|---|---|
| AK1 | Das YAML-Contentformat ist um `lernskript`, `lernerlebnisse` und `visualisierungen` erweitert (Abschnitt 2) und `content.py`/`validate_content.py` validieren alle drei neuen Blöcke (Pflichtfelder, bekannte Typen, Cross-Referenzen auf `card_slugs`/`schema_slug`) | `backend/scripts/validate_content.py` läuft grün über `content/`; ein gezielt kaputtes Testfixture (fehlendes Pflichtfeld, unbekannter Typ, hängende Referenz) erzeugt einen Fehler, kein stiller Fallback |
| AK2 | Jedes der 3 Pilot-Themen (Abschnitt 4) hat genau ein Lernskript (≥ 3 Abschnitte, jeder Abschnitt referenziert ≥ 1 bestehenden `card_slug`), genau einen geführten Fall mit Verzweigung (≥ 3 Entscheidungspunkte), genau eine Sortieraufgabe (reuse des bestehenden Schemas) sowie je ein Flussdiagramm und einen Anspruchsaufbau-Baum des bestehenden Schemas; das Thema `or-vwgo-anfechtungsklage` zusätzlich einen Zeitstrahl | Diff der 3 Pilot-YAML-Dateien gegen das Schema aus Abschnitt 2; manuelle Zählung der Abschnitte/Entscheidungspunkte |
| AK3 | Der Flutter-Client rendert alle vier neuen Inhaltstypen offline aus dem lokalen Content-Cache, ohne Netzwerk- oder LLM-Aufruf zur Laufzeit | Tester-Lauf mit Netzwerk getrennt nach initialem Sync (analog bestehendem Offline-Test für Karten/Schemata) |
| AK4 | Der Einstieg ist aus der bestehenden Themenübersicht (Dashboard, `_TopicRow`) erreichbar, ausschließlich für die 3 Pilot-Themen; alle anderen Themen zeigen unverändert nur Karten/Schema/Fälle — kein Leerzustand, kein toter Tab | Manueller Durchlauf mit einem Pilot-Thema und einem Nicht-Pilot-Thema |
| AK5 | Lernskript, Lernerlebnisse und Visualisierungen lösen **keine** FSRS-Zustandsänderung aus und fließen **nicht** in `weighted_coverage` ein (Abgrenzung zu `docs/13-lernarchitektur.md` Abschnitt 1.2) | Automatisierter Test: `GET /progress/coverage` vor und nach vollständigem Durchlauf aller Pilot-Inhalte ist identisch |
| AK6 | Jede neue Content-Datei trägt `stand` und `quellen` wie bestehende Bundles (Leitprinzip 6, `docs/01-produktvision.md`) | Gleicher `_check_stand`/`_require`-Mechanismus wie für Karten/Schemata/Fälle, keine Ausnahme im Loader |
| AK7 | Content-Prüfagent hat die 3 Pilot-Themen fachlich freigegeben, bevor sie nach `main` gemerged werden | PR-Review-Kommentar des Content-Prüfagent vor Merge |
| AK8 | Tester bestätigt alle 3 Pilot-Themen Ende-zu-Ende (Desktop **und** Web) ohne Konsolenfehler, mit Screenshot-Beleg je Inhaltstyp | Tester-Run-Protokoll |

---

## 2. Content-Format

Die drei neuen Blöcke leben **in derselben Topic-Datei** wie `cards`,
`schemata` und `faelle` (z. B. `content/zivilrecht/bgb-at-kaufrecht.yaml`) —
kein neues Verzeichnis, kein neuer Lade-Pfad. Das hält die bestehende Regel
„ein Thema, eine Datei" intakt und lässt Redakteure bestehende Karten/Schemata
direkt referenzieren, ohne Dateien zu wechseln.

### 2.1 Lernskript (a)

Gegliederter Erklärtext, der ein Thema zum ersten Mal einführt — die Brücke
zu den bestehenden Karten/Schemata, nicht deren Ersatz. **Wichtig gegen
Leitprinzip 1** (`docs/01-produktvision.md`: „Aktiv vor passiv — kein
Feature, bei dem der Nutzer nur konsumiert"): ein reiner Lesetext wäre ein
Rückschritt. Deshalb kann jeder Abschnitt einen `checkpoint` tragen — eine
Lückentext-/Check-Frage (gleicher Typ wie in 2.2c), die vor dem nächsten
Abschnitt beantwortet werden muss. Das macht Anforderung (b) „interaktive
Lernerlebnisse" teilweise schon zum Bestandteil von (a), statt eine
getrennte, zusätzliche Interaktion zu erzwingen.

```yaml
lernskript:
  slug: zr-bgb-at-skript-vertragsschluss
  title: "Wie ein Vertrag entsteht: Angebot, Annahme, Willenserklärung"
  quellen: ["BGB, amtliche Fassung", "Eigenformulierung Redaktion"]
  stand: "2026-11"
  abschnitte:
    - titel: "Was ist eine Willenserklärung?"
      text: >-
        ... (Fließtext, mehrere Absätze möglich) ...
      card_slugs: ["zr-at-willenserklaerung"]
      checkpoint:
        type: luecke
        frage: "Eine Willenserklärung ist eine ___ Willensäußerung, die auf einen rechtlichen Erfolg gerichtet ist."
        antworten: ["private", "privaten"]
    - titel: "Angebot und invitatio ad offerendum"
      text: >-
        ...
      card_slugs: ["zr-at-angebot", "zr-at-invitatio"]
      schema_slug: zr-schema-433-ii   # optional: Abschnitt kann auf ein bestehendes Schema verweisen
      checkpoint:
        type: frage
        frage: "Ist eine Schaufensterauslage ein Angebot?"
        optionen: ["Ja, mit Rechtsbindungswillen", "Nein, invitatio ad offerendum"]
        richtig: 1
    - titel: "Annahme und Vertragsschluss"
      text: >-
        ...
      card_slugs: ["zr-at-zugang"]
```

Pflichtfelder: `slug`, `title`, `quellen`, `stand`, `abschnitte` (≥ 1).
Je Abschnitt Pflichtfeld: `titel`, `text`. `card_slugs`/`schema_slug`/
`checkpoint` optional, aber mit AK2 für den Piloten faktisch vorgeschrieben
(≥ 1 `card_slugs`-Eintrag je Abschnitt). Genau ein Lernskript je
`topic_slug` im Piloten — die Datenstruktur erlaubt technisch mehr (Liste
wäre denkbar), das ist aber bewusst nicht gebaut, um den Umfang klein zu
halten (Abschnitt 8).

### 2.2 Interaktive Lernerlebnisse (b)

Eigener Block `lernerlebnisse`, Liste mit `type`-Unterscheidung:

**(b1) `gefuehrter_fall`** — Mini-Fall mit Verzweigung, keine Freitext-Eingabe
(Abgrenzung zu den bestehenden `faelle`: dort schreibt der Nutzer ein
Gutachten, hier wählt er zwischen vorgegebenen Antworten — niedrigere
Einstiegshürde für ein Thema, das er noch nicht kennt).

```yaml
lernerlebnisse:
  - slug: zr-bgb-at-erlebnis-rennrad
    type: gefuehrter_fall
    title: "Der verschriebene Preis"
    quellen: ["Eigener Sachverhalt der Redaktion"]
    stand: "2026-11"
    intro: "V stellt ein Rennrad mit einem Preisschild '500 EUR' ins Schaufenster ..."
    start: knoten_1
    knoten:
      - id: knoten_1
        frage: "Ist das Preisschild im Schaufenster schon ein Angebot?"
        optionen:
          - text: "Ja, mit allen essentialia negotii"
            feedback: "Nicht ganz — ein Angebot braucht Rechtsbindungswillen."
            naechster: knoten_1b
          - text: "Nein, invitatio ad offerendum"
            feedback: "Richtig. Der Händler will sich nicht gegenüber jedem binden."
            naechster: knoten_2
      - id: knoten_1b
        frage: "Würde der Händler jedem, der das Rad verlangt, zu 500 EUR verkaufen müssen?"
        optionen:
          - text: "Ja"
            feedback: "Dann hätte er kein Steuerungsrecht über sein Warenlager mehr — das ist gerade der Grund, warum die Auslage keine invitatio ist."
            naechster: knoten_2
          - text: "Nein, eben deshalb ist es keine invitatio"
            feedback: "Richtig."
            naechster: knoten_2
      - id: knoten_2
        frage: "Wer gibt hier das Angebot ab?"
        optionen:
          - text: "Der Kunde, beim Betreten des Ladens"
            feedback: "Richtig — er bezieht sich konkret auf das ausgestellte Rad."
            naechster: ende_richtig
          - text: "Der Händler, mit dem Preisschild"
            feedback: "Das Preisschild war nur invitatio — er kann also noch kein Angebot abgegeben haben."
            naechster: ende_falsch
    ende:
      ende_richtig:
        ergebnis: bestanden
        text: "Genau so läuft § 433 Abs. 1 BGB an: Kunde bietet an, Händler nimmt an."
      ende_falsch:
        ergebnis: wiederholen
        text: "Schau dir Abschnitt 2 des Lernskripts noch einmal an und versuch es erneut."
```

Pflichtfelder: `slug`, `type`, `title`, `quellen`, `stand`, `start`,
`knoten` (≥ 1 Knoten, jeder mit `id`, `frage`, `optionen` ≥ 2), `ende`
(≥ 1 Endknoten mit `ergebnis` ∈ {`bestanden`, `wiederholen`}). Validierung
(Abschnitt 2.4): jedes `naechster` muss auf eine existierende `knoten.id`
oder einen Schlüssel von `ende` zeigen, kein Knoten darf unerreichbar sein,
keine Zyklen zwischen Knoten (ein Zurückspringen auf denselben Knoten ist
nicht vorgesehen — anders als die Fehlerkorrektur im bestehenden
Gutachten-Fluss gibt es hier keinen Bewertungsmechanismus, der eine Wieder-
holung inhaltlich einordnen könnte).

**(b2) `sortieraufgabe`** — Prüfschritte in die richtige Reihenfolge bringen.
**Das ist kein neuer Mechanismus, sondern die konkrete Umsetzung des bereits
in `docs/03-roadmap.md` (M2: „Interaktive Prüfungsschemata, aufklappbar,
Reihenfolge-Drill") und im Code-Kommentar von `app/lib/pages/schemata_page.dart`
angekündigten, bisher nicht gebauten Reihenfolge-Drills.** Dieses Ticket
liefert dafür zum ersten Mal ein konkretes Contentformat und eine Pilot-
Umsetzung, statt einen weiteren, unabhängigen Drill-Typ zu erfinden.

```yaml
lernerlebnisse:
  - slug: zr-bgb-at-sortieraufgabe-433
    type: sortieraufgabe
    title: "Bring die Anspruchsprüfung in die richtige Reihenfolge"
    quellen: ["Eigenformulierung Redaktion, auf Basis des Schemas"]
    stand: "2026-11"
    schema_slug: zr-schema-433-ii
    ebene: 1   # nur die oberste Gliederungsebene (I./II./III.) wird abgefragt, nicht die Unterpunkte
```

Pflichtfelder: `slug`, `type`, `title`, `quellen`, `stand`, `schema_slug`
(muss auf ein Schema **im selben Topic** verweisen), `ebene` (im Piloten
fest `1` — nur `steps[].label` der obersten Ebene wird gemischt und muss
sortiert werden; tiefere Ebenen sind bewusst **nicht** im Pilotumfang, siehe
Abschnitt 8). Kein eigener Inhalt nötig jenseits der Referenz — die
redaktionelle Arbeit ist die Auswahl eines geeigneten Schemas, nicht neues
Schreiben.

**(b3) `luecken_check`** — eigenständige Lückentext-/Check-Frage, derselbe
Typ wie der inline `checkpoint` in 2.1, aber als eigenständiges Lernerlebnis
nutzbar (z. B. als kurzer Wissens-Check nach einem ganzen Lernskript, nicht
nur je Abschnitt):

```yaml
lernerlebnisse:
  - slug: zr-bgb-at-check-abschluss
    type: luecken_check
    title: "Hast du es verstanden?"
    quellen: ["Eigenformulierung Redaktion"]
    stand: "2026-11"
    fragen:
      - type: luecke
        frage: "Eine invitatio ad offerendum fehlt der ___."
        antworten: ["Rechtsbindungswille", "Rechtsbindungswillen"]
      - type: frage
        frage: "Wer nimmt im Schaufenster-Fall das Angebot an?"
        optionen: ["Der Kunde", "Der Händler"]
        richtig: 1
```

Antwortprüfung läuft **rein clientseitig** gegen die in der YAML-Datei
hinterlegten `antworten`/`richtig`-Werte — kein Bewertungs-Endpunkt, kein
`Submission`-Eintrag, kein LLM. Das ist bewusst einfacher als die
heuristische Stichwortprüfung des bestehenden `HeuristicEvaluator`
(`docs/13-lernarchitektur.md` Abschnitt 1.3): hier geht es um kurze,
vorhersehbare Antworten (ein Wort, eine Auswahl), nicht um ein Gutachten.

### 2.3 Visualisierungen (c)

Eigener Block `visualisierungen`. **Zwei der drei Typen brauchen keinen
neuen fachlichen Inhalt** — sie sind reine Renderings des bereits
bestehenden `Schema.steps`-Baums (siehe `zr-schema-433-ii` oben). Nur der
Zeitstrahl braucht eine eigene, chronologische Datenstruktur, weil ein
Prüfungsschema keine zeitliche Reihenfolge, sondern eine
Prüfungsreihenfolge kodiert.

```yaml
visualisierungen:
  - slug: zr-bgb-at-flussdiagramm-433
    type: flussdiagramm
    title: "Anspruch aus § 433 Abs. 2 BGB als Ablauf"
    quellen: ["Eigenformulierung Redaktion, auf Basis des Schemas"]
    stand: "2026-11"
    schema_slug: zr-schema-433-ii

  - slug: zr-bgb-at-baum-433
    type: baum
    title: "Anspruchsaufbau § 433 Abs. 2 BGB"
    quellen: ["Eigenformulierung Redaktion, auf Basis des Schemas"]
    stand: "2026-11"
    schema_slug: zr-schema-433-ii

  - slug: or-anfechtungsklage-zeitstrahl-fristen
    type: zeitstrahl
    title: "Fristenlauf bis zur Anfechtungsklage"
    quellen: ["§§ 68 ff. VwGO, § 42 Abs. 1 VwGO, amtliche Fassung"]
    stand: "2026-11"
    punkte:
      - label: "Erlass des Verwaltungsakts"
        hinweis: "Bekanntgabe setzt die Rechtsbehelfsfrist in Gang (§ 41 VwVfG)."
      - label: "Widerspruch, § 69 VwGO"
        hinweis: "Innerhalb eines Monats nach Bekanntgabe (§ 70 Abs. 1 VwGO), sofern kein Fall des § 68 Abs. 1 S. 2 VwGO vorliegt."
      - label: "Widerspruchsbescheid"
        hinweis: "Abhilfe oder Zurückweisung."
      - label: "Anfechtungsklage, § 42 Abs. 1 Var. 1 VwGO"
        hinweis: "Innerhalb eines Monats nach Zustellung des Widerspruchsbescheids (§ 74 Abs. 1 VwGO)."
```

Pflichtfelder: `slug`, `type` ∈ {`flussdiagramm`, `baum`, `zeitstrahl`},
`title`, `quellen`, `stand`. `flussdiagramm`/`baum`: zusätzlich
`schema_slug` (muss auf ein Schema im selben Topic verweisen).
`zeitstrahl`: zusätzlich `punkte` (≥ 2, je mit `label`; `hinweis` optional).
**Bewusst keine echten Kalenderdaten im Zeitstrahl** — Fristen hängen vom
jeweiligen Sachverhalt ab, der Zeitstrahl zeigt die **Reihenfolge und
Fristenlogik**, nicht einen konkreten Termin. Flussdiagramm und Baum
unterscheiden sich nur in der Darstellung (Abschnitt 3), nicht im
Contentformat — beide referenzieren dasselbe `schema_slug`.

### 2.4 Validierung (`backend/app/services/content.py`)

Erweiterung nach demselben Muster wie die bestehenden Blöcke:

- `VALID_LERNERLEBNIS_TYPES = {"gefuehrter_fall", "sortieraufgabe", "luecken_check"}`,
  `VALID_VISUALISIERUNG_TYPES = {"flussdiagramm", "baum", "zeitstrahl"}`.
- `_require()` auf die Pflichtfelder je Block/Typ aus 2.1–2.3, wie bereits für
  `cards`/`schemata`/`faelle` gemacht (`content.py:120-220`).
- `_check_stand()` auf `lernskript`/jedes `lernerlebnis`/jede `visualisierung`,
  identisch zur bestehenden Staleness-Warnung (18 Monate).
- Neue Cross-Referenz-Prüfungen, analog zum bestehenden `card_slug_refs`-Sammel-
  und-Prüf-Mechanismus (`content.py:116-119,230-237`): `lernskript.abschnitte[].card_slugs`
  gegen `bundle.cards`, `lernskript.abschnitte[].schema_slug` und
  `sortieraufgabe/flussdiagramm/baum.schema_slug` gegen `bundle.schemata` —
  **zusätzlich mit der Prüfung, dass das referenzierte Schema denselben
  `topic_slug` trägt** wie der verweisende Block (eine Sortieraufgabe, die auf
  ein Schema eines anderen Themas zeigt, ist ein Redaktionsfehler, kein
  gültiger Querverweis).
- `gefuehrter_fall`: Graph-Validierung wie in 2.2b1 beschrieben (jedes
  `naechster` existiert, jeder Knoten erreichbar von `start`, keine Zyklen).
- Slug-Eindeutigkeit über das bestehende globale `slugs`-Register
  (`content.py:166-171`) — neue Slugs kollidieren mit Karten/Schemata/Fällen
  genauso wie diese bereits heute untereinander.
- `ContentBundle` bekommt drei neue Felder (`lernskripte`, `lernerlebnisse`,
  `visualisierungen`), `seed()` schreibt sie idempotent in drei neue Tabellen
  (Abschnitt 5, Ticket 1) — exakt das bestehende Muster für `Card`/`Schema`/
  `Case` (`content.py:449-465`), kein neuer Seeding-Mechanismus.

---

## 3. App-Darstellung (Flutter)

### 3.1 Einstieg aus der Themenübersicht

Die Dashboard-Themenliste (`_TopicRow` in `app/lib/pages/dashboard_page.dart`)
ist heute eine reine Fortschrittsanzeige ohne `onTap`. Sie wird tappable und
öffnet eine neue `ThemaUebersichtPage`. Diese Seite zeigt — **nur, wenn für
das Thema vorhanden** (`manifest`-Zähler aus Abschnitt 5, Ticket 2 prüfen das
vorab) — einen Abschnitt „Neu hier?" mit Links auf Lernskript, geführten Fall,
Sortieraufgabe und Visualisierungen, zusätzlich zu den bestehenden Links auf
Karten/Schema/Fälle des Themas (die es unverändert gibt). Themen ohne
Pilot-Content zeigen diesen Abschnitt schlicht nicht — kein Leerzustand zu
gestalten (AK4).

### 3.2 Neue Widgets

- **`LernskriptWidget`** (neue Seite `lernskript_page.dart`): rendert die
  Abschnitte sequenziell, mit Chips auf referenzierte Karten/Schemata (Tap
  öffnet die bestehende Karten-/Schema-Ansicht). Ein `checkpoint` blendet
  `LueckeCheckInlineWidget`/`FrageInlineWidget` ein und schaltet den
  „Weiter"-Button erst nach einer Antwort frei (keine Sperre bei falscher
  Antwort — Leitprinzip 5 „kein Druck durch Design" gilt auch hier, Zweck ist
  Aktivierung, nicht Prüfung).
- **`GefuehrterFallWidget`**: Knoten-für-Knoten-Player mit Buttons statt
  Freitext, Feedback nach jeder Wahl über die bestehende
  `SubsumoFeedbackBlock`-Komponente (`app/lib/design/components/subsumo_feedback_block.dart`)
  — keine neue Feedback-Darstellung nötig.
- **`SortieraufgabeWidget`**: lädt `Schema.steps` der obersten Ebene über die
  bestehende `/content/schemata`-API, mischt sie client-seitig, Nutzer bringt
  sie per Drag oder Auf-/Ab-Buttons in die richtige Reihenfolge, Prüf-Button
  vergleicht gegen die Originalreihenfolge. Bewusst als eigenständige, nach
  Schema-Slug parametrisierte Komponente gebaut — wiederverwendbar für den in
  `docs/03-roadmap.md` (M2) vorgesehenen generischen Reihenfolge-Drill über
  **alle** Schemata, nicht nur die 3 Pilot-Themen (Ausbau als Folgeticket,
  Abschnitt 8).
- **`FlussdiagrammWidget`** / **`AnspruchsaufbauBaumWidget`**: beide
  konsumieren dieselbe `Schema.steps`-Struktur, unterscheiden sich nur im
  Layout — Flussdiagramm als lineare Kastenkette von oben nach unten mit
  Pfeilen (nur Hauptebene I./II./III.), Baum als vollständig eingerückte
  Gliederung inklusive aller Unterpunkte und `hinweis`-Texte (z. B. die
  bedingte Anfechtungsprüfung aus `zr-schema-433-ii`). Reiner Rendering-Code,
  keine neue Datenquelle.
- **`ZeitstrahlWidget`**: horizontale (breit) bzw. vertikale (schmal)
  Abfolge von `punkte`-Markern mit `hinweis`-Text, Breakpoint analog zu
  `breit` in `schemata_page.dart`.

### 3.3 Verzahnung mit Fortschritt/FSRS

**Entscheidung: keine.** Lernskript, geführter Fall, Sortieraufgabe und
Visualisierungen erzeugen **keinen** `UserCard`-/`Review`-Eintrag und fließen
nicht in `mastery`/`weighted_coverage` ein (AK5). Begründung: Abschnitt 1.2
von `docs/13-lernarchitektur.md` benennt die Coverage-Zahl bereits heute als
ausschließlich wissens-/anwendungsbasiert und als fragil gegenüber
Verwässerung durch zusätzliche, nicht vergleichbare Signale (dort
„Änderungsbedarf" #1/#2). Ein „Lernskript gelesen"-Signal in dieselbe Zahl zu
mischen, würde genau die dort beschriebene Verwässerung wiederholen, nur mit
einem neuen Feature statt mit Technik-Karten. Einziges persistiertes Signal
im Piloten: ein rein clientseitiges `gesehen`-Flag je (Nutzer, Lernskript-Slug)
in `app/lib/state.dart` (SharedPreferences, kein Server-Roundtrip, keine neue
Backend-Tabelle) — zeigt nur „schon geöffnet" in der `ThemaUebersichtPage` an,
nichts weiter.

**Bewusst nicht im Piloten** (Folgeticket, siehe Abschnitt 8): eine korrekt
gelöste Sortieraufgabe/Lücken-Check könnte die referenzierten Karten als
`cards_started` markieren (Vorgriff auf das Thema) — das würde den
`Pruefpunkt.card_slugs`-Mechanismus aus `docs/13` Abschnitt 3.3 spiegeln,
braucht aber eine eigene Entscheidung darüber, ob ein Einstiegserlebnis
„Kartenstart" auslösen darf, und ist für den Piloten nicht nötig.

---

## 4. Pilotumfang: 3 Themen

Ein Thema je Rechtsgebiet, wie im Auftrag vorgeschlagen — mit den konkreten,
bereits existierenden Themen-Slugs statt nur Beispielbezeichnungen:

| Rechtsgebiet | Thema (bestehender `topic_slug`) | Bestehende Datei | Zeitstrahl im Piloten? |
|---|---|---|---|
| Zivilrecht | `zr-bgb-at` — Vertragsschluss (Angebot/Annahme im BGB AT) | `content/zivilrecht/bgb-at-kaufrecht.yaml` | Nein — ein Vertragsschluss hat keine prüfungsrelevante Frist, die einen eigenen Zeitstrahl rechtfertigt; ausgelassen statt erzwungen |
| Strafrecht | `sr-at-vorsatz-tatbestandsirrtum` — Aufbau des Vorsatzdelikts | `content/strafrecht/sr-at-vorsatz-tatbestandsirrtum.yaml` | Nein, aus demselben Grund |
| Öffentliches Recht | `or-vwgo-anfechtungsklage` — Zulässigkeit der Anfechtungsklage | `content/oeffentliches-recht/or-vwgo-anfechtungsklage.yaml` | Ja — Fristenlauf Widerspruch → Widerspruchsbescheid → Klage (Abschnitt 2.3) |

Jedes der drei Themen hat bereits ein passendes Schema (`zr-schema-433-ii`,
`sr-schema-...`, `or-...`), auf das Sortieraufgabe, Flussdiagramm und Baum
ohne neue fachliche Recherche verweisen können — die redaktionelle Arbeit im
Piloten konzentriert sich auf das, was wirklich neu geschrieben werden muss:
3 Lernskripte, 3 geführte Fälle, 1 Zeitstrahl. Visualisierungstyp und
Lernerlebnistyp müssen im Piloten **mindestens einmal über alle drei Themen**
vorkommen, nicht zwingend bei jedem Thema jeder Typ (die Zeitstrahl-Spalte
oben ist die einzige bewusste Auslassung, begründet statt stillschweigend).

---

## 5. Zerlegung in Tickets

| # | Ticket | Rolle | Abhängigkeit |
|---|---|---|---|
| 1 | YAML-Schema-Erweiterung + Validator in `content.py` (`lernskript`, `lernerlebnisse`, `visualisierungen`, neue `VALID_*`-Sets, Cross-Referenz- und Graph-Validierung aus Abschnitt 2.4); 3 neue Models (`Lernskript`, `Lernerlebnis`, `Visualisierung`, JSON-Payload-Spalten analog zu `Schema.steps`) + Alembic-Migration + `seed()`-Erweiterung | Backend-Developer | keine |
| 2 | API-Endpunkte `GET /content/lernskripte`, `/lernerlebnisse`, `/visualisierungen` (+ Pydantic-Schemas nach Muster `SchemaOut`/`CaseSummaryOut`) sowie Zähler in `GET /content/manifest` | Backend-Developer | 1 |
| 3 | `ThemaUebersichtPage` + Dashboard-Verzahnung (`_TopicRow` tappable, „Neu hier?"-Abschnitt nur für Pilot-Themen, Dart-API-Client-Methoden) | Frontend-Developer | 2 |
| 4 | `LernskriptWidget` inkl. inline Checkpoint (Lücke/Frage) | Frontend-Developer | 2 |
| 5 | `GefuehrterFallWidget` (Branching-Player, Feedback via `SubsumoFeedbackBlock`) | Frontend-Developer | 2 |
| 6 | `SortieraufgabeWidget` (Drag-/Tap-Reorder bestehender Schema-Schritte, bewusst wiederverwendbar für den M2-Reihenfolge-Drill aus `docs/03-roadmap.md`) | UI-Developer | 2 |
| 7 | Visualisierungs-Renderer: `FlussdiagrammWidget`, `AnspruchsaufbauBaumWidget`, `ZeitstrahlWidget` | UI-Developer | 2 |
| 8 | Pilot-Inhalte Thema `zr-bgb-at` (Lernskript, geführter Fall, Sortieraufgabe-/Visualisierungs-Kuratierung) | Content-Zivilrecht-Redakteur | 1 (Format muss stehen) |
| 9 | Pilot-Inhalte Thema `sr-at-vorsatz-tatbestandsirrtum` | Content-Strafrecht-Redakteur | 1 |
| 10 | Pilot-Inhalte Thema `or-vwgo-anfechtungsklage` inkl. Zeitstrahl (Fristenlauf) | Content-Oeffentliches-Recht-Redakteur | 1 |
| 11 | Fachliche Prüfung aller 3 Pilot-Themen (Richtigkeit, Quellenbeleg, `stand`), Freigabe vor Merge (AK7) | Content-Pruefagent | 8, 9, 10 |
| 12 | Ende-zu-Ende-Test aller 3 Pilot-Themen, Desktop + Web, inkl. Regressionscheck „Coverage/FSRS unverändert" (AK5) | Tester | 3, 4, 5, 6, 7, 11 |

Reihenfolge: 1 ist Voraussetzung für alles andere. 2 sowie 8–10 können
parallel zu 1 vorbereitet werden (Redaktion kann am Format mitarbeiten,
bevor die Validierung steht), aber erst nach 1 gegen die echte CI validiert
werden. 3–7 können parallel zueinander laufen, sobald 2 steht. 11 hängt an
allen drei Redaktionstickets, 12 ist das Abnahme-Gate und hängt an allem.

---

## 6. Nicht Gegenstand dieses Dokuments

1. **Ausbau über 3 Themen hinaus.** Der Pilot ist bewusst klein (Auftrag:
   „Scope bitte bewusst klein halten"). Weitere Themen sind Folgetickets nach
   demselben Format, keine neue Spezifikation nötig.
2. **Kartenstart-Verzahnung über gelöste Lernerlebnisse** (Abschnitt 3.3) —
   Entwurfsentscheidung, die erst nach Beobachtung des Piloten sinnvoll
   getroffen wird.
3. **Generischer Reihenfolge-Drill über alle Schemata** (`docs/03-roadmap.md`,
   M2) — Ticket 6 liefert die Komponente, aber nur parametrisiert auf die 3
   Pilot-Schemata; der Rollout auf alle Schemata ist ein eigener, kleiner
   Folgeschritt (Komponente existiert dann schon).
4. **Mehrsprachigkeit/Barrierefreiheit der neuen Widgets** über das hinaus,
   was die bestehenden Design-Komponenten (`app/lib/design/components/`)
   bereits mitbringen — kein neuer Standard für dieses Ticket.

---

## Quellen

- Auftrag: [SUB-810](/SUB/issues/SUB-810)
- Bestehende Lernarchitektur und offene Änderungsbedarfe (insb. Abschnitt 1.2
  Coverage-Definition, Abschnitt 3.3 `card_slugs`): `docs/13-lernarchitektur.md`
- Produktvision, Leitprinzipien 1/5/6: `docs/01-produktvision.md`
- Roadmap, M2-Ankündigung des Reihenfolge-Drills: `docs/03-roadmap.md`
- Bestehendes Contentformat und Validierung: `backend/app/services/content.py`,
  `backend/scripts/validate_content.py`, Beispiel
  `content/zivilrecht/bgb-at-kaufrecht.yaml`
- Pilot-Themen-Dateien: `content/strafrecht/sr-at-vorsatz-tatbestandsirrtum.yaml`,
  `content/oeffentliches-recht/or-vwgo-anfechtungsklage.yaml`
- Bestehende App-Struktur: `app/lib/pages/dashboard_page.dart`,
  `app/lib/pages/schemata_page.dart`, `app/lib/design/components/subsumo_feedback_block.dart`
- Content-Rollen: `ops/agents/content/content-zivilrecht-redakteur.md`,
  `content-strafrecht-redakteur.md`, `content-oeffentliches-recht-redakteur.md`,
  `content-pruefagent.md`
- AVV-/LLM-Gate: `docs/23-llm-provider-avv.md`, `docs/18-release-2-wochen.md`
