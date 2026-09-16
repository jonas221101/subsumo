# Kalibrierungspaket: 30 Dozentengutachten

Löst [SUB-130](/SUB/issues/SUB-130), Vorlauf zu Gate B
(`docs/13-lernarchitektur.md` Abschnitt 4, `docs/03-roadmap.md` M3). Bezug:
`docs/18-release-2-wochen.md` Abschnitt 3.2 — die KI-Klausurkorrektur mit
Punkten ist aus v1.0 gestrichen, weil zwei Vorbedingungen fehlen: der AVV mit
dem LLM-Provider ([SUB-129](/SUB/issues/SUB-129), echtes Gate, blockt jede
LLM-Variante) und die Kalibrierung gegen 30 Dozentengutachten (dieses
Dokument, bindet nur die *bewertende* Variante). Reihenfolge: AVV zuerst,
diese Vorbereitung läuft parallel.

**Status dieses Dokuments: Vorbereitungspaket, kein Versand.** Es wurde keine
externe Person kontaktiert, keine Vergütung zugesagt. Das Anschreiben in
Abschnitt 4 ist ein Entwurf. Beschaffung der Dozenten/Korrektoren selbst ist
Nutzersache (siehe Auftrag).

## 1. Stichprobe (30 Positionen)

Stratifiziert wie in `docs/13-lernarchitektur.md` Abschnitt 4.2 verlangt: je
10 aus Zivilrecht, Strafrecht, Öffentlichem Recht, je Rechtsgebiet mindestens
2–3 Positionen je Qualitätsstufe (schwach/mittel/stark). Grundlage ist der
vorhandene Fallbestand in `content/<gebiet>/*.yaml` auf `origin/main`
(Stand dieses Pakets: 34 veröffentlichte Fälle — 13 Zivilrecht, 9 Strafrecht,
12 Öffentliches Recht — geprüft per Skript gegen `faelle[].expectation`).

