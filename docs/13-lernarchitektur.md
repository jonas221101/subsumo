# Lernarchitektur

Löst [SUB-44](/SUB/issues/SUB-44), Spur T4 der [Release-Roadmap](/SUB/issues/SUB-39#document-plan).
Das didaktische Modell von Subsumo steckt heute implizit im Code — in den
FSRS-Parametern (`backend/app/services/srs.py`), den Planer-Heuristiken
(`backend/app/services/planner.py`) und den Prüfpunkten des
Erwartungshorizonts (`backend/app/services/evaluator.py`). Dieses Dokument
macht es explizit: was ist eine Kompetenz, wann gilt sie als erreicht, welchen
Weg geht ein Nutzer hindurch, welche Fehler unterscheidet das System, und
woher weiß irgendjemand, dass das alles stimmt.

Methodik: Abschnitt 1 beschreibt, was der Code heute tut, nicht was er tun
sollte — Abweichungen sind explizit als **Änderungsbedarf** markiert, nicht
stillschweigend wegkorrigiert. Eine Zusammenfassung aller Änderungsbedarfe
steht am Ende (Abschnitt 6).

## 1. Lernmodell

### 1.1 Kompetenzhierarchie: Karte → Schema → Fall → Gutachten

Das Datenmodell (`backend/app/models.py`, siehe auch `docs/04-datenmodell.md`)
kennt vier Inhaltsebenen, die konzeptionell aufeinander aufbauen:

| Ebene | Tabelle | Was sie prüft | Wird individuell verfolgt? |
|---|---|---|---|
| Wissen | `cards` (`type`: `definition`, `schema_step`, `norm`, `streitstand`, `rechtsprechung`) | Kann der Nutzer einen einzelnen Fakt/eine Definition erinnern? | Ja — `user_cards` + FSRS (`srs.py`) |
| Struktur | `schemata` (verschachtelte `steps`) | Kennt der Nutzer die Prüfungsreihenfolge eines Anspruchs/Delikts? | **Nein** — statischer Inhalt, keine eigene Zustandstabelle |
| Anwendung | `cases` (`steps` = geführte Teilschritte, `expectation` = Erwartungshorizont) | Kann der Nutzer das Wissen auf einen Sachverhalt anwenden? | Teilweise — `submissions` je Versuch, aber kein aggregierter Fall-Mastery-Wert |
| Rückmeldung | `submissions.report` (`structure` aus `gutachten.py`, `evaluation` aus `evaluator.py`) | War die Anwendung handwerklich und inhaltlich richtig? | Ja, pro Abgabe, nicht kumuliert |

**Wichtige Abweichung von der Produktvision:** `docs/01-produktvision.md`
beschreibt die Verzahnung als „Eine Karte kennt ihr Schema, das Schema kennt
seine Fälle". Im Code gibt es dafür **keine Fremdschlüsselkette** — `Card`,
`Schema` und `Case` tragen unabhängig voneinander dasselbe `topic_slug`
(`backend/app/models.py:91,147,168`), verknüpft sind sie also nur implizit
über ein gemeinsames Thema, nicht explizit über eine Kette. Das reicht für
„zeig mir alles zu Thema X", aber nicht für die im Vision-Dokument behauptete
und in Abschnitt 3 dieses Dokuments benötigte Aussage „dieser konkrete
Prüfpunkt in diesem Fall gehört zu jenen konkreten Karten". Ob und wie eng
diese Verzahnung tatsächlich sein muss, ist die offene Frage von T5
(`docs/16-innovationsthesen.md`, [SUB-45](/SUB/issues/SUB-45)) — dieses
Dokument entwirft in Abschnitt 3.3 nur den minimal nötigen Ausschnitt, der die
Fehlertaxonomie implementierbar macht.

**Kompetenz, als Arbeitsdefinition:** Eine Kompetenz ist an ein `Topic`
gebunden und hat zwei unabhängige Dimensionen — *Wissen* (reproduzierbare
Karten) und *Anwendung* (belastbare Fallbearbeitung). Ein Thema ist nicht
„gekonnt", weil alle Karten reif sind; es ist bestenfalls „gewusst". Diese
Unterscheidung ist keine Wortklauberei, sondern die Grundlage von Abschnitt
1.2 — genau hier weicht die heutige Coverage-Zahl vom Kompetenzbegriff ab.

### 1.2 Wann gilt ein Thema als „gekonnt"? Die Coverage-Definition

Maßgeblich ist `GET /progress/coverage`
(`backend/app/api/v1/learn.py:186-241`). Für jede Karte eines Themas gilt sie
als **reif** (`mature`), wenn:

```
uc.stability >= MATURE_STABILITY_DAYS (= 21.0)  UND  uc.state == "review"
```

„Reif" heißt also: die FSRS-Stabilität übersteigt 21 Tage — die Karte würde
laut Modell auch ohne baldige Wiederholung über ein Semester hinweg im
Gedächtnis bleiben (`backend/app/api/v1/learn.py:26-28`). Das
Themen-`mastery` ist der Anteil reifer Karten an allen Karten des Themas:

```
mastery(topic) = mature_cards(topic) / total_cards(topic)
```

Die angezeigte **Coverage-Zahl** (`weighted_coverage`) ist der nach
`topic.relevance` (1–5) gewichtete Mittelwert über alle Themen, ebenso
`by_area` je Rechtsgebiet:

```
weighted_coverage = Σ(relevance_t · mastery_t) / Σ(relevance_t)
```

**Das ist die vollständige, korrekte Beschreibung dessen, was der Code tut.**
Sie ist bewusst konservativ — „gesehen" zählt nicht, nur „reif" zählt
(Kommentar im Code: „gezählt wird nur, was reif ist — nicht, was schon einmal
gesehen wurde", `learn.py:188-189`), was zu Leitprinzip 4 passt.

**Änderungsbedarf:** Die Coverage-Zahl misst ausschließlich die
*Wissens*-Dimension aus 1.1 (Karten-Reife). Sie enthält keinerlei
Fall-/Gutachten-Performance — ein Thema mit zehn reifen Karten, aber null
bestandenen Fällen, zeigt dieselbe Coverage wie eines mit denselben Karten und
lauter bestandenen Fällen. Für Lena (Abschnitt 2.1) ist das ehrlich, weil sie
noch keine Fälle bearbeitet — für Jonas und Mira (Abschnitt 2.2, 2.3), deren
Kernproblem laut Produktvision gerade das Scheitern in der *Anwendung* ist,
ist eine reine Wissens-Coverage-Zahl irreführend, wenn sie als „kann ich"
gelesen wird. Zwei Optionen, keine davon in diesem Ticket umgesetzt:

1. **Label schärfen (klein, sofort machbar):** UI-Text von „Coverage" bzw.
   „Wissenslandkarte" auf etwas wie „Karten-Reife" o. Ä. präzisieren, ohne die
   Formel zu ändern. Ehrlicher, aber verschenkt Information.
2. **Formel erweitern (größer, braucht 3.3):** Sobald Fälle je Thema über
   `Pruefpunkt.card_slug` (Abschnitt 3.3) mit Karten verknüpft sind, kann ein
   zweiter Faktor `anwendung_t` (z. B. Anteil erfolgreich gelöster
   Pflicht-Prüfpunkte über die letzten *n* Versuche je Thema) eingeführt und
   z. B. als `mastery_t = 0.5·wissen_t + 0.5·anwendung_t` gemischt werden. Das
   ist die sauberere Lösung, setzt aber die Datenmodell-Erweiterung aus 3.3
   voraus und sollte nicht vor T5s Verzahnungs-Entscheidung gebaut werden.

Empfehlung: Option 1 vor v1.0 (kostet nichts), Option 2 als Folgeticket nach
T5.

### 1.3 Zwei getrennte Bewertungsebenen: Struktur und Inhalt

Zwei unabhängige, bewusst getrennte Scores pro Abgabe (`gutachten.py:1-11`):

- **Strukturscore** (`gutachten.py::analyze`, 0–100): regelbasiert, offline,
  reproduzierbar — prüft Gutachtenstil-*Technik* (Obersatz/Definition/
  Subsumtion/Ergebnis, Verschachtelung, Urteilsstil), unabhängig vom
  konkreten Fall. Kostenlos und sofort, auch ohne LLM-Provider
  (`POST /gutachten/analyze`).
- **Inhaltliche Bewertung** (`evaluator.py`, 0–18 JAP-Skala): prüft, *ob* die
  im Erwartungshorizont hinterlegten Prüfpunkte inhaltlich getroffen wurden.
  Zwei Engines: `HeuristicEvaluator` (Stichwort-/Normabgleich, **hart gedeckelt
  bei `HEURISTIK_MAX_PUNKTE = 11.0`**, `evaluator.py:146`) und `LLMEvaluator`
  (fällt bei jedem Fehler lautlos auf die Heuristik zurück,
  `evaluator.py:238-296`). Endgültiger Punktwert:
  `0.72·Inhaltsquote + 0.28·(Strukturscore/100)`, skaliert auf 0–18
  (`evaluator.py:204,324`).

Diese Trennung ist für die Fehlertaxonomie zentral: Strukturfehler
(Abschnitt 3, Kategorie A) sind themenübergreifend und fallunabhängig
handwerkliche Fehler; Inhaltsfehler (Kategorie B) sind an einen konkreten
Prüfpunkt und damit an ein konkretes Thema gebunden. Die Deckelung der
Heuristik ist wichtig für Abschnitt 4: Eine Kalibrierung gegen die volle
0–18-Skala ist für die Heuristik strukturell unmöglich und daher kein Ziel
(siehe 4.1).

## 2. Lernpfade

Ausgangslage: Es gibt keinen Onboarding-Fragebogen, keinen „Nächster
Schritt"-Endpunkt und keine persona-spezifische Führung im Code — nur
Bausteine, aus denen ein Pfad zusammengesetzt werden kann: `Topic.position`
für die Reihenfolge innerhalb eines Rechtsgebiets (bereits genutzt in
`coverage()`, `learn.py:193`, und in `plan.py:46`), die Relevanz-Sortierung
neuer Karten (`learn.py:93-98`), und der Planer (`planner.py`) für einen
examenszentrierten Tagesplan. Die folgenden drei Pfade sind ein **Entwurf**,
der diese Bausteine persona-spezifisch zusammensetzt — nicht eine Beschreibung
bereits gebauter Führung. Was fehlt, ist an jeder Stelle benannt.

### 2.1 Lena — 1. Semester

**Einstiegspunkt.** Onboarding fragt (heute nicht vorhanden, **Änderungsbedarf**)
das aktuelle Semester bzw. die aktuell belegten Themenblöcke ab und wählt
daraus die Startthemen: alle Themen mit `relevance = 5` und Priorität P1 aus
`docs/12-content-produktionsplan.md`, in der Reihenfolge von `Topic.position`
je Rechtsgebiet — z. B. Zivilrecht: BGB AT vor Stellvertretung vor
Willenserklärung/Auslegung. Ohne dieses Onboarding fällt Lena heute auf die
generische `/cards/due`-Reihenfolge zurück (neue Karten nach
Themen-Relevanz, `learn.py:93-98`), was ohne Semesterfilter Karten aus allen
drei Rechtsgebieten und allen Schwierigkeitsstufen gleichzeitig zeigt — für
Tag 1 zu viel Wahl.

**Geführte Reihenfolge.** Karten vor Schemata vor Fällen, pro Thema. Ein Fall
eines Themas wird erst vorgeschlagen (nicht gesperrt — Free-Tier-Prinzip
„aktiv vor passiv" bleibt), wenn `cards_started` (`CoverageTopicOut`,
`learn.py:210-215,221-230`) für das Thema eine Schwelle überschreitet, z. B.
≥ 60 % der Karten des Themas mindestens einmal beantwortet. Vorschlag, keine
gebaute Schwelle.

**Tagespensum.** Klein, 15–20 Minuten: fast ausschließlich neue Karten,
Wiederholungslast ist am Anfang naturgemäß gering. Kein aktiver
`POST /plan`-Aufruf nötig — Lena hat typischerweise noch kein Examensdatum
(`User.exam_date` ist `nullable`, `models.py:64`), der adaptive Planer
(Abschnitt 2.3) ist für sie nicht der richtige Mechanismus.

**Abbruch und Wiedereinstieg.** Siehe 2.4 — für Lena besonders relevant, weil
Semesterpausen und Klausurphasen anderer Fächer lange Lücken verursachen.

### 2.2 Jonas — 5. Semester, Schwerpunkt

**Einstiegspunkt.** Fälle, nicht Karten — Jonas kann laut Produktvision die
Grundlagen bereits. Direkter Einstieg in `/cases/{slug}` seines
Schwerpunktbereichs, unabhängig vom Kartenreifegrad (Struktur-Feedback über
`/gutachten/analyze` ist ohnehin kostenlos und sofort verfügbar, auch ohne
Login-Historie zum Thema).

**Geführte Reihenfolge.** Pro Thema: Schema ansehen (Struktur auffrischen) →
Fall bearbeiten → sofortiges Strukturfeedback → bei Pro-Abo inhaltliche
Bewertung. Nicht getroffene Prüfpunkte (`evaluation.checkpoints`,
`evaluator.py:61-68`) werden nach Abschnitt 3 zu gezielten
Wiederholungskarten — das *ist* Jonas' Kernnutzen, siehe Abschnitt 3.

**Tagespensum.** Mittel, 45–60 Minuten. Sinnvoll mit gesetztem Examens- oder
Klausurtermin über `POST /plan` (das Feld heißt `exam_date`, ist aber nicht
auf das Staatsexamen beschränkt — für eine Schwerpunktklausur nutzbar). Der
Planer räumt Rückstände zuerst ab (`planner.py:216-230`) und kappt bei mehr
als 150 Minuten Rückstand jeden neuen Stoff zugunsten von Backlog-Abbau
(`planner.py:233-238`) — schützt genau vor dem in `srs.py:246-247`
benannten Hauptabbruchgrund „400-Karten-Rückstand nach dem Urlaub".

**Abbruch und Wiedereinstieg.** Siehe 2.4.

### 2.3 Mira — Examensvorbereitung, Monat 9 von 14

**Einstiegspunkt.** Voller `generate_plan`-Betrieb (`planner.py`): festes
`exam_date`, `daily_minutes` deutlich höher (180–240 min), wöchentlicher
Klausurtag (`KLAUSUR_WEEKDAY = 5`, Samstag, `planner.py:25,202-214`) unter
Examensbedingungen in der Endspurtphase (300 Minuten,
`planner.py:204`).

**Geführte Reihenfolge.** Interleaving über die Rechtsgebiete
(`_interleave_by_area`, `planner.py:117-129`) statt Themenblöcke — bewusst,
weil verschränktes Lernen bei Transferaufgaben nachweislich besser
abschneidet (`planner.py:14-16`). Priorität je Thema:
`relevance · (1 − mastery)` (`planner.py:42-44`) — bereits gelernte Themen
treten zugunsten schwacher zurück.

**Tagespensum.** Wiederholungen zuerst, gedeckelt auf 60 % des Tagesbudgets
(`MAX_REVIEW_SHARE = 0.6`, `planner.py:30,219-226`), Rest für neuen Stoff
bzw. zweiten Durchgang mit Fallanwendung (`planner.py:174-178,246-247`).

**Beobachtung zur Phasenrechnung:** `generate_plan` berechnet die drei Phasen
(Grundlagen 55 %/Vertiefung 30 %/Endspurt 15 %, `PHASE_SPLIT`,
`planner.py:28,132-140`) relativ zum **beim jeweiligen Aufruf verbleibenden**
Zeitraum (`start=date.today()` bis `exam_date`, gesetzt in
`plan.py:84-85`), nicht relativ zur gesamten, ursprünglich geplanten
Vorbereitungszeit. Fordert Mira in Monat 9 von 14 (5 Monate verbleibend)
einen neuen Plan an, gilt intern wieder 55 % dieser 5 Monate als
„Grundlagen" — obwohl sie inhaltlich längst in der Vertiefung ist. Die
Themenpriorisierung selbst bleibt davon unberührt (sie hängt an `mastery`,
nicht an der Phase), aber das Phasen-*Label* steuert z. B., ob überhaupt
Klausuren unter Examensbedingungen stattfinden (`phase != PHASE_GRUNDLAGEN`,
`planner.py:203`) — bei häufigem Neu-Planen könnte das echte Klausurtraining
unbeabsichtigt verzögert werden. **Änderungsbedarf:** Phasenberechnung sollte
den ursprünglichen Vorbereitungsbeginn (z. B. `User.exam_date` minus einer
einmal gesetzten Gesamtdauer, oder schlicht das Datum der ersten
`POST /plan`) statt des Neuberechnungszeitpunkts zugrunde legen. Kein
Blocker für v1.0, aber vor M4-Ausbau (adaptiver Plan) zu klären.

**Abbruch und Wiedereinstieg.** Siehe 2.4 — für Mira ist der Rückstand-Cap
(`planner.py:233-238`) die wichtigste einzelne Regel im gesamten Lernmodell:
ohne ihn wäre ein einwöchiger Ausfall (Krankheit, Familie) mit
250 Minuten Tagespensum ein Rückstand, den der Plan nie mehr auflöst, bevor
das Examen kommt.

### 2.4 Gemeinsamer Baustein: Abbruch und Wiedereinstieg

Leitprinzip 5 („Kein Druck durch Design. Streaks brechen nicht an einem
Krankheitstag", `docs/01-produktvision.md:52`) ist heute konsistent
umgesetzt, weil es **nichts umzusetzen gab**: Es existiert kein
Streak-Zähler im Code (weder Backend-Modell noch
`app/lib/state.dart`/`dashboard_page.dart`). Wiedereinstieg läuft technisch
über zwei unabhängige, bereits vorhandene Mechanismen:

1. **`/cards/due` ist von sich aus stumpf und ehrlich.** Es liefert, was
   fällig ist, begrenzt auf `limit` (Standard 20, `learn.py:47`) — kein
   „du hast 400 Karten verpasst"-Bildschirm, einfach die nächsten 20. Das
   deckelt die wahrgenommene Rückstandsgröße pro Sitzung strukturell, auch
   ohne UI-Zutun.
2. **Der Planer verteilt Rückstand statt ihn zu löschen** (`backlog`-Feld in
   `PlanDay`, `planner.py:63-75`) und bremst neuen Stoff, bis er abgebaut ist
   (Regel 3 aus dem Modul-Docstring, `planner.py:8-9`). Das gilt nur für
   Nutzer mit aktivem Plan (Jonas, Mira) — Lena ohne Plan hat ohnehin kein
   Tagesbudget, das „gesprengt" werden könnte.

**Änderungsbedarf, klein:** Für Lena/Jonas ohne aktiven Plan gibt es keine
äquivalente Rückstands-Kappung — `/cards/due` deckelt zwar die pro Anfrage
sichtbare Menge, aber ein Nutzer mit 400 fälligen Karten sieht nach dem
zwanzigsten Abruf immer noch 380 weitere. Ob das für die Free-Tier-Persona
Lena ein reales Problem ist, hängt von der Content-Menge ab (heute 77 Karten
gesamt, siehe `docs/12-content-produktionsplan.md`) — bei 500 Zielkarten
wahrscheinlicher. Vorschlag: dieselbe 60-%-Regel wie im Planer optional auch
ohne aktiven Plan auf die Session-Länge anwenden, statt einen zweiten
Mechanismus zu bauen.

## 3. Fehlertaxonomie

### 3.1 Bestand: Was `gutachten.py` und `evaluator.py` heute unterscheiden

Beide Module erzeugen bereits benannte, stabile `code`-Strings
(`Finding.code` in `gutachten.py:198`, implizit über `PruefpunktResult.hit`
in `evaluator.py:61-68`). Das ist die faktische Fehlertaxonomie von heute —
Abschnitt 3.2 übersetzt sie in ein Enum und ergänzt, was für die Kernthese
„ein Fehler im Fall erzeugt eine Wiederholungskarte" fehlt.

### 3.2 Enum und Regeltabelle

```python
class GutachtenfehlerCode(StrEnum):
    # Kategorie A — Struktur/Technik (gutachten.py, themenübergreifend)
    KEIN_OBERSATZ = "kein_obersatz"
    SPRUNG_ZUM_ERGEBNIS = "sprung_zum_ergebnis"          # Subsumtionslücke
    OFFENER_OBERSATZ_MIT_SUBSTANZ = "offener_obersatz_leicht"
    OFFENER_OBERSATZ_OHNE_SUBSTANZ = "offener_obersatz_schwer"
    URTEILSSTIL = "urteilsstil"
    KEINE_DEFINITION = "keine_definition"
    KEINE_SUBSUMTION = "keine_subsumtion"
    KEIN_ERGEBNIS = "kein_ergebnis"
    KEINE_NORM = "keine_norm"
    GESETZ_FEHLT = "gesetz_fehlt"
    SCHACHTELSATZ = "schachtelsatz"                       # reiner Stilhinweis
    ZU_KURZ = "zu_kurz"                                   # Abbruch, kein Fachfehler

    # Kategorie B — Inhalt (evaluator.py, fallspezifisch, je Prüfpunkt)
    PRUEFPUNKT_VERFEHLT = "pruefpunkt_verfehlt"            # neu zu benennen
    PRUEFPUNKT_VERFEHLT_PFLICHT = "pruefpunkt_verfehlt_pflicht"  # neu zu benennen
    NORM_NICHT_GEPRUEFT = "norm_nicht_geprueft"            # erwartete Norm fehlt
    NORMZITAT_FALSCH = "normzitat_falsch"                  # geplant, siehe unten

    # Kategorie C — positiv (kein Fehler, aber Teil der Taxonomie)
    SAUBERER_AUFBAU = "sauberer_aufbau"
```

`OFFENER_OBERSATZ_MIT_SUBSTANZ`/`_OHNE_SUBSTANZ` und
`PRUEFPUNKT_VERFEHLT(_PFLICHT)` sind hier aufgespalten, obwohl der Code
heute denselben `Finding.code` bzw. gar keinen eigenen Code verwendet
(`gutachten.py:270-283,301-318`, `evaluator.py:196-201`) — die Fallunterscheidung
existiert bereits als Bedingung im Code, nur nicht als eigener Enum-Wert. Für
eine Regeltabelle mit unterschiedlicher Konsequenz muss sie einen eigenen
Wert haben.

| Code | Kategorie | Schweregrad | Konsequenz |
|---|---|---|---|
| `kein_obersatz` | A | Fehler, −40 Strukturpunkte | **Technik-Karte** (siehe unten), höchste Priorität — ohne Obersatz ist die Methode nicht erkennbar |
| `sprung_zum_ergebnis` | A | Fehler, −10 je Sprung (Deckel 20) | **Technik-Karte** „Subsumtion"; korreliert meist mit `pruefpunkt_verfehlt` am selben Prüfpunkt |
| `offener_obersatz_schwer` | A | Fehler, −12 je Fall (Deckel in `offener_obersatz`-Summe 24) | **Technik-Karte** „Prüfungspunkt abschließen" |
| `offener_obersatz_leicht` | A | Hinweis, −5 je Fall | Nur Textrückmeldung, keine Karte — der Punkt wurde inhaltlich bearbeitet |
| `urteilsstil` | A | Fehler, −8 je Fall (Deckel 30) | **Technik-Karte** „Gutachten- vs. Urteilsstil" — Kernhandwerk, hohe Priorität |
| `keine_definition` | A | Hinweis, −12 | Textrückmeldung; wird zur `pruefpunkt_verfehlt`-Karte, falls der fehlenden Definition ein Prüfpunkt zuzuordnen ist |
| `keine_subsumtion` | A | Fehler, −15 | wie `sprung_zum_ergebnis` |
| `kein_ergebnis` | A | Fehler, −12 | **Technik-Karte** „Ergebnissatz formulieren" |
| `keine_norm` | A | Fehler, −15 | Norm-Karten (`CardType.NORM`) des Themas vorziehen |
| `gesetz_fehlt` | A | Hinweis, −5 | Nur Textrückmeldung |
| `schachtelsatz` | A | Hinweis, bis −8 | Nur Textrückmeldung — reine Lesbarkeit, kein Fachfehler |
| `zu_kurz` | C | Hinweis, Score 0 | Keine Karte, Aufforderung zur erneuten Bearbeitung |
| `pruefpunkt_verfehlt` | B | — (fließt in Inhaltsquote) | **Fall-Karte(n)** über `Pruefpunkt.card_slug` (3.3) vorzeitig fällig setzen (`due = jetzt`), FSRS-Historie bleibt unangetastet |
| `pruefpunkt_verfehlt_pflicht` | B | Deckelt Gesamtpunktzahl auf 3.5 (`evaluator.py:206-208,326-327`) | wie oben, zusätzlich `state → relearning` auf den verlinkten Karten (härterer Reset, weil ein Kernpunkt fehlte) |
| `norm_nicht_geprueft` | B | Hinweis, bis −20 (`gutachten.py:437-449`) | Zugehörige Norm-Karte(n) vorziehen, wie `keine_norm` |
| `normzitat_falsch` | B | **geplant, heute nicht erkennbar** | s. u. |
| `sauberer_aufbau` | C | Lob, kein Punktabzug | Keine Karte; zählt positiv in die Wirksamkeitsmessung (Abschnitt 5) |

**`normzitat_falsch` ist absichtlich als „geplant" markiert.**
`extract_norms` (`gutachten.py:175-181`) erkennt nur, *dass* ein
Paragraph zitiert wird, nicht *ob* er zur Rechtslage passt — es gibt keinen
Abgleich gegen einen echten Normindex. Genau diese Lücke benennt bereits
`docs/03-roadmap.md` (Risikotabelle: „echter Normindex-Abgleich erst ab M2,
Norm-Explorer"). Ein Gutachten, das durchgängig § 985 statt § 433 zitiert,
fällt heute nur über `norm_nicht_geprueft` auf (erwartete Norm fehlt), nicht
als aktiv falsches Zitat — der Fehler wird also erkannt, aber mit der
falschen Kategorie und ohne die spezifischere Rückmeldung „das ist die
falsche Norm". Kein v1.0-Blocker, aber wichtig für die Erwartungshaltung an
die Taxonomie: sie ist vollständig für das, was heute technisch erkennbar
ist, nicht vollständig für alles, was ein Korrektor sehen würde.

### 3.3 Voraussetzung: Prüfpunkt → Karte verlinken

Die Konsequenzen „Fall-Karte" und „Fall-Karte (hart)" in 3.2 setzen voraus,
dass ein `Pruefpunkt` weiß, welche `Card`(s) das dort geprüfte Wissen
vermitteln. Das existiert heute nicht — `Pruefpunkt`
(`evaluator.py:48-57`) hat `id`, `label`, `weight`, `keywords`, `norms`,
`required`, aber kein `card_slug`. Ohne dieses Feld ist die im Ticket und in
`docs/01-produktvision.md` genannte Kernthese „ein Fehler im Fall erzeugt
eine Wiederholungskarte" nicht implementierbar — es gäbe keine Karte, die
erzeugt werden könnte.

**Vorschlag (klein, additiv, nicht in diesem Ticket umgesetzt):**

```python
@dataclass
class Pruefpunkt:
    id: str
    label: str
    weight: float = 1.0
    keywords: list[str] = field(default_factory=list)
    norms: list[str] = field(default_factory=list)
    required: bool = False
    card_slugs: list[str] = field(default_factory=list)  # NEU
```

Spiegelbildlich im YAML-Contentformat (`expectation.pruefpunkte[].card_slugs`)
und in der CI-Validierung (`content.py`): optionales Feld, das bei Fehlen
keine Karten-Konsequenz auslöst (Rückfall auf reine Textrückmeldung wie
heute) — kein Breaking Change für bestehende Fälle. Redaktionell güns­tig,
weil die Zuordnung „dieser Prüfpunkt gehört zu jenen Karten" meist schon beim
Schreiben des Falls im Kopf der Redaktion existiert (die Karten desselben
Themas sind ja die Wissensgrundlage des Falls); es fehlt nur das Feld, um es
aufzuschreiben.

**Nachtrag (SUB-261, 24.09.2026): Unabhängig vom LLM/AVV umsetzbar.**
Verifikation am Code zeigt, dass dieser Mechanismus nicht an den
`LLMEvaluator` gebunden ist, sondern an *jeden* Evaluator, der pro Prüfpunkt
ein `hit`/`miss` liefert — und genau das tut `HeuristicEvaluator.evaluate()`
bereits heute (`evaluator.py:159-235`, Stichwort-/Normabgleich, vollständig
offline). `get_evaluator()` liefert diesen heuristischen Evaluator immer dann,
wenn kein LLM konfiguriert ist oder keine Einwilligung vorliegt
(`evaluator.py:350-361`) — in v1.0 also grundsätzlich
(`llm_provider=none`). `submit_case` (`app/api/v1/gutachten.py:56-93`) ruft
ihn bei jeder Abgabe auf. Die für Punkt 7 in Abschnitt 6 benötigten
`PruefpunktResult(hit=False)`-Ereignisse entstehen damit schon ohne LLM-Aufruf
und ohne AVV — schwächer in der Trefferquote (Stichwortabgleich statt
Verständnis), aber funktionsfähig. Die bisherige Einordnung in
`docs/16-innovationsthesen.md`, Abschnitt 2 („v1.1-Umsetzung, sobald die
KI-Korrektur aktiviert wird") war daher in der Begründung falsch; korrigiert
dort im Nachtrag zu Punkt 2.

Für die generischen **Technik-Karten** (Kategorie A) reicht `card_slugs`
nicht, weil diese Fehler nicht an ein Thema, sondern an die
Gutachtentechnik allgemein gebunden sind. Zwei Optionen:

1. **Bevorzugt:** eigener, themenübergreifender Inhaltsblock (z. B.
   `content/technik/gutachtenstil.yaml`) mit Karten wie „Woran erkenne ich
   Urteilsstil?" — erfordert einen vierten Wert im `Area`-Enum
   (`models.py:33-38`, durchgesetzt über `VALID_AREAS` in
   `content.py:25`), z. B. `UEBERGREIFEND`. Kleine, saubere Erweiterung,
   aber ein Enum-Wert, der außerhalb der drei examensrelevanten
   Rechtsgebiete liegt — redaktionell und für die Coverage-Anzeige gesondert
   zu behandeln (Technik-Karten sollten nicht in `weighted_coverage`
   einfließen, sonst verwässern sie die Rechtsgebiets-Gewichtung).
2. **Pragmatischer Zwischenschritt:** Technik-Fehler zunächst nur als
   Textrückmeldung ausliefern (Status quo) und erst mit Option 1 nachziehen,
   sobald T3 Kapazität für einen weiteren Inhaltsblock hat.

Empfehlung: Option 2 für v1.0, Option 1 als Folgeticket nach Gate B.

## 4. Kalibrierungsplan

### 4.1 Ziel und Geltungsbereich

Ziel aus M3 (`docs/03-roadmap.md:164`): **30 von Dozenten bewertete
Referenzgutachten, MAE ≤ 2 Punkte** (JAP-Skala 0–18,
`evaluator.py:30-38`). Die Kalibrierung bezieht sich ausschließlich auf den
`LLMEvaluator` — der `HeuristicEvaluator` ist mit `HEURISTIK_MAX_PUNKTE = 11`
strukturell auf höchstens „gut" gedeckelt (Abschnitt 1.3) und damit gegen die
volle Skala gar nicht kalibrierbar; das ist gewolltes Produktdesign, kein
Kalibrierungsziel.

### 4.2 Auswahl der Referenzgutachten

30 Gutachten, stratifiziert wie schon in
`docs/12-content-produktionsplan.md` Abschnitt 4.2 für die Content-Stichprobe
vorgemacht — nicht zufällig, sondern nach zwei Kriterien gleichzeitig
gezogen, damit ein systematischer Fehler in einer Dimension nicht
untergeht:

- **Rechtsgebiet:** je 10 aus Zivilrecht, Strafrecht, Öffentlichem Recht.
- **Qualitätsstufe:** je Rechtsgebiet mindestens je 2–3 Gutachten in „schwach"
  (viele der in Abschnitt 3 gelisteten Fehler), „mittel" und „stark"
  (nah am Erwartungshorizont). Eine Stichprobe, die nur mittelmäßige
  Gutachten enthält, kann eine niedrige MAE zeigen, obwohl das System an den
  Rändern der Skala (sehr gut/mangelhaft) systematisch danebenliegt — genau
  dort, wo Fehlbewertungen für Nutzer am schmerzhaftesten sind.

**Woher kommen die Texte?** Vor Launch gibt es keine echten
Nutzer-Gutachten (`submissions` ist zu Kalibrierungszeitpunkt leer oder fast
leer). Zwei Quellen, beide nötig:

1. **Redaktionell verfasste Referenzgutachten** in allen drei
   Qualitätsstufen, gezielt so geschrieben, dass sie bekannte
   Taxonomie-Fehler aus Abschnitt 3 enthalten (z. B. ein Gutachten mit
   bewusstem Urteilsstil, eines mit fehlendem Pflicht-Prüfpunkt) — das macht
   die Kalibrierung zum direkten Test der Taxonomie, nicht nur der
   Gesamtpunktzahl.
2. **Opt-in-Beta-Gutachten**, sobald T7 die geschlossene Beta mit zwei
   Fachschaften startet (`docs/03-roadmap.md:76`) — mit expliziter
   Einwilligung nach `docs/06-recht-compliance.md` Abschnitt 3
   („Einwilligung für optionale Telemetrie und KI-Training"). Diese Quelle
   ist realistischer, aber zeitlich später verfügbar als Quelle 1 und daher
   nicht der Startpunkt.

### 4.3 Bewertungsbogen und Verfahren

Doppelkorrektur pro Gutachten (zwei unabhängige Dozenten/Korrektoren, blind
gegenüber der Systembewertung), analog zur Zweitkorrektur im echten
Staatsexamen:

- Gesamtpunktzahl 0–18, halbe Punkte zulässig (deckt sich mit
  `round(... * 2) / 2` im Code, `evaluator.py:205,325`).
- Pro Prüfpunkt des Erwartungshorizonts: getroffen/nicht getroffen (ja/nein),
  gespiegelt an `PruefpunktResult.hit` — macht die menschliche Bewertung
  strukturell vergleichbar mit der Systemausgabe, nicht nur die Endnote.
- Freitextfeld für Auffälligkeiten, die der Erwartungshorizont nicht abdeckt
  (Hinweis auf blinde Flecken im Prüfpunktkatalog selbst).
- Weichen beide Korrektoren um mehr als 3 Punkte voneinander ab: dritter
  Korrektor entscheidet (Stichentscheid), wie im echten Prüfungsverfahren.

**Nebenprodukt, wichtig für die Ehrlichkeit der Zielmetrik:** Die
Inter-Rater-Differenz der beiden menschlichen Korrektoren wird mitgemessen.
Liegt sie selbst im Mittel über 2 Punkten, ist „MAE ≤ 2 gegen die
Dozentennote" ein Ziel, das die Dozenten selbst untereinander nicht
erreichen — das relativiert (nicht ersetzt) das Kriterium und gehört in die
Auswertung, nicht unter den Tisch.

### 4.4 Auswertung

```
MAE = mean(|system_points_i − human_points_i|)  für i = 1..30
```

`human_points_i` = Mittelwert der (ggf. per Stichentscheid ergänzten) zwei
Korrektoren. Zusätzlich, um Fehlerursachen von Fehlerausmaß zu trennen:

- MAE getrennt je Rechtsgebiet und je Qualitätsstufe (Abschnitt 4.2) —
  zeigt, ob das Problem gleichmäßig verteilt ist oder an einem Rechtsgebiet
  hängt (denkbar: LLM kennt Zivilrecht besser als Öffentliches Recht).
  
- **Richtung** des Fehlers (System zu streng vs. zu milde), nicht nur Betrag
  — eine MAE von 2,0 kann aus „immer 2 Punkte zu milde" oder aus „zufällig
  gestreut" entstehen; nur Ersteres ist ein Bias-Problem mit klarer
  Korrekturrichtung.
- Abweichung je Prüfpunkt-Treffer/Verfehlung getrennt von der
  Gesamtpunktzahl — zeigt, ob das Problem in der Prüfpunkterkennung (Content)
  oder in der Punkteumrechnung (Formel `0.72/0.28`) liegt.

### 4.5 Was bei Verfehlen passiert

Wenn MAE > 2 nach Abschnitt 4.4:

1. **Root-Cause statt Rateraten:** anhand der Aufschlüsselung aus 4.4 gezielt
   nachsteuern — Prompt in `LLMEvaluator._build_prompt`
   (`evaluator.py:259-280`) präzisieren, wenn die Prüfpunkterkennung
   abweicht; die Gewichtung `0.72/0.28` anpassen, wenn Struktur- und
   Inhaltsanteil systematisch verzerrt wirken.
2. **Nachmessen, nicht neu raten.** Nach jeder Prompt-/Gewichtsänderung
   erneuter Durchlauf gegen denselben 30er-Satz (kein neues Sample — sonst
   ist nicht vergleichbar, ob sich etwas verbessert hat).
3. **Bleibt MAE > 2 nach realistischem Nachsteuern:** Notlösung aus der
   Risikotabelle in `docs/03-roadmap.md:196` — Deckelung beibehalten und
   offen kommunizieren. Konkret: dem `LLMEvaluator` denselben
   Deckelungs-Mechanismus geben, den der `HeuristicEvaluator` bereits hat
   (`HEURISTIK_MAX_PUNKTE`, `evaluator.py:146-147`), z. B.
   `LLM_MAX_PUNKTE_UNKALIBRIERT`, bis die Kalibrierung nachträglich besteht.
   Das ist ehrlicher als ein unkalibriertes 0–18-Ergebnis mit falscher
   Genauigkeitssuggestion auszuliefern — direkte Umsetzung von Leitprinzip 4.
   **Änderungsbedarf**, nicht in diesem Ticket umgesetzt: dieser
   Deckel-Parameter existiert im Code heute nicht.
4. Gate B (`docs/03-roadmap.md:69-70`) gilt erst als erreicht, wenn MAE ≤ 2
   **ohne** Deckelungs-Notlösung nachgewiesen ist — die Notlösung ist ein
   Weg, trotzdem ehrlich zu launchen, kein Weg, das Gate zu erfüllen.

### 4.6 Fallback ohne Dozentenzugang

Das ist laut `docs/03-roadmap.md:87-89,196` der härteste externe
Abhängigkeitspunkt der gesamten Roadmap. Fallback, falls keine
Lehrstuhl-Dozenten gewinnbar sind (Zeitmangel, fehlendes Interesse, kein
Kontakt):

1. **Erfahrene Korrekturassistenten/wissenschaftliche Mitarbeiter** mit
   nachweisbarer Klausurkorrekturerfahrung im Zweiten Staatsexamen oder in
   der universitären Übungsklausur-Korrektur — bereits als Fallback in der
   Roadmap-Risikotabelle benannt. Rekrutierung über Fachschaften, jur.
   Repetitorien-Netzwerke, oder gezielte Ansprache über die ohnehin für T7
   geplanten Fachschafts-Kontakte (`docs/03-roadmap.md:76`).
2. **Honorar statt Gefallen.** Ein bezahlter Kalibrierungsauftrag (30
   Gutachten à ~15–20 Minuten Korrekturzeit) ist verlässlicher terminierbar
   als eine unbezahlte Bitte an Dozenten und senkt zugleich die Abhängigkeit
   von deren Wohlwollen.
3. **Transparenz als Bedingung, nicht als Kür.** Wird mit dem Fallback
   kalibriert, darf das Produkt nicht mit „dozentengeprüft" werben — die
   Herkunft der Referenzbewertung gehört im Zweifel offen kommuniziert
   (Leitprinzip 4, Anschluss an `docs/06-recht-compliance.md` Abschnitt 5
   zu Werbeaussagen).
4. **Wenn auch das scheitert:** die 30 Referenzgutachten ausschließlich
   redaktionell mit dokumentierter, mehrköpfiger interner Prüfung bewerten
   (mindestens zwei Personen aus der juristischen Fachredaktion, gleiches
   Doppelkorrektur-Verfahren wie 4.3) — schwächere externe Validität, aber
   besser als gar keine Kalibrierung. In diesem Fall bleibt die
   Punktedeckelung aus 4.5 Schritt 3 **dauerhaft** aktiv, nicht nur bis zur
   nächsten Nachmessung, weil ohne externe Referenz keine belastbare
   Aussage über die tatsächliche MAE gegenüber echten Korrektoren möglich
   ist.

### 4.7 Kadenz

Kalibrierung ist kein einmaliges Gate-Ereignis. Auslöser für eine erneute
Prüfung:

- **Jede Änderung an `_build_prompt`, an `settings.llm_model` oder an der
  Gewichtungsformel** (`evaluator.py:204,324`): voller Durchlauf gegen den
  bestehenden 30er-Satz (Abschnitt 4.5 Punkt 2).
- **Laufender Drift-Check ohne Anlass:** alle ~3 Monate ein kleines
  Stichproben-Update (10 neue Gutachten statt 30), um Modell-Drift durch
  Provider-seitige Updates am LLM zu erkennen, ohne jedes Mal den vollen
  Aufwand zu treiben.
- **Content-Wachstum:** sobald neue Rechtsgebiets-Themen mit substanziell
  anderer Fallstruktur hinzukommen (z. B. Öffentliches Recht wächst laut
  `docs/12-content-produktionsplan.md` am stärksten), eigene Mini-Stichprobe
  für das neue Gebiet, falls die bestehenden 30 es unterrepräsentieren.

## 5. Wirksamkeitsmessung

Leitprinzip 4 verlangt „lieber 62 % sicher als Konfetti" — eine Metrik, die
zeigen *kann*, dass Subsumo nicht wirkt, nicht nur eine, die gut aussieht.
Zwei Metriken, beide aus vorhandenen Tabellen berechenbar, keine neue
Telemetrie nötig:

### 5.1 Metrik 1 (Minimalanforderung): FSRS-Retentionslücke

Der Scheduler plant Wiederholungen so, dass die Erinnerungswahrscheinlichkeit
beim Fälligkeitszeitpunkt der Ziel-Retention entspricht
(`DESIRED_RETENTION_BY_TYPE`, z. B. 0.92 für Definitionen,
`srs.py:41-48`). Das ist eine **Prognose**, keine Messung — die
`DEFAULT_WEIGHTS` sind generische FSRS-4.5-Standardgewichte, nicht auf
Subsumo-Nutzer trainiert (Kommentar `srs.py:24-25`: „später pro Nutzer aus
dem eigenen Review-Verlauf optimierbar").

**Metrik:** Für jede Karte, die zu ihrem `due`-Zeitpunkt bewertet wird
(`Review.rating`, verknüpft über `Review.card_id → Card.type`), berechne den
Anteil `AGAIN`-Bewertungen je `card.type`. Vergleiche das mit
`1 − DESIRED_RETENTION_BY_TYPE[type]` (für `definition`: prognostizierte
Vergessensrate 8 %). Liegt die tatsächliche `AGAIN`-Quote systematisch
darüber, hält das Gedächtnismodell nicht, was die Coverage-Zahl (Abschnitt
1.2) unterstellt — reife Karten wären dann nicht wirklich „ein Semester
lang sicher im Gedächtnis", wie es der `MATURE_STABILITY_DAYS`-Schwellenwert
verspricht.

Berechnung ist eine reine Analytics-Abfrage über `reviews` + `cards`, kein
Schema-Zusatz nötig. Sinnvoll ab einer Mindestmenge Reviews je Kartentyp
(z. B. n ≥ 200), sonst zu verrauscht für eine Aussage.

### 5.2 Metrik 2: Punkteentwicklung über wiederholte Fälle

`submissions` erlaubt mehrere Abgaben derselben `case_id` durch denselben
Nutzer (kein Unique-Constraint, `models.py:181-195`). Für alle
`(user_id, case_id)`-Paare mit ≥ 2 Abgaben: Trend von `points` über die
Versuche (z. B. Steigung einer linearen Regression über die
Abgabereihenfolge, oder simpler: Differenz letzter minus erster Versuch).

Ein im Mittel positiver Trend ist der direkteste verfügbare Beleg, dass
wiederholtes Üben mit Feedback tatsächlich zu besseren Gutachten führt — nicht
nur zu höherer Kartenreife. Ergänzt Metrik 1 (Wissen hält) um die
Anwendungsdimension aus Abschnitt 1.1.

### 5.3 Leitplanke gegen Selbsttäuschung

Beide Metriken lassen sich technisch schönrechnen, wenn man sie unkritisch
nimmt — das widerspricht Leitprinzip 4, also:

- **Near-Duplicate-Filter für Metrik 2.** Ein Nutzer, der denselben Text mit
  Mikro-Änderungen mehrfach einreicht, um die Punktzahl hochzugrinden,
  darf nicht als „hat gelernt" gezählt werden. Einfacher Textähnlichkeits-
  Schwellenwert (z. B. Levenshtein-Quote) zwischen aufeinanderfolgenden
  Abgaben desselben Falls; auffällig ähnliche Paare aus der Trendberechnung
  ausschließen.
- **Beide Metriken werden nicht automatisch in die Coverage-Zahl
  eingerechnet.** Sie sind Diagnoseinstrumente für die Redaktion/Produkt-
  seite (z. B. Dashboard „Kalibrierungsstatus"), keine Nutzer-facing Kennzahl
  — bis Abschnitt 1.2 Option 2 (Coverage-Formel-Erweiterung) tatsächlich
  umgesetzt ist. Eine unfertige Metrik direkt im Nutzerinterface zu zeigen,
  wäre der in Leitprinzip 4 explizit abgelehnte Fall einer Zahl ohne
  tragfähige Definition dahinter.
- **Retentionslücke bei starker Abweichung nach oben ist ein Rückwärtsgang
  für die Coverage-Zahl, nicht nur ein Datenpunkt.** Zeigt Metrik 1 über
  mehrere Auswertungszeiträume konsistent eine deutlich höhere
  `AGAIN`-Quote als prognostiziert, ist das ein Signal, `MATURE_STABILITY_DAYS`
  oder die `DESIRED_RETENTION_BY_TYPE`-Werte nachzuschärfen — nicht, die
  Metrik zu ignorieren, weil sie unbequem ist.

## 6. Zusammenfassung: offene Änderungsbedarfe

| # | Änderungsbedarf | Betrifft | Abschnitt | Vor v1.0 nötig? |
|---|---|---|---|---|
| 1 | Coverage-Label präzisieren („Karten-Reife" statt „Coverage/Können") | UI-Text | 1.2 | Empfohlen, klein |
| 2 | Coverage-Formel um Anwendungsdimension erweitern | `learn.py`, Datenmodell | 1.2 | Nein, nach T5 |
| 3 | Onboarding mit Semester-/Themenauswahl für Lena | Neu (Backend + Client) | 2.1 | Für sauberen Tag-1-Pfad ja |
| 4 | Fall-Freischaltschwelle je Thema (`cards_started`-basiert) | `learn.py`/Client | 2.1 | Nein, Komfortfeature |
| 5 | Rückstands-Kappung auch ohne aktiven Plan | `learn.py` | 2.4 | Ab wachsendem Kartenbestand |
| 6 | Phasenberechnung relativ zum ursprünglichen Vorbereitungsbeginn statt zum Neuberechnungszeitpunkt | `planner.py` | 2.3 | Vor M4-Ausbau |
| 7 | `Pruefpunkt.card_slugs` (Prüfpunkt → Karte) | `evaluator.py`, Contentformat, `content.py` | 3.3 | Nein — aber AVV-unabhängig umsetzbar (SUB-261, 24.09.2026); Voraussetzung für die Kernthese, geplant nach v1.0-Freeze |
| 8 | Technik-Karten-Block + `Area.UEBERGREIFEND` | Contentformat, `models.py`, `content.py` | 3.3 | Nein, Folgeticket nach Gate B |
| 9 | `normzitat_falsch` erkennbar machen | `gutachten.py`, wartet auf Norm-Explorer | 3.2 | Nein, an M2 gekoppelt |
| 10 | Deckelungs-Parameter für `LLMEvaluator` bei nicht bestandener Kalibrierung | `evaluator.py` | 4.5 | Ja, falls MAE-Ziel verfehlt wird |

## Quellen

- `backend/app/services/srs.py`, `planner.py`, `evaluator.py`,
  `gutachten.py`, `backend/app/models.py`, `backend/app/api/v1/learn.py`,
  `plan.py`, `gutachten.py` (API), `backend/app/schemas.py`
- `content/zivilrecht/bgb-at-kaufrecht.yaml` (Struktur eines Themas mit
  Karten, Schema, Fall, Erwartungshorizont)
- `docs/01-produktvision.md` (Personas, Leitprinzipien, Verzahnungsthese)
- `docs/03-roadmap.md` (M3-Kalibrierungsziel, Release-Gates, Risikotabelle)
- `docs/04-datenmodell.md`, `docs/06-recht-compliance.md`
- `docs/12-content-produktionsplan.md` (Stichproben-Methodik als Vorbild für
  Abschnitt 4.2, Themenprioritäten P1–P3 für Abschnitt 2.1)
- [Release-Roadmap Subsumo v1.0](/SUB/issues/SUB-39#document-plan) (Spur T4,
  Gate B/C)
