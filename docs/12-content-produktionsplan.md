# Content-Produktionsplan

Beantwortet die in [SUB-43](/SUB/issues/SUB-43) gestellte Frage: Reicht der
Redaktionstakt, um von heute (11 Themen) auf das Release-Gate T3 der
[Release-Roadmap](/SUB/issues/SUB-39#document-plan) zu kommen — **500 Karten,
40 Fälle über alle drei Rechtsgebiete, ≥ 10 % menschliche Stichprobe ohne
fachlichen Befund**? Bisher gab es dafür nur die Absicht, keine Rechnung.
Dieses Dokument liefert beides: eine Themenlandkarte und eine Rechnung, aus
echten Daten (`content/*.yaml`, `git log`, GitHub-PR-Historie), nicht aus
einer Schätzung vom Reißbrett.

**Ergebnis vorweg:** Ja, 500/40 sind bis Gate C (Woche 24) erreichbar — rund
61 zusätzliche Themen, ≈ 61 Menschenstunden Redaktions-Review im realistischen
Szenario, bei einem Produktionsfenster von ≈ 22 Wochen. Der Puffer ist
komfortabel bei ≥ 10 Std./Woche Fachredaktionskapazität und knapp, aber noch
positiv, bei nur 5 Std./Woche und ungünstigem Verlauf. Details und
Gegenrechnung in Abschnitt 3. Der in der Roadmap als Option genannte
Notfallschnitt „zwei statt drei Rechtsgebiete" ist nach dieser Rechnung nicht
nötig und wäre auch die falsche Reihenfolge — Begründung in Abschnitt 5.

## 0. Datenkorrektur: der heutige Bestand

Sowohl die Release-Roadmap als auch das Issue nennen als Ausgangslage „11
Themen, 77 Karten, 11 Schemata, 9 Fälle". Eine direkte Auszählung aller
`content/*/*.yaml` (Python/PyYAML, elf Dateien, Stand heute) ergibt:

| Größe | Bisher genannt | Tatsächlich (ausgezählt) |
|---|---|---|
| Themen | 11 | 11 ✅ |
| Karten | 77 | 77 ✅ |
| Prüfungsschemata | 11 | **13** |
| Fälle | 9 | **11** |

Die Karten- und Themenzahl stimmt exakt. Schemata und Fälle waren zu niedrig
angesetzt — vermutlich weil implizit „ein Schema/ein Fall pro Thema"
angenommen wurde. Tatsächlich haben zwei der elf Themen (`or-grundrechte`,
`sr-at`) je zwei Schemata, und alle elf Themen haben genau ein Fall (nicht
neun). Diese Zahlen sind unten die Grundlage der Rechnung; die Roadmap-Tabelle
in Abschnitt 1 der [Release-Roadmap](/SUB/issues/SUB-39#document-plan) sollte
bei Gelegenheit auf 13/11 korrigiert werden.

## 1. Themenlandkarte

Referenz ist der Pflichtstoffkatalog nach § 18 JAPO (Bayern), der in Aufbau
und Umfang mit den Pflichtfachkatalogen der anderen Länder (z. B. § 11 JAG
NRW) im Kernbestand übereinstimmt — Abweichungen liegen vor allem im
Landesrecht (hier bewusst ausgeklammert: Subsumo zielt auf den
bundesrechtlichen Kern). Quelle:
[Prüfungsgebiete nach § 18 JAPO](https://www.jura.uni-wuerzburg.de/studium/rechtswissenschaft/erste-juristische-pruefung/examensvorbereitung/pruefungsgebiete-nach-18-japo/),
Volltext auch beim
[Bayerischen Landesjustizprüfungsamt](https://www.justiz.bayern.de/media/pdf/ljpa/japo/japo_by_g%C3%BCltig_v._15.2.2022_bis_15.2.2022.pdf).

**Annahme:** „Thema" = ein prüfungsrelevanter Zuschnitt in der Größenordnung
der elf vorhandenen (z. B. „Diebstahl, § 242 StGB", nicht „Strafrecht BT" als
Ganzes). Die Liste ist redaktionell kuratiert nach Klausurhäufigkeit, keine
vollständige Themenexegese des Gesetzes — das deckt sich mit der Praxis in
`redaktion_cli.py::BACKLOG`, wo dieselbe Person/Instanz entscheidet, *was*
drankommt, nicht das Modell.

Priorität: **P1** Kernbestand, ohne den v1.0 nicht überzeugt · **P2**
regelmäßig klausurrelevant, ~~gehört in v1.0 wenn der Takt reicht~~ **gesetzter
v1.0-Umfang (Nutzerentscheid 23.09.2026, siehe Abschnitt 1.1)** · **P3**
ergänzend, vertretbar auch erst nach v1.0 (M6, siehe `docs/03-roadmap.md`).

### Zivilrecht (22 vorhanden, 4 offen → 26 Themen)

| Thema | Status | Priorität |
|---|---|---|
| BGB AT und Kaufrecht (Grundlagen) | ✅ vorhanden (`zr-bgb-at`) | P1 |
| Stellvertretung, §§ 164 ff. BGB | ✅ vorhanden (`zr-at-stellvertretung`) | P1 |
| Vertreter ohne Vertretungsmacht, §§ 177 ff. BGB | ✅ vorhanden (`zr-at-vertreter-ohne-vertretungsmacht`) | P2 |
| Willenserklärung und Auslegung, §§ 133, 157 BGB | ✅ vorhanden (`zr-at-auslegung`) | P1 |
| Anfechtung, §§ 119 ff. BGB | ✅ vorhanden (`zr-at-anfechtung`) | P1 |
| Geschäftsfähigkeit Minderjähriger, §§ 104 ff. BGB | ✅ vorhanden (`zr-at-geschaeftsfaehigkeit`) | P1 |
| Verjährung, §§ 194 ff. BGB | ✅ vorhanden (`zr-at-verjaehrung`) | P2 |
| AGB-Kontrolle, §§ 305 ff. BGB | ✅ vorhanden (`zr-schuldrecht-at-agb-kontrolle`) | P2 |
| Leistungsstörungen: Unmöglichkeit, § 275 BGB | ✅ vorhanden (`zr-schuldrecht-at-unmoeglichkeit`) | P1 |
| Verzug, § 286 BGB | ✅ vorhanden (`zr-su-verzug`) | P1 |
| Rücktritt, § 323 BGB | ✅ vorhanden (`zr-schuldrecht-at-ruecktritt`) | P1 |
| Schadensersatz statt der Leistung, §§ 280, 281 BGB | ✅ vorhanden (`zr-su-schadensersatz-statt-der-leistung`) | P1 |
| Culpa in contrahendo, § 311 Abs. 2 BGB | ✅ vorhanden (`zr-schuldrecht-at-cic`) | P2 |
| Abtretung, § 398 BGB | offen | P3 |
| Deliktsrecht: § 823 Abs. 1 BGB | ✅ vorhanden (`zr-deliktsrecht-823`) | P1 |
| Mängelgewährleistung Kaufrecht, §§ 434 ff. BGB (vertieft) | ✅ vorhanden (`zr-kaufrecht-maengelgewaehrleistung`) | P1 |
| Bereicherungsrecht, § 812 BGB | ✅ vorhanden (`zr-bereicherungsrecht-leistungskondiktion`) | P1 |
| § 823 Abs. 2 BGB, Schutzgesetzverletzung | ✅ vorhanden (`zr-deliktsrecht-823-abs2`) | P2 |
| § 826 BGB, vorsätzliche sittenwidrige Schädigung | ✅ vorhanden (`zr-deliktsrecht-826`) | P2 |
| Werkvertragsrecht, § 631 BGB | offen | P3 |
| Eigentumsherausgabe, § 985 BGB | ✅ vorhanden (`zr-sachenrecht-eigentumsherausgabe-985`) | P1 |
| Eigentumserwerb an beweglichen Sachen, § 929 BGB | ✅ vorhanden (`zr-sr-eigentumserwerb-929`) | P1 |
| Gutgläubiger Erwerb, § 932 BGB | ✅ vorhanden (`zr-sr-gutglaeubiger-erwerb-932`) | P1 |
| Sicherungsübereignung | ✅ vorhanden (`zr-sr-sicherungsuebereignung`) | P2 |
| Kaufmannsbegriff und Handelsregister, HGB | offen | P3 |
| Prokura und Handlungsvollmacht, § 48 HGB | offen | P3 |

### Strafrecht (20 vorhanden, 2 offen → 22 Themen)

| Thema | Status | Priorität |
|---|---|---|
| Strafrecht AT: Aufbau des vollendeten Vorsatzdelikts | ✅ vorhanden (`sr-at`) | P1 |
| Versuch und Rücktritt, §§ 22 ff. StGB | ✅ vorhanden (`sr-versuch-ruecktritt`) | P1 |
| Täterschaft und Teilnahme, §§ 25 ff. StGB | ✅ vorhanden (`sr-taeterschaft-teilnahme-25`) | P1 |
| Kausalität und objektive Zurechnung | ✅ vorhanden (`sr-at-kausalitaet-zurechnung`) | P1 |
| Vorsatz und Tatbestandsirrtum, § 16 StGB | ✅ vorhanden (`sr-at-vorsatz-tatbestandsirrtum`) | P1 |
| Notwehr, § 32 StGB | ✅ vorhanden (`sr-notwehr-32`) | P1 |
| Rechtfertigender Notstand, § 34 StGB | ✅ vorhanden (`sr-notstand-34`) | P2 |
| Verbotsirrtum, § 17 StGB | ✅ vorhanden (`sr-at-verbotsirrtum-17`) | P2 |
| Fahrlässige Delikte, § 222 StGB | ✅ vorhanden (`sr-bt-fahrlaessige-toetung-222`) | P2 |
| Unterlassungsdelikte, § 13 StGB | ✅ vorhanden (`sr-at-unterlassungsdelikte`) | P2 |
| Konkurrenzen | offen | P3 |
| Körperverletzungsdelikte, §§ 223 ff. StGB | ✅ vorhanden (`sr-bt-koerperverletzung-224`) | P1 |
| Tötungsdelikte, §§ 211, 212 StGB | ✅ vorhanden (`sr-bt-toetungsdelikte-211-212`) | P1 |
| Nötigung, § 240 StGB | ✅ vorhanden (`sr-bt-noetigung-240`) | P2 |
| Freiheitsberaubung, § 239 StGB | offen | P3 |
| Diebstahl, § 242 StGB | ✅ vorhanden (`sr-bt-diebstahl`) | P1 |
| Raub, § 249 StGB | ✅ vorhanden (`sr-bt-raub`) | P1 |
| Betrug, § 263 StGB | ✅ vorhanden (`sr-bt-betrug`) | P1 |
| Urkundenfälschung, § 267 StGB | ✅ vorhanden (`sr-bt-urkundenfaelschung-267`) | P2 |
| Untreue, § 266 StGB | ✅ vorhanden (`sr-bt-untreue-266`) | P2 |
| Unterschlagung, § 246 StGB | ✅ vorhanden (`sr-bt-unterschlagung-246`) | P2 |
| Erpressung, § 253 StGB | ✅ vorhanden (`sr-bt-erpressung-253`) | P2 |

### Öffentliches Recht (18 vorhanden, 8 offen → 26 Themen)

Ursprünglich als größter Nachholbedarf geführt (damals 2 von 11 Themen).
Stand 23.09.2026 sind P1- **und** P2-Kern des Gebiets vollständig; die
8 offenen Themen sind sämtlich P3 (Kommunalrecht, Störerauswahl, Baurecht,
Unionsrecht, Glaubensfreiheit und vertiefende Verfassungsthemen).

| Thema | Status | Priorität |
|---|---|---|
| Grundrechte und Verfassungsprozessrecht (Grundlagen) | ✅ vorhanden (`or-grundrechte`) | P1 |
| Art. 12 Abs. 1 GG: Berufsfreiheit | ✅ vorhanden (`or-berufsfreiheit`) | P1 |
| Art. 14 GG: Eigentumsgarantie | ✅ vorhanden (`or-eigentumsgarantie`) | P1 |
| Art. 2 Abs. 1 GG: Allgemeine Handlungsfreiheit | ✅ vorhanden (`or-allgemeine-handlungsfreiheit`) | P1 |
| Art. 3 GG: Gleichheitssatz | ✅ vorhanden (`or-gleichheitssatz`) | P1 |
| Art. 5 GG: Meinungsfreiheit | ✅ vorhanden (`or-meinungsfreiheit`) | P1 |
| Art. 8 GG: Versammlungsfreiheit | ✅ vorhanden (`or-versammlungsfreiheit`) | P2 |
| Art. 4 GG: Glaubensfreiheit | offen | P3 |
| Enteignung und Inhalts-/Schrankenbestimmung, Art. 14 GG vertieft | offen | P3 |
| Gesetzgebungsverfahren, Art. 76 ff. GG | ✅ vorhanden (`or-staatsorganisationsrecht-gesetzgebungsverfahren`) | P2 |
| Organstreitverfahren | ✅ vorhanden (`or-verfassungsprozessrecht-organstreitverfahren`) | P2 |
| Bund-Länder-Kompetenzen, Art. 70 ff. GG | offen | P3 |
| Normenkontrollverfahren | offen | P3 |
| Der Verwaltungsakt, § 35 VwVfG | ✅ vorhanden (`or-vwvfg-verwaltungsakt`) | P1 |
| Ermessen, § 40 VwVfG | ✅ vorhanden (`or-vwvfg-ermessen-beurteilungsspielraum`) | P1 |
| Rechtmäßigkeitsprüfung eines Verwaltungsakts | ✅ vorhanden (`or-va-rechtmaessigkeitspruefung`) | P1 |
| Nebenbestimmungen, § 36 VwVfG | ✅ vorhanden (`or-vwvfg-nebenbestimmungen`) | P2 |
| Rücknahme und Widerruf, §§ 48, 49 VwVfG | ✅ vorhanden (`or-vwvfg-ruecknahme-widerruf`) | P2 |
| Die Anfechtungsklage, § 42 Abs. 1 Var. 1 VwGO | ✅ vorhanden (`or-vwgo-anfechtungsklage`) | P1 |
| Die Verpflichtungsklage, § 42 Abs. 1 Var. 2 VwGO | ✅ vorhanden (`or-vwgo-verpflichtungsklage`) | P2 |
| Vorläufiger Rechtsschutz, §§ 80, 123 VwGO | ✅ vorhanden (`or-vwgo-vorlaeufiger-rechtsschutz`) | P2 |
| Polizeiliche Generalklausel und Standardmaßnahmen | ✅ vorhanden (`or-sicherheitsrecht-generalklausel-standardmassnahmen`) | P2 |
| Störerauswahl, §§ 4, 5 PolG | offen | P3 |
| Organe der Gemeinde (Kommunalrecht) | offen | P3 |
| Bauplanungsrecht, §§ 30–35 BauGB (Grundzüge) | offen | P3 |
| Grundfreiheiten im Unionsrecht (Grundzüge) | offen | P3 |

**Summe: 74 Themen** (Stand 23.09.2026, nach dem P2-Abschluss: **60 vorhanden
+ 14 offen**). Nach Priorität: **P1 36/36 vorhanden, P2 24/24 vorhanden**, P3
0 vorhanden / 14 offen. Der kuratierte `BACKLOG` in `redaktion_cli.py` ist
vollständig abgearbeitet (57/57); **alle noch offenen Themen sind
ausschließlich P3** und damit laut Prioritätsdefinition oben bewusst
nach-v1.0-Stoff (M6).

**Nicht in v1.0, bewusst:** Familien-/Erbrecht über die Grundzüge hinaus,
Gesellschaftsrecht über GbR/Prokura hinaus, Arbeitsrecht als eigenes Feld,
Strafprozessrecht als eigener Block. Das sind reguläre JAPO-Randgebiete mit
geringerer Klausurdichte; Aufnahme nach v1.0 in M6.

### 1.1 Nutzerentscheid 23.09.2026: P2 gehört in v1.0

Der Nutzer hat auf [SUB-225](/SUB/issues/SUB-225) entschieden: **„P2 soll vor
dem Release auch kommen."** Damit ist die bisherige Taktabhängigkeit von P2
aufgehoben — P2 ist gesetzter v1.0-Umfang. Das betraf 17 offene Themen,
verteilt auf drei Gebiets-Redakteure und nach Klausurrelevanz sortiert, weil
bei Teillieferung die Reihenfolge entscheidet, was live geht.

**Ergebnis: vollständig geliefert, alle 17 Themen am 23.09.2026 auf `main`.**

| Gebiet | P2-Themen | Auftrag | Stand |
|---|---|---|---|
| Zivilrecht | Verjährung §§ 194 ff.; § 823 Abs. 2; § 826; Sicherungsübereignung | [SUB-243](/SUB/issues/SUB-243) | ✅ 4/4, PR #69 (`b78ae6d`) |
| Strafrecht | § 34; § 240; § 17; § 222; § 246; § 253; § 266 StGB | [SUB-244](/SUB/issues/SUB-244) | ✅ 7/7, PR #70 (`c13c815`) |
| Öffentliches Recht | §§ 48, 49 VwVfG; § 36 VwVfG; Polizeirecht-Generalklausel; Art. 8 GG; Art. 76 ff. GG; Organstreit | [SUB-245](/SUB/issues/SUB-245) | ✅ 6/6, PR #68 (`75f204e`) |

**Mengenwirkung, Ist statt Prognose:** Erwartet waren ≈ 119 zusätzliche Karten
(17 × Richtwert 7) auf ≈ 432. Tatsächlich ausgezählt
(`backend/scripts/validate_content.py` gegen `main`):

| Größe | Vor P2 | Nach P2 | G3-Ziel (`docs/18`) | T3-Ziel (Gate C) |
|---|---|---|---|---|
| Themen | 43 | **60** | — | 72–74 |
| Karten | 313 | **444** | 180 ✅ 2,5× | 500 (56 offen) |
| Schemata | 45 | **64** | — | — |
| Fälle | 43 | **60** | — | 40 ✅ übererfüllt |

Die P2-Themen fielen mit Ø 7,7 Karten etwas umfangreicher aus als der
Richtwert. Das G3-Ziel ist um das 2,5-Fache übererfüllt, das Fälle-Ziel des
T3-Gates ist bereits erreicht. Für die 500-Karten-Zielmenge fehlen noch
56 Karten ≈ 8 P3-Themen — laut `docs/18-release-2-wochen.md` (Abschnitt 4)
ist diese Zielmenge jedoch ausdrücklich **„laufende Produktion nach Release"**
und kein v1.0-Gate.

**Was damit offen bleibt — und es ist nicht die Menge:** Die menschliche
Stichprobe nach Abschnitt 4.2 ist für **keines der 60 Themen** erbracht. Alle
57 Themen mit Redaktions-Metadaten tragen `status: ki-freigegeben` und
`geprueft_von: reviewer-agent-v1` — ein LLM-Aufruf, keine Person. Das ist
dieselbe Lücke, die Abschnitt 3.1 bei n = 8 beschrieben hat, nur jetzt bei
n = 60. Kein Agent kann dieses Gate schließen; es braucht eine Person mit
juristischer Vorbildung (`docs/08-ki-redaktion.md`). Stratifizierter
Mindestumfang nach Abschnitt 4.2: ≥ 6 Themen, mind. 2 je Rechtsgebiet,
Schwerpunkt P1.

## 2. Zuschnitt eines Themas

Ausgezählt aus den elf vorhandenen `content/*.yaml`-Dateien
(`topic.slug`, `len(cards)`, `len(schemata)`, `len(faelle)`):

| Größe | Summe | Mittelwert/Thema | Stdabw. (Population) | Min–Max |
|---|---|---|---|---|
| Karten | 77 | 7.00 | 0.60 | 6–8 |
| Schemata | 13 | 1.18 | 0.39 | 1–2 |
| Fälle | 11 | 1.00 | 0.00 | 1–1 |

**Lesart:** Der Kartenumfang pro Thema ist eng gebündelt (6–8, kaum
Streuung) — ein verlässlicher Planungswert. Jedes Thema hat bisher **genau
ein** Fall; das ist keine Naturkonstante, sondern eine redaktionelle
Entscheidung der bisherigen BACKLOG-Kuration (jedes Thema wurde bewusst so
zugeschnitten, dass ein Fall reinpasst). Für die Hochrechnung heißt das: der
Kartenrichtwert ist belastbar, die Annahme „1 Fall pro Thema" ist ein Hebel,
kein Gesetz — siehe Abschnitt 5.

**Arbeitswert für Abschnitt 3:** 1 Thema ≈ 7 Karten + 1,2 Schemata + 1 Fall.

## 3. Durchsatzrechnung

### 3.1 Was die Daten zeigen — und was nicht

Acht der elf Themen entstanden über die KI-Redaktion
(`topic.redaktion.status: ki-freigegeben`). Commit-Zeitstempel der jeweils
ersten Version (`git log --diff-filter=A`):

| Thema | Commit-Zeitpunkt |
|---|---|
| `zr-at-stellvertretung` | 2026-09-12 20:20 |
| `zr-schuldrecht-at-unmoeglichkeit` | 2026-09-13 13:10 |
| `sr-bt-diebstahl` | 2026-09-13 13:14 |
| `or-berufsfreiheit` | 2026-09-13 13:18 |
| `zr-deliktsrecht-823` | 2026-09-13 13:21 |
| `sr-versuch-ruecktritt` | 2026-09-13 13:24 |
| `zr-sachenrecht-eigentumsherausgabe-985` | 2026-09-14 10:09 |
| `sr-taeterschaft-teilnahme-25` | 2026-09-14 11:04 |

Fünf davon liegen 13 Minuten auseinander (13:10–13:24 Uhr am 13.09.) — klar
eine einzelne Bearbeitungssitzung im Brücken-Modus, kein Beleg für einen
über Tage verteilten, unabhängigen Redaktionstakt. Diese Zahl beantwortet
**nur**, wie schnell Collector- und Reviewer-Agent technisch antworten
(Minuten), nicht die eigentliche Frage aus dem Issue: den Takt *inklusive
menschlicher Prüfung*.

**Ehrlicher Befund:** Für die menschliche Prüfung gibt es aktuell **keine
Daten**. Belege dafür:

- `topic.redaktion.geprueft_von` steht bei allen acht Themen auf
  `reviewer-agent-v1` — ein LLM-Aufruf, keine Person.
- Die zugehörigen GitHub-PRs (`gh pr list`, #3 und #6 für die beiden
  jüngsten Themen) haben `"reviews": []` — keine einzige aufgezeichnete
  Review-Freigabe.
- `docs/08-ki-redaktion.md` schreibt vor: „jeder KI-erzeugte Inhalt [ist]
  vor der ersten Nutzung stichprobenartig von einer Person mit juristischer
  Vorbildung zu prüfen" — das ist bisher für keines der acht Themen
  nachweisbar geschehen.

Das ist keine Randnotiz, sondern der Kern des Problems: Die einzige real
gemessene Zykluszeit (Minuten) misst genau die Stufe, die **nicht** der
Engpass ist. Die eigentliche Bremse — menschliche Stichprobe — ist unbemessen.
Abschnitt 3.2 rechnet deshalb mit einem explizit ausgewiesenen Annahme-Modell
statt mit einer stillschweigend verlängerten Maschinen-Zahl.

### 3.2 Annahme-Modell für die menschliche Prüfung

Aufwand pro Thema = Kuration (Themenauswahl, Kontextzeile für
`redaktion_cli.py::BACKLOG` schreiben) + Stichprobe-Review (Urheberrecht,
RDG-Fiktivität, fachliche Plausibilität, Normzitate — die fünf Punkte aus
`docs/08-ki-redaktion.md`) je Karte/Schema/Fall eines Themas (Ø 7+1,2+1
Einheiten).

| Szenario | Kuration | Stichprobe-Review | Summe/Thema |
|---|---|---|---|
| Optimistisch | 15 min | 20 min | 35 min |
| Realistisch | 15 min | 45 min | 60 min |
| Pessimistisch (inkl. Nacharbeitsrunde bei ca. jedem 3. Thema) | 15 min | 90 min | 105 min |

**Annahme, explizit:** Diese Minutenwerte sind geschätzt, nicht gemessen —
siehe 3.1. Empfehlung: Ab dem ersten realen Stichproben-Durchlauf in Phase A
die tatsächliche Zeit stoppen und dieses Modell nach 10–15 Themen durch
Ist-Werte ersetzen.

### 3.3 Zielrechnung

Fehlmenge bis Gate T3: 500 − 77 = **423 Karten**. Bei Ø 7,0 Karten/Thema:
⌈423 / 7,0⌉ = **61 zusätzliche Themen** (Karten sind die bindende Größe, nicht
Fälle — dazu mehr in Abschnitt 5). Macht insgesamt 72 Themen, deckungsgleich
mit der Themenlandkarte in Abschnitt 1.

| Szenario | Aufwand/Thema | Aufwand für 61 Themen |
|---|---|---|
| Optimistisch | 35 min | 35,6 Std. |
| Realistisch | 60 min | 61,0 Std. |
| Pessimistisch | 105 min | 106,8 Std. |

**Verfügbares Fenster laut Release-Roadmap:** Phase A (W1–6, davon realistisch
4 Wochen produktiv nach Ramp-up/dieser Landkarte) + Phase B (W7–16, 10 Wochen)
+ Phase C (W17–24, 8 Wochen) ≈ **22 Wochen** bis Gate C.

**Kapazität, zwei Annahmen** (Roadmap nennt nur „Teilzeit-Fachredaktion",
ohne Stundenzahl):

| Kapazität | Verfügbare Stunden über 22 Wochen | Optimistisch reicht für | Realistisch reicht für | Pessimistisch reicht für |
|---|---|---|---|---|
| 5 Std./Woche | 110 Std. | ✅ Faktor 3,1× | ✅ Faktor 1,8× | ✅ Faktor 1,03× (praktisch kein Puffer) |
| 10 Std./Woche | 220 Std. | ✅ Faktor 6,2× | ✅ Faktor 3,6× | ✅ Faktor 2,1× |

**Zwischen-Gate B** (Woche 16, 250 Karten / 20 Fälle laut Release-Roadmap):
fehlen (250 − 77)/7 ≈ 25 Themen, realistisch 25 Std. Aufwand, bei
≈ 15 produktiven Wochen bis dahin selbst mit 2 Std./Woche (30 Std.) unkritisch
erreichbar.

### 3.4 Antwort

**Ja, 500 Karten und 40 Fälle sind innerhalb der geplanten Phasen A–C
(≈ 22 Wochen) erreichbar — 61 zusätzliche Themen, realistisch ≈ 61
Redaktions-Stunden.** Bei ≥ 5 Std./Woche verlässlicher Fachredaktionskapazität
bleibt selbst im pessimistischen Szenario ein (knapper) positiver Puffer; bei
≥ 10 Std./Woche ist der Puffer komfortabel (Faktor 2–6×). Das einzige
Szenario, das kippt, ist eine Kombination aus **beidem gleichzeitig**:
Kapazität unter 5 Std./Woche *und* durchgehend pessimistischer Aufwand pro
Thema. Konkrete Empfehlung: Fachredaktionskapazität von mindestens 5
Std./Woche für Phase A–C als Ressourcen-Zusage einholen (Bezug zur offenen
Frage O5 „Budget" in der Release-Roadmap) und ab den ersten realen
Stichproben die Ist-Zeit messen, um Abschnitt 3.2 zu kalibrieren.

## 4. Qualitätssicherung im Maßstab

### 4.1 Wo der Reviewer-Agent nicht mehr reicht

Der LLM-Reviewer (`ReviewerAgent`) ist bereits heute ein Pflicht-Gate vor
jedem Merge — das skaliert automatisch mit, kein Kapazitätsproblem. Die
Grenze liegt woanders, und zwar dort, wo `docs/08-ki-redaktion.md` sie selbst
benennt: **Normzitate**. Ein Sprachmodell prüft sich nicht selbst zuverlässig
auf erfundene Paragraphen; genau dafür ist der Norm-Explorer (M2) als
deterministische dritte Stufe vorgesehen, existiert aber noch nicht. Bis
dahin ist die menschliche Stichprobe die einzige Instanz, die das auffängt —
und laut Abschnitt 3.1 hat sie bei keinem der acht bisherigen KI-Themen
stattgefunden. Das ist keine Frage der Menge, sondern eine bereits heute
offene Lücke bei n = 8.

### 4.2 Stichprobenquote

Release-Gate T3 verlangt „≥ 10 % menschliche Stichprobe ohne fachlichen
Befund". Vorschlag für die Umsetzung, gestaffelt statt pauschal:

- **100 % Struktur-Gate** (`load_content`, bereits vorhanden, CI-Pflicht) —
  automatisch, kostet nichts extra.
- **100 % LLM-Reviewer-Gate** (bereits vorhanden) — Pflicht vor jedem Merge.
- **100 % Normzitat-Stichprüfung, aber nur automatisiert**, sobald ein
  einfacher Vor-Abgleich existiert (siehe 4.3) — kein Ersatz für den
  Norm-Explorer, aber deutlich billiger als jede fünfte Klausel von Hand
  nachzuschlagen.
- **Mindestens 10 % der neuen Themen vollständig menschlich geprüft**
  (Karten, Schemata, Fall inkl. Erwartungshorizont) — bei 61 neuen Themen
  sind das mindestens 7. Empfehlung: nicht zufällig ziehen, sondern die
  Stichprobe **stratifiziert nach Rechtsgebiet und Priorität** ziehen (mind.
  2 pro Rechtsgebiet, Schwerpunkt P1), damit ein systematischer Fehler in
  einem Gebiet nicht durch Zufall übersehen wird.
- **100 % der P1-Themen erhalten unabhängig von der Zufallsstichprobe eine
  menschliche Prüfung**, weil sie laut Definition (Abschnitt 1) den
  Kernbestand tragen — ein Fehler dort wiegt schwerer als bei einem
  P3-Randthema. Das treibt die effektive Quote deutlich über 10 % (36 von 61
  neuen Themen sind P1, siehe Abschnitt 5), ohne dass jedes Thema geprüft
  werden muss.
- **Adaptiv nachschärfen:** Befundrate der ersten 15 geprüften Themen
  protokollieren. Bleibt sie niedrig, ist die 10-%-Fläche ausreichend; steigt
  sie, wird die Quote für das jeweilige Rechtsgebiet oder den jeweiligen
  Kartentyp erhöht, bis die Ursache gefunden ist.

### 4.3 Wie ein Befund zurück in die Pipeline läuft

Zwei Fälle, je nachdem wann der Befund auftritt:

**Vor dem Merge** (LLM-Reviewer lehnt ab): existiert bereits —
`RedaktionPipeline` schickt das Feedback an den Collector zurück, bis zu
`MAX_ROUNDS = 3` (`pipeline.py`). Unverändert.

**Nach dem Merge** (menschliche Stichprobe oder ein Nutzerbericht findet
etwas, das der LLM-Reviewer durchgelassen hat) — dafür fehlt heute ein
Prozess, hier der Vorschlag:

1. Befund wird als Issue mit Bezug auf `topic.slug` + betroffene
   Karte/Schema/Fall-`slug` angelegt.
2. `topic.redaktion.status` wird von `ki-freigegeben` auf `in-pruefung`
   gesetzt — dieser Wert existiert bereits in `docs/08-ki-redaktion.md` und
   in der CI-Warnlogik (`app/services/content.py`), muss also nur auf einen
   zweiten Auslöser (nachträglicher Befund, nicht nur „vor Erstnutzung")
   erweitert werden.
3. Je nach Schwere: kleine Korrektur direkt im PR, oder neue Collector-Runde
   mit dem Befund als Kontext (wie bei einer regulären Ablehnungsrunde, nur
   nachträglich ausgelöst).
4. Erneuter Reviewer-Agent-Durchlauf **und** — weil der ursprüngliche Fehler
   ja gerade zeigte, dass die automatisierten Gates ihn nicht gefangen haben —
   eine zweite menschliche Prüfung, bevor der Status zurück auf
   `ki-freigegeben` wechselt.
5. Befund fließt in die Befundrate aus 4.2 ein und kann die Stichprobenquote
   für das betroffene Rechtsgebiet anheben.

## 5. Notfallschnitt

> **Stand 23.09.2026: gegenstandslos für v1.0.** Der Notfallschnitt war eine
> Vorsorge für den Fall, dass der Content-Takt nicht reicht. Er hat nicht
> gegriffen: P1 (36/36) und P2 (24/24) sind vollständig geliefert, alle drei
> Rechtsgebiete tragen ihren kompletten Kernbestand, 444 Karten gegen ein
> G3-Ziel von 180. Der Abschnitt bleibt als dokumentierte Reihenfolge für die
> P3-/M6-Produktion nach dem Release stehen — die Zahlen darin sind unten auf
> den Ist-Stand korrigiert.

Die Release-Roadmap nennt als Option: „v1.0 auf zwei statt drei
Rechtsgebiete, falls der Content-Takt nicht reicht" (offene Frage O3,
Risikotabelle Abschnitt 6). Nach der Rechnung in Abschnitt 3 ist dieser
Schnitt **aktuell nicht nötig** — der Takt reicht mit Puffer. Trotzdem lohnt
die Prüfung, weil O3 im Roadmap-Dokument offen ist und weil ein Notfallplan
vor der Krise feststehen sollte, nicht während ihr.

**Ist „zwei statt drei Rechtsgebiete" produktseitig tragbar? Nein.** Die
Produktvision (`docs/01-produktvision.md`) und Release-Gate 0 verlangen: „ein
Erstsemester … kann die App am Tag 1 sinnvoll nutzen". Zivilrecht, Strafrecht
und Öffentliches Recht laufen im deutschen Jurastudium ab dem ersten Semester
**parallel**, nicht nacheinander — ein Erstsemester hat in der Regel
Veranstaltungen in allen drei Gebieten gleichzeitig. Fehlt eines komplett,
scheitert die App für jeden Studierenden, dessen aktuelles Semester das
fehlende Gebiet enthält, am Tag-1-Kriterium selbst. Das ist kein graduelles
Downgrade, sondern ein Ausfall für einen ganzen Nutzerkreis — und trifft dazu
ausgerechnet Öffentliches Recht am härtesten, das bei Abfassung dieses
Abschnitts mit 2 von 11 Themen am weitesten zurücklag (Abschnitt 1) und das
gleichzeitig das JAPO-Gebiet mit den meisten Teilgebieten ist. *(Dieser
Rückstand ist seit 23.09.2026 aufgeholt: 18 von 26 Themen, P1 und P2
vollständig.)*

**Bessere Variante — horizontal statt vertikal kürzen, in dieser
Reihenfolge:**

1. ~~**Fälle nicht auf alle Themen verteilen.**~~ — **erledigt, Hebel nicht
   mehr nötig.** Die ursprüngliche Rechnung („36 neue P1-Themen plus 11
   vorhandene = 47") zählte die elf Bestandsthemen doppelt; die Landkarte
   enthält insgesamt **36 P1-Themen**, nicht 47. Der Punkt ist ohnehin
   gegenstandslos: Jedes der 60 gelieferten Themen hat genau einen Fall, macht
   **60 Fälle** gegen ein T3-Ziel von 40 — übererfüllt, ohne dass gekürzt
   werden musste.
2. **P3-Themen zuerst strecken, nicht streichen.** Sinkt der reale Takt unter
   das realistische Szenario, zuerst die **14** P3-Themen (über alle drei
   Rechtsgebiete verteilt, siehe Abschnitt 1) in Richtung M6 schieben. Das
   reduziert die Zielmenge auf 60 Themen (74 − 14) und ist mit dem
   P2-Abschluss faktisch bereits der eingetretene Zustand: Was heute auf
   `main` liegt, *ist* die um P3 gestreckte Zielmenge. Jedes Rechtsgebiet
   behält seinen P1/P2-Kernbestand vollständig.
3. ~~**Erst danach, falls das nicht reicht: P2-Themen strecken**~~ —
   **hinfällig seit 23.09.2026.** Der Nutzerentscheid in Abschnitt 1.1 nimmt
   P2 aus der Streckmasse: P2 gehört in v1.0. Bleibt nach Stufe 1 und 2 immer
   noch eine Lücke, ist die richtige Reaktion nicht, P2 zu kürzen, sondern
   *innerhalb* von P2 nach der in Abschnitt 1.1 festgelegten Reihenfolge zu
   liefern und den Rest offen zu benennen.
4. **Was nicht zur Disposition steht:** die ≥ 10-%-Stichprobenquote
   (Release-Gate, kein Kosmetikposten) und die P1-Themen aller drei Gebiete —
   das wäre der Punkt, an dem „Tag 1 sinnvoll nutzbar" kippt.

Kurz: Lieber jedes Rechtsgebiet dünner am Rand als eines davon ganz
auslassen. Das hält das Tag-1-Versprechen für alle drei Nutzer-Personas aus
`docs/01-produktvision.md` aufrecht, egal welches Rechtsgebiet gerade im
Semesterplan steht.

## 6. Versionierung und Update-Diffs

**Ausgangslage im Code:** `card.stand` / `schema.stand` / `case.stand` sind
bereits Pflichtfelder (`app/services/content.py`), geprüft auf Format und auf
Alter (`STALE_AFTER_MONTHS = 18`). Daneben gibt es
`GET /content/manifest` → `_content_version()`
(`app/api/v1/content.py`): ein SHA-256-Hash über den *gesamten* Kartenbestand,
für den in `docs/03-roadmap.md` als offen vermerkten Client-Delta-Sync. Beide
Bausteine lösen aber nicht das hier gefragte Problem: Ein Nutzer, der ein
Thema schon gelernt hat, muss erfahren *dass* und *was* sich an der
Rechtslage geändert hat — nicht nur, dass sich irgendwo im Gesamtbestand
etwas geändert hat (das sagt der Manifest-Hash) und auch nicht nur, dass der
Inhalt „alt" ist (das sagt `stand`, ohne Grund).

**Vorschlag, ohne neues Pflichtfeld:**

1. `stand` bleibt der Versionsanker pro Karte/Schema/Fall — es ist bereits
   Pflicht, bereits validiert, monoton interpretierbar (YYYY-MM). Kein neues
   Feld nötig.
2. Eine Änderung an `stand` **ohne** inhaltliche Änderung von `front`/`back`/
   Schema-Schritten/Fall-Text (z. B. reine Tippfehlerkorrektur) löst keinen
   Diff-Hinweis aus — dafür reicht ein einfacher Vergleich des Textinhalts
   zwischen der vorherigen und der neuen Fassung, den Git ohnehin
   bereitstellt (`git diff` auf den betroffenen Pfad zwischen den beiden
   `stand`-tragenden Commits).
3. Ändert sich der Text **und** `stand` (also eine fachliche Änderung: neue
   Norm, neue Rechtsprechung, korrigierter Prüfpunkt), wird das serverseitig
   als „Rechtslage geändert" markiert. Ein Nutzer, dessen FSRS-Historie diese
   Karte/dieses Schema/diesen Fall bereits mit einem `stand` vor der Änderung
   enthält, bekommt beim nächsten Erscheinen keine normale Wiederholung,
   sondern einen Diff-Hinweis (alter Text → neuer Text, wie ein Code-Review-
   Diff) statt einer stillen Neuauslieferung.
4. Dieselbe Markierung greift, wenn ein Befund aus dem QS-Prozess
   (Abschnitt 4.3) eine bereits gelernte Karte korrigiert — Versionierung und
   Fehlerrückführung nutzen denselben Mechanismus, keinen zweiten.

**Was das explizit nicht ist:** ein fertiger Implementierungsplan. Punkt 2–4
sind heute **nicht** gebaut (die Manifest-Route liefert nur einen
Gesamt-Hash, keinen Pro-Einheit-Diff) und gehören als Engineering-Aufgabe zu
T1/T4, nicht zu diesem Redaktionsplan — hier nur festgehalten, damit T3 nicht
unabhängig von T4 an der Frage vorbeiplant, wie ein bereits gelernter Inhalt
bei Änderung behandelt wird.

## Quellen

- `content/*/*.yaml` (Auszählung Abschnitt 0 und 2, Stand: heute)
- `git log --diff-filter=A` je KI-Thema, `gh pr list --json reviews` (Abschnitt 3.1)
- `docs/08-ki-redaktion.md`, `backend/scripts/redaktion_cli.py`, `backend/app/services/content.py`, `backend/app/api/v1/content.py`
- [Release-Roadmap Subsumo v1.0](/SUB/issues/SUB-39#document-plan) (Gate T3, Phasen A–D, Risikotabelle O3)
- [Prüfungsgebiete nach § 18 JAPO](https://www.jura.uni-wuerzburg.de/studium/rechtswissenschaft/erste-juristische-pruefung/examensvorbereitung/pruefungsgebiete-nach-18-japo/), [JAPO Bayern (Volltext)](https://www.justiz.bayern.de/media/pdf/ljpa/japo/japo_by_g%C3%BCltig_v._15.2.2022_bis_15.2.2022.pdf)