**Wichtig zur Einordnung der Qualitätsstufe:** Sie bezieht sich auf den noch
zu verfassenden *Gutachtentext* (Abschnitt 4.2 Quelle 1: "redaktionell
verfasste Referenzgutachten ... gezielt so geschrieben, dass sie bekannte
Taxonomie-Fehler enthalten"), nicht auf den zugrunde liegenden Fall. Jeder
ausgewählte Fall liefert Sachverhalt + Erwartungshorizont; die eigentliche
Bearbeitung (schwach/mittel/stark) muss die Redaktion für die Kalibrierung
erst schreiben — das ist nicht Teil dieses Pakets, sondern die Aufgabe, die
dieses Paket vorbereitet. Die Taxonomie-Codes aus `docs/13` Abschnitt 3.2
(`kein_obersatz`, `urteilsstil`, `sprung_zum_ergebnis`,
`pruefpunkt_verfehlt(_pflicht)` usw.) sind die Zielfehler für die
"schwach"-Stufe; "stark" sollte nah am Erwartungshorizont liegen, aber keine
wörtliche Kopie der `steps[].erwartung`-Texte sein (sonst testet die
Kalibrierung nur Wiedererkennung, nicht Bewertung).

### 1.1 Zivilrecht (10 von 13, 3 in Reserve)

| # | Fall-Slug | Datei | Zielstufe | Erwartungshorizont |
|---|---|---|---|---|
| 1 | `zr-fall-sonderpreis` | `content/zivilrecht/bgb-at-kaufrecht.yaml` | schwach | vorhanden (6 Prüfpunkte) |
| 2 | `zr-fall-zahlendreher-kaufangebot` | `content/zivilrecht/zr-at-anfechtung.yaml` | schwach | vorhanden (6) |
| 3 | `zr-fall-verwechseltes-fahrradmodell` | `content/zivilrecht/zr-at-auslegung.yaml` | schwach | vorhanden (5) |
| 4 | `zr-fall-anscheinsvollmacht` | `content/zivilrecht/zr-at-stellvertretung.yaml` | mittel | vorhanden (6) |
| 5 | `zr-fall-doppelt-bezahlte-werklohnrechnung` | `content/zivilrecht/zr-bereicherungsrecht-leistungskondiktion.yaml` | mittel | vorhanden (7) |
| 6 | `zr-fall-radfahrer-rotlicht` | `content/zivilrecht/zr-deliktsrecht-823.yaml` | mittel | vorhanden (8) |
| 7 | `zr-fall-zurueckgedrehter-tachometer` | `content/zivilrecht/zr-kaufrecht-maengelgewaehrleistung.yaml` | mittel | vorhanden (7) |
| 8 | `zr-fall-verspaetete-rueckgabe-985` | `content/zivilrecht/zr-sachenrecht-eigentumsherausgabe-985.yaml` | stark | vorhanden (6) |
| 9 | `zr-fall-moebelhaus-haftungsausschluss` | `content/zivilrecht/zr-schuldrecht-at-agb-kontrolle.yaml` | stark | vorhanden (6) |
| 10 | `zr-fall-zerstoertes-motorrad` | `content/zivilrecht/zr-schuldrecht-at-unmoeglichkeit.yaml` | stark | vorhanden (7) |

Reserve (nicht gezogen, bei Bedarf Tausch 1:1 gegen eine der zehn Positionen
oben, z. B. falls die Redaktion für einen der Fälle keine überzeugende
Fehl-Bearbeitung konstruieren kann): `zr-fall-oldtimer-onkel-votv`
(`zr-at-vertreter-ohne-vertretungsmacht.yaml`),
`zr-fall-gebrauchtwagen-vorschaden` (`zr-schuldrecht-at-cic.yaml`),
`zr-fall-haustuer-fixgeschaeft` (`zr-schuldrecht-at-ruecktritt.yaml`).

### 1.2 Strafrecht (9 von 9 — Lücke: 1 Position)

| # | Fall-Slug | Datei | Zielstufe | Erwartungshorizont |
|---|---|---|---|---|
| 11 | `sr-fall-gebrauchter-laptop` | `content/strafrecht/sr-bt-betrug.yaml` | schwach | vorhanden (7) |
| 12 | `sr-fall-parfuemflasche` | `content/strafrecht/sr-bt-diebstahl.yaml` | schwach | vorhanden (7) |
| 13 | `sr-fall-gartenzaunstreit` | `content/strafrecht/sr-notwehr-32.yaml` | schwach | vorhanden (5) |
| 14 | `sr-fall-stiefeltritt-zu-zweit` | `content/strafrecht/sr-bt-koerperverletzung-224.yaml` | mittel | vorhanden (6) |
| 15 | `sr-fall-tankstellenueberfall` | `content/strafrecht/sr-bt-raub.yaml` | mittel | vorhanden (7) |
| 16 | `sr-fall-nachtschicht-wachmann` | `content/strafrecht/sr-bt-toetungsdelikte-211-212.yaml` | mittel | vorhanden (6) |
| 17 | `sr-fall-notwehr-schlagstock` **(Zweitgutachten a)** | `content/strafrecht/strafrecht-at.yaml` | mittel | vorhanden (8) |
| 18 | `sr-fall-schmiere-stehen` | `content/strafrecht/sr-taeterschaft-teilnahme-25.yaml` | stark | vorhanden (6) |
| 19 | `sr-fall-messerstich-ruecktritt` | `content/strafrecht/sr-versuch-ruecktritt.yaml` | stark | vorhanden (6) |
| 20 | `sr-fall-notwehr-schlagstock` **(Zweitgutachten b)** | `content/strafrecht/strafrecht-at.yaml` | stark | vorhanden (8) |

**Benannte Lücke:** Strafrecht hat nur 9 distinkte veröffentlichte Fälle statt
der für eine sauber distinkte 10er-Stichprobe nötigen Anzahl — das ist keine
fehlende Erwartungshorizont-Lücke (alle 9 sind vollständig), sondern eine
Fallbestands-Lücke. Position 20 füllt sie durch ein zweites,
qualitätsverschiedenes Referenzgutachten zum selben Fall
(`sr-fall-notwehr-schlagstock`, dem Fall mit dem reichsten
Erwartungshorizont, 8 Prüfpunkte, daher am ehesten geeignet für zwei klar
unterscheidbare Bearbeitungsqualitäten). Nachteil: reduzierte
Fall-Diversität in Strafrecht (9 statt 10 unterschiedliche Sachverhalte).
Zwei Wege, das aufzulösen — Entscheidung liegt beim Nutzer/Board, nicht bei
diesem Paket:

- **Sofort starten (empfohlen):** Position 20 wie oben, mit dem Vermerk in
  der späteren Auswertung, dass Strafrecht einen Fall doppelt nutzt. Deckt
  sich mit der "Start sofort"-Vorgabe aus `docs/18-release-2-wochen.md`
  Abschnitt 3.2.
- **Warten auf Content-Wachstum:** ein zehntes Strafrecht-Thema aus einem
  Folge-Batch (Fortsetzung von SUB-55/SUB-93) abwarten, dann Position 20
  gegen einen echten neuen Fall tauschen. Sauberer, aber verzögert den Start
  entgegen der Roadmap-Vorgabe. Ohnehin vorgesehen als Routine-Update nach
  `docs/13` Abschnitt 4.7 ("Content-Wachstum ... eigene Mini-Stichprobe für
  das neue Gebiet").

### 1.3 Öffentliches Recht (10 von 12, 2 in Reserve)

| # | Fall-Slug | Datei | Zielstufe | Erwartungshorizont |
|---|---|---|---|---|
| 21 | `or-fall-versammlungsauflage` | `content/oeffentliches-recht/grundrechte.yaml` | schwach | vorhanden (8) |
| 22 | `or-fall-baeckerei-bedarfspruefung` | `content/oeffentliches-recht/or-berufsfreiheit.yaml` | schwach | vorhanden (6) |
| 23 | `or-fall-versaeumter-anhoerungstermin` | `content/oeffentliches-recht/or-va-rechtmaessigkeitspruefung.yaml` | schwach | vorhanden (5) |
| 24 | `or-fall-naechtlicher-tretroller` | `content/oeffentliches-recht/or-allgemeine-handlungsfreiheit.yaml` | mittel | vorhanden (6) |
| 25 | `or-fall-strassenbau-enteignung-ohne-entschaedigungsregelung` | `content/oeffentliches-recht/or-eigentumsgarantie.yaml` | mittel | vorhanden (4) |
| 26 | `or-fall-satireplakat` | `content/oeffentliches-recht/or-meinungsfreiheit.yaml` | mittel | vorhanden (6) |
| 27 | `or-fall-gewerbeuntersagung-anfechtung` | `content/oeffentliches-recht/or-vwgo-anfechtungsklage.yaml` | mittel | vorhanden (5) |
| 28 | `or-fall-studiengebuehrenbefreiung-beamteneltern` | `content/oeffentliches-recht/or-gleichheitssatz.yaml` | stark | vorhanden (4) |
| 29 | `or-fall-baugenehmigung-untaetigkeitsklage` | `content/oeffentliches-recht/or-vwgo-verpflichtungsklage.yaml` | stark | vorhanden (5) |
| 30 | `or-fall-gewerbeuntersagung-sofortvollzug` | `content/oeffentliches-recht/or-vwgo-vorlaeufiger-rechtsschutz.yaml` | stark | vorhanden (5) |

Reserve: `or-fall-einsturzgefaehrdeter-balkon-ermessensreduzierung`
(`or-vwvfg-ermessen-beurteilungsspielraum.yaml`),
`or-fall-duldungsverfuegung-vermessung` (`or-vwvfg-verwaltungsakt.yaml`).

**Ergebnis:** 30 Positionen, alle mit vorhandenem Erwartungshorizont. Die
einzige benannte Lücke ist die Strafrecht-Fallzahl (1.2), keine fehlt beim
Erwartungshorizont selbst.

## 2. Bewertungsbogen

### 2.1 Zielformat: was der SUB-69-Harness tatsächlich einliest

Geprüft gegen den Code, nicht behauptet:

- Eingabeformat dokumentiert in `backend/scripts/kalibrierung_cli.py:13-25`
  (Docstring: YAML mit Liste `faelle`, je Fall `slug`, `gutachten`
  (Volltext), `expectation.pruefpunkte` (gleiches Format wie
  `content.py`/`parse_expectation()`), `punkte` (0–18)).
- Durchgesetzt in `load_cases()`,
  `backend/scripts/kalibrierung_cli.py:74-127`: ein Fall ohne nicht-leeren
  `gutachten`-Text (Zeile 100–103), ohne
  `expectation.pruefpunkte` (Zeile 105–111) oder ohne numerische `punkte`
  im Bereich `[0, 18]` (Zeile 113–119) wird als Einzelfehler markiert und
  nicht ausgewertet — der Lauf bricht deswegen nicht ab, aber der Fall zählt
  nicht in die MAE. Konkretes Beispiel für ein gültiges Format:
  `backend/tests/fixtures/kalibrierung_beispiel.yaml`.
- `CalibrationCase`/`CalibrationResult`
  (`backend/scripts/kalibrierung_cli.py:52-71`) speichern nur `slug`,
  `gutachten`, `expectation`, `punkte` bzw. `predicted`/`actual` — **keine**
  Felder für zwei Korrektoren, für Prüfpunkt-Treffer/-Verfehlung oder für
  Freitext. `run_calibration()` (Zeile 130-152) ruft zwar
  `evaluator.evaluate(...)` auf, das laut
  `backend/app/services/evaluator.py:60-76`
  (`PruefpunktResult.hit` Zeile 65, `Evaluation.checkpoints` Zeile 76) pro Prüfpunkt ein
  Treffer/Verfehlung-Ergebnis liefert — aber `run_calibration()` verwirft
  `evaluation.checkpoints` und behält nur `evaluation.points`
  (`kalibrierung_cli.py:149-151`).

**Folge für dieses Paket:** Der Bewertungsbogen muss zwei Ebenen haben — eine
reiche Rohdaten-Ebene (Abschnitt 2.2, für Doppelkorrektur, Prüfpunkt-Diff und
Freitext nach `docs/13` Abschnitt 4.3/4.4) und eine schlanke, aggregierte
Ausgabe-Ebene im exakten Harness-Format (Abschnitt 2.3). Nur Letztere kann
`kalibrierung_cli.py run --input ...` direkt einlesen.

**Beobachtung, kein Auftrag an dieses Paket:** Die in `docs/13` Abschnitt 4.4
geforderte Auswertung "Abweichung je Prüfpunkt-Treffer/-Verfehlung getrennt
von der Gesamtpunktzahl" ist mit dem heutigen Harness-Code nicht automatisch
erzeugbar, weil `run_calibration()` die pro-Fall `checkpoints` verwirft. Wer
den eigentlichen Kalibrierungslauf durchführt, braucht entweder eine kleine
Erweiterung von `CalibrationResult` um `checkpoints: list[PruefpunktResult]`
(additiv, kein Format-Bruch) oder muss die Auswertung von Hand aus einem
separaten `evaluator.evaluate()`-Aufruf ziehen. Das ist Entwickler-Arbeit
(`norm_gate.py`/`pipeline.py`-Nachbarschaft, nicht in meiner Rolle) — als
Beobachtung hier festgehalten, damit sie nicht erst beim Auswerten auffällt.

### 2.2 Rohdaten-Bogen (pro Korrektor, pro Gutachten)

Ein Bogen pro Korrektor und Fall — Korrektoren sehen einander nicht, sehen
keine Systembewertung ("blind" nach `docs/13` Abschnitt 4.3). Vorschlag als
Tabellenkopf (CSV oder Formular, Werkzeugwahl offen):

```
position,fall_slug,korrektor_id,gesamtpunkte,pruefpunkt_id,pruefpunkt_getroffen,freitext,datum
21,or-fall-versammlungsauflage,K1,9.5,p1,ja,,2026-09-20
21,or-fall-versammlungsauflage,K1,9.5,p2,nein,"Erwartungshorizont deckt Fallgruppe X nicht ab",2026-09-20
...
```

Felder:

- `position` / `fall_slug`: Bezug auf Abschnitt 1.
- `korrektor_id`: Pseudonym (K1/K2/K3), keine Klarnamen in der Datenzeile —
  Zuordnung Name↔Kürzel getrennt verwaltet (Datenminimierung,
  `docs/06-recht-compliance.md` Abschnitt 3).
- `gesamtpunkte`: 0–18, halbe Punkte zulässig — deckt sich mit
  `round(... * 2) / 2` in `evaluator.py:205,325`.
- `pruefpunkt_id` / `pruefpunkt_getroffen`: eine Zeile je Prüfpunkt aus
  `expectation.pruefpunkte[].id` des jeweiligen Falls, gespiegelt an
  `PruefpunktResult.hit`.
- `freitext`: Auffälligkeiten, die der Erwartungshorizont nicht abdeckt
  (Hinweis auf blinde Flecken im Prüfpunktkatalog, `docs/13` 4.3).

### 2.3 Aggregation → Harness-Eingabedatei

Aus je zwei (ggf. drei) Rohdaten-Bögen pro Fall wird eine Zeile in der
Harness-YAML, exakt im Format aus 2.1:

```yaml
faelle:
  - slug: "or-fall-versammlungsauflage"
    gutachten: |
      <Volltext des zu bewertenden Referenzgutachtens>
    expectation:
      pruefpunkte:
        # 1:1 kopiert aus content/oeffentliches-recht/grundrechte.yaml,
        # faelle[].expectation.pruefpunkte des Falls "or-fall-versammlungsauflage"
        - id: "p1"
          label: "..."
          weight: 2.0
          required: true
          norms: ["..."]
    punkte: 9.5   # aggregierte Dozentenpunktzahl, siehe Regel unten
```

Aggregationsregel für `punkte` (aus `docs/13` Abschnitt 4.3):

- `|K1 − K2| ≤ 3`: `punkte` = arithmetisches Mittel aus K1 und K2.
- `|K1 − K2| > 3`: dritter Korrektor (K3) entscheidet per Stichentscheid;
  `punkte` = K3s Punktzahl (nicht der Mittelwert aus drei Werten) — analog
  zum echten Prüfungsverfahren, wo der Stichentscheid die Note endgültig
  festlegt, nicht verwässert.

Die 30 Zeilen zusammen ergeben die Referenzdatei für
`python backend/scripts/kalibrierung_cli.py run --input <datei>` — Format
1:1 wie `backend/tests/fixtures/kalibrierung_beispiel.yaml`, nur mit echten
(bzw. hier: redaktionell verfassten) Gutachtentexten und echten
Dozentenpunktzahlen statt der dort frei erfundenen Werte.

## 3. Doppelkorrektur und Inter-Rater-Messung

Pflicht nach `docs/13` Abschnitt 4.3: zwei unabhängige, blinde Bewertungen
je Gutachten. Ablauf:

1. Jedes der 30 Gutachten geht blind an zwei Korrektoren (kein Zugriff auf
   Systembewertung, kein Zugriff auf die jeweils andere Bewertung).
2. Differenz `|K1 − K2|` pro Fall wird erfasst, **unabhängig** von der
   späteren System-MAE — das ist ein eigener Datenpunkt, kein Nebenprodukt,
   das man nur bei Bedarf nachrechnet.
3. **Inter-Rater-MAE** = `mean(|K1_i − K2_i|)` über alle 30 Fälle (bei
   Stichentscheid-Fällen: Differenz der beiden ursprünglichen Korrektoren,
   nicht die K3-Entscheidung, damit die Streuungsmessung von der
   Konfliktlösung unabhängig bleibt).
4. **Berichtsregel:** Inter-Rater-MAE wird immer zusammen mit der
   System-MAE berichtet, nie isoliert die System-MAE allein. Liegt die
   Inter-Rater-MAE selbst über 2 Punkten, ist das Ziel "System-MAE ≤ 2"
   laut `docs/13` Abschnitt 4.3 eines, das die Dozenten untereinander nicht
   erreichen — das relativiert das Kriterium, ersetzt es aber nicht: Gate B
   bleibt an der System-MAE gegen die (ggf. per Stichentscheid bereinigte)
   Dozentennote hängen, nicht an einem nachträglich aufgeweichten Ziel.
   Alternative Erfolgs-Rahmung für den Bericht, falls Inter-Rater-MAE > 2:
   System-MAE ≤ Inter-Rater-MAE ("System stimmt mit Dozenten etwa so gut
   überein wie Dozenten untereinander") als zusätzliche, nicht
   ersetzende Kennzahl.
5. Stichentscheid-Schwelle: `|K1 − K2| > 3` → dritter Korrektor (siehe
   Abschnitt 2.3). Anteil der Fälle mit Stichentscheid wird mitgezählt und
   berichtet (hoher Anteil ⇒ Hinweis auf einen zu vage formulierten
   Erwartungshorizont, nicht nur auf strenge/milde Korrektoren).

## 4. Anschreiben (Entwurf, kein Versand)

> **Betreff: Mitwirkung an einer Kalibrierung für ein KI-Korrektur-Tool im
> Jurastudium (bezahlt)**
>
> Sehr geehrte/r [Name],
>
> wir entwickeln Subsumo, eine Lernanwendung für das Jurastudium mit
> KI-gestützter Gutachtenkorrektur gegen einen hinterlegten
> Erwartungshorizont (JAP-Punkteskala 0–18). Bevor wir diese Korrektur mit
> Punktzahl an Studierende ausliefern, müssen wir nachweisen, dass sie nah
> genug an einer menschlichen Fachbewertung liegt (Zielwert: mittlerer
> absoluter Fehler ≤ 2 Punkte gegenüber Dozentennoten).
>
> Dafür suchen wir [Anzahl] Personen mit Korrekturerfahrung im (Zweiten)
> Staatsexamen oder in der universitären Klausurkorrektur, die einen Teil
> von **30 Referenzgutachten** unabhängig bewerten — jedes Gutachten wird
> von zwei Korrektoren blind (ohne Kenntnis der jeweils anderen Bewertung
> oder der KI-Bewertung) benotet.
>
> **Aufwand:** ca. 15–20 Minuten je Gutachten (Gesamtpunktzahl 0–18 plus
> Kennzeichnung getroffener/verfehlter Prüfpunkte je einem kurzen
> Bewertungsbogen). Bei [Anzahl] Personen und gleichmäßiger Aufteilung der
> 30 Gutachten (× 2 Bewertungen je Gutachten) liegt der Aufwand pro Person
> bei etwa [Gesamtzahl Zuteilungen] Bewertungen, ca. [X] Stunden insgesamt.
> Vereinzelt kommt eine dritte, kurze Zweitmeinung hinzu, wenn zwei
> Bewertungen weit auseinanderliegen.
>
> **Vergütung:** [durch Auftraggeber festzulegen — Honorar je Gutachten
> oder Pauschale, vor Zusage zu klären]. Wir bevorzugen eine Vergütung
> gegenüber einem unbezahlten Gefallen, weil sich bezahlte Termine
> verlässlicher planen lassen.
>
> **Datennutzung:** Die zu bewertenden Gutachtentexte sind fiktiv und
> redaktionell erstellt (keine echten Studierendendaten, kein Bezug zu
> realen Klausuren). Ihre Bewertungen (Punktzahl, Prüfpunkt-Einschätzung,
> Freitext) verwenden wir ausschließlich zur Kalibrierung unseres
> Bewertungsmodells; eine Veröffentlichung erfolgt nur anonymisiert und
> aggregiert (z. B. als Fehlerkennzahl), nie mit Zuordnung zu Ihrer Person.
> Ihre Kontaktdaten nutzen wir ausschließlich zur Koordination und
> Honorarabwicklung.
>
> Über Interesse und verfügbare Kapazität würden wir uns sehr freuen.
>
> Mit freundlichen Grüßen,
> [Name/Team Subsumo]

**Hinweis zur AVV-Abhängigkeit:** Weil die 30 Referenzgutachten
redaktionell erstellte, fiktive Texte ohne Personenbezug sind (Quelle 1 aus
`docs/13` Abschnitt 4.2), betrifft der in SUB-129 zu klärende
Auftragsverarbeitungsvertrag mit dem LLM-Provider diesen Kalibrierungslauf
nicht zwingend — der AVV wird erst zum Gate, sobald echte
Nutzer-Gutachten (Quelle 2, Opt-in-Beta) durch den `LLMEvaluator` laufen.
Das ist der Grund, warum die Aufgabenbeschreibung diese Vorbereitung explizit
als "parallel und ohne Risiko" zu SUB-129 einordnet — die Kalibrierung selbst
kann sogar rein gegen den `HeuristicEvaluator` (kein Provider konfiguriert)
vorbereitet und mit synthetischen Texten durchgerechnet werden; nur ein Lauf
gegen den echten `LLMEvaluator` mit personenbeziehbaren Texten bräuchte den
AVV vorher.

## 5. Fallback ohne Dozentenzugang — bewertet, nicht nur zitiert

`docs/13` Abschnitt 4.6 nennt vier Stufen, `docs/03-roadmap.md:215` (Zeile
in der Risikotabelle) die Notlösung "Deckelung auf 11 Punkte offen
kommunizieren". Bewertung je Stufe:

1. **Erfahrene Korrekturassistenten/wiss. Mitarbeiter statt Dozenten.**
   Realistischste erste Ausweichstufe — nutzt dieselben T7-Kontakte
   (Fachschaften, Repetitorien, `docs/03-roadmap.md:76`), die ohnehin für
   die Beta-Anbahnung geplant sind, kein zusätzlicher Akquisekanal nötig.
   Einschränkung: externe Validität sinkt leicht (kein Lehrstuhl-Prüfer),
   bleibt aber deutlich über der reinen Redaktionsprüfung (Stufe 4).
2. **Honorar statt Gefallen.** Bewertung: sollte unabhängig vom Fallback
   ohnehin die Standardannahme sein (siehe Anschreiben-Entwurf oben), nicht
   erst greifen, wenn Dozenten nicht gewinnbar sind — ein bezahlter Auftrag
   ist für *beide* Zielgruppen (Dozenten wie Korrekturassistenten)
   verlässlicher terminierbar. Einzige offene Variable bleibt die Höhe, laut
   Auftrag bewusst nicht von diesem Paket festgelegt.
3. **Transparenzpflicht bei Fallback-Nutzung.** Das ist keine eigene
   Beschaffungsstufe, sondern eine Nebenbedingung, die ab Stufe 1 aufwärts
   gilt: Wird nicht mit habilitierten Dozenten kalibriert, darf das Produkt
   nicht mit "dozentengeprüft" werben (`docs/06-recht-compliance.md`
   Abschnitt 5). Geprüft: der aktuelle Launch-Text
   (`docs/21-landing-preisseite-launchtext.md`) enthält heute keine solche
   Aussage — kein akuter Konflikt, aber eine Vorgabe, die vor jeder
   künftigen Formulierung zu Korrektur-Qualität gilt, unabhängig davon,
   welche Fallback-Stufe am Ende genutzt wird.
4. **Nur redaktionelle Doppelprüfung, keine externen Personen.** Schwächste
   externe Validität, aber einzige Stufe ohne jede externe Abhängigkeit.
   **Wichtige Klarstellung, die die Roadmap-Zeile 215 für sich genommen
   verwischt:** `docs/03-roadmap.md:215` beschreibt die 11-Punkte-Deckelung
   als *vorübergehende* Notlösung ("bis die Kalibrierung nachträglich
   besteht"). `docs/13` Abschnitt 4.6 Punkt 4 verlangt für **diese**
   Fallback-Stufe (rein redaktionell, keine externe Referenz) ausdrücklich
   eine **dauerhafte** Deckelung — weil ohne jede externe Referenzbewertung
   nie eine belastbare Aussage über die tatsächliche MAE gegenüber echten
   Korrektoren möglich ist, also auch kein Zeitpunkt existiert, zu dem die
   Deckelung nachträglich fallen könnte. Die beiden Dokumente widersprechen
   sich nicht, sind aber leicht zu verwechseln: die Roadmap-Formulierung
   gilt für Stufen 1–3 (externe Referenz existiert, nur eben nicht von
   habilitierten Dozenten), nicht für Stufe 4.

**Empfehlung:** Stufe 1 mit Honorar (2) als Standardweg sofort anstoßen
(Anschreiben Abschnitt 4); Stufe 4 nur, wenn Stufe 1 nach angemessener
Frist nachweislich scheitert — und dann mit der dauerhaften statt
vorübergehenden Deckelung planen, nicht mit der Roadmap-Formulierung aus
Zeile 215.

## 6. Offene Punkte für den Nutzer

- Vergütungshöhe je Gutachten/Pauschale (Anschreiben, Abschnitt 4).
- Anzahl und Auswahl der tatsächlich anzufragenden Personen (Größe des
  Korrektoren-Pools bestimmt Aufwand pro Person, siehe Anschreiben).
- Entscheidung Strafrecht-Lücke (Abschnitt 1.2): sofort mit Zweitgutachten
  starten oder auf ein zehntes Thema aus einem Content-Folge-Batch warten.
- Wer schreibt die 30 Referenzgutachten in den drei Zielqualitätsstufen
  (Abschnitt 1) — das ist Content-Redaktionsarbeit, die dieses Paket
  vorbereitet, aber nicht selbst leistet.
