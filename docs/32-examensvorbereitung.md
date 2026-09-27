# Examensvorbereitung: Bundesland, Universitaet, Kurs-Decks, Examen-Reiter

Konzept und Umsetzungsstand fuer den Examen-Reiter der App. Beantwortet vier
Fragen, die das Produkt bisher offen liess:

1. **Wo wird geprueft?** Die staatliche Pflichtfachpruefung ist Landesrecht -
   Zahl und Verteilung der Klausuren, Freiversuch, Abschichtung, Hilfsmittel
   und vor allem der Landesrechtsanteil im Oeffentlichen Recht unterscheiden
   sich je Bundesland. Bisher kannte Subsumo nur den bundesrechtlichen Kern
   (`docs/12-content-produktionsplan.md`, Abschnitt 1: "Landesrecht bewusst
   ausgeklammert").
2. **Wo wird studiert?** Der Weg zum Examen fuehrt ueber Vorlesungen und
   Klausuren einer konkreten Fakultaet. Ein Nutzer im dritten Semester will
   das Deck zu "Schuldrecht BT", nicht "alle 92 Themen".
3. **Was heisst "vorbereitet"?** Die Coverage-Zahl misst nur Kartenreife
   (`docs/13-lernarchitektur.md`, Abschnitt 1.2, Aenderungsbedarf). Fuer das
   Examen zaehlen Anwendung, Technik und Klausurpraxis mindestens so viel.
4. **Wo sieht man das alles zusammen?** Bisher: Karten, Schemata und Faelle
   als getrennte Tabs, der Planer nur als API ohne UI, kein Examensdatum-
   Eingabefeld in der App.

Der Examen-Reiter ist die Antwort auf alle vier - kein zusaetzliches
Feature neben den bestehenden, sondern die Klammer darum.

---

## 1. Leitideen

**Landesrecht ist Pflichtstoff, aber nur das eigene.** Ein bayerischer
Kandidat lernt PAG und LStVG, nicht das ASOG Berlin. Landesrecht-Themen
tragen `topic.bundesland` und sind nur fuer Nutzer dieses Landes sichtbar -
in faelligen Karten, Coverage, Lernplan und Decks. Ohne Bundesland im Profil
sieht ein Nutzer gar kein Landesrecht, statt 16 Laender Stoff, den er nie
braucht.

**Die Klausurverteilung ist die ehrlichste Gewichtung.** Wo das Strafrecht
zwei von sieben Klausuren stellt (NW, BE, BB), wiegt ein Rueckstand dort
mehr als bei einer von sechs (BY, BW, HE, ...). Die Examensreife rechnet mit
dieser Verteilung, nicht mit einer pauschalen Drittelung.

**Ein Deck ist eine Auswahl, keine Kopie.** Kurs-Decks referenzieren Themen;
die Karten bleiben die eine Quelle in `content/`. Ein Fehler in einer Karte
wird an einer Stelle korrigiert, der Lernfortschritt bleibt (`content_hash`,
`docs/04-datenmodell.md`). "Massgeschneidert" heisst: dieselbe Themenliste,
ergaenzt um das Landesrecht des Nutzers, mit seinem Kartenzustand.

**Examensreife ist keine Note.** Sie zerfaellt in fuenf benannte
Komponenten, die einzeln sichtbar sind; der Gesamtwert ist ein gewichteter
Mittelwert mit offengelegter Formel. Leitprinzip 4 ("Ehrlichkeit vor
Motivation") und die Ampel-Regel aus `docs/11-designsystem.md` gelten
unveraendert - eine Farbe, keine Konfetti, keine Streaks.

**Struktur, die das Repetitorium verkauft, gratis.** Wochenrhythmus mit
festem Klausurtag, Phasen mit stabilem Vorbereitungsbeginn, Checkliste bis
zur Meldung: das ist, was ein Repetitorium neben dem Stoff liefert
(`docs/00-problemanalyse.md`, Challenge 5).

---

## 2. Was gebaut ist (Stand dieses PRs)

| Baustein | Wo | Status |
|---|---|---|
| 16 Bundesland-Profile (Klausurstruktur, Pruefungsamt, Termine, Freiversuch, Abschichtung, Hilfsmittel, Normenspiegel, Checkliste, Pruefliste) | `content/examen/bundeslaender/<code>.yaml` | vorhanden, Status `in-pruefung` |
| 32 Landesrecht-Themen (je Land: Polizei-/Ordnungsrecht, Landesrecht allgemein), 165 Karten | `content/landesrecht/<code>-*.yaml` | vorhanden, Status `in-pruefung` |
| Kurskatalog: 18 kanonische Kurse mit Lernzielen, Klausurformat, Themenliste, Landesrecht-Kategorien, fehlenden Themen | `content/examen/kurse/*.yaml` | vorhanden |
| 41 Universitaeten mit Staatsexamens-Studiengang, je mit Standard-Studienverlaufsplan | `content/examen/universitaeten/*.yaml` | vorhanden, Status `in-pruefung` |
| Loader, Validierung, Seed fuer die drei neuen Dateitypen und `topic.bundesland` | `backend/app/services/content.py` | vorhanden, CI-Validierung |
| Nutzerprofil: `User.bundesland`, `User.universitaet_slug`, `PATCH /auth/me` | `backend/app/models.py`, `api/v1/auth.py` | vorhanden |
| Sichtbarkeitsfilter fuer Landesrecht in `/cards/due`, `/progress/coverage`, `/plan`; `deck`-Filter in `/cards/due` | `api/v1/learn.py`, `api/v1/plan.py` | vorhanden |
| Examen-Service: Deck-Aufloesung, Examensreife, Schwachstellen, Klausurvorschlag, Phase, Checkliste | `backend/app/services/examen.py` | vorhanden |
| API `/v1/examen/*` (Bundeslaender, Universitaeten, Kurse, Deck, Cockpit) | `backend/app/api/v1/examen.py` | vorhanden |
| App: Examen-Tab mit Profil-Onboarding, Cockpit, Deck-Detail, Deck-Lernschleife, Klausurmodus | `app/lib/pages/examen_page.dart` | vorhanden |
| Tests | `backend/tests/test_examen.py` (18), `app/test/examen_page_test.dart` (4) | vorhanden |

**Nicht in diesem PR** (Abschnitt 8): menschliche Pruefung der Landesangaben,
lokale Modulnamen der Universitaeten, Pro-Gating des Examen-Reiters,
Offline-Cache fuer Cockpit und Decks, Migrationsskript fuer die neuen
Spalten (Runbook-Regel, `docs/22-deploy-runbook.md` Abschnitt 2.2).

---

## 3. Datenmodell und Content-Format

### 3.1 Bundesland-Profil

Eine Datei je Land unter `content/examen/bundeslaender/<code>.yaml`, oberste
Ebene `bundesland:`. Pflichtfelder: `code` (amtliches Kuerzel, eines von 16),
`name`, `stand`, `quellen`, `klausuren` mit `anzahl` und `verteilung`
(Summe muss `anzahl` ergeben - CI-Fehler sonst). Alles Weitere ist
strukturiert, aber frei erweiterbar, weil das Profil als JSON in
`bundeslaender.data` liegt:

```yaml
bundesland:
  code: NW
  name: Nordrhein-Westfalen
  klausuren:
    anzahl: 7
    dauer_minuten: 300
    verteilung: {zivilrecht: 3, strafrecht: 2, oeffentliches-recht: 2}
  abschichtung: {moeglich: true, beschreibung: "§ 12 JAG NRW ..."}
  landesrecht:
    schwerpunkte: [...]
    normenspiegel:
      polizei_generalklausel: "§ 8 Abs. 1 PolG NRW; § 14 Abs. 1 OBG NRW"
      verwaltungsverfahrensgesetz: "VwVfG NRW - Vollgesetz"
      individualverfassungsbeschwerde: "Ja - seit 2019, ..."
  checkliste:
    - {monate_vor_examen: 12, titel: "Meldefristen und Freiversuch pruefen", detail: "..."}
  pruefliste_redaktion: [...]
  redaktion: {status: in-pruefung, normzitate_geprueft: false}
```

Der **Normenspiegel** ist das Herzstueck: fuer jeden Baustein, den der
bundesrechtliche Content abstrakt behandelt (Generalklausel, Stoerer,
Standardmassnahmen, VwVfG, Kommunalverfassung, Bauordnung, Landesverfassungs-
gericht), die Fundstelle im jeweiligen Landesrecht. Daraus sind die
Landesrecht-Karten abgeleitet (3.2) und der Examen-Reiter zeigt ihn als
Nachschlagetabelle.

### 3.2 Landesrecht-Themen

Gewoehnliche Themen-Dateien (`docs/05-content-pipeline.md`) mit einem
zusaetzlichen Feld `topic.bundesland`. Slug-Konvention `<code klein>-<kategorie>`
mit zwei Kategorien:

- `polizei-ordnungsrecht`: Generalklausel, Standardmassnahmen (wo eine
  Fundstelle bekannt ist), Stoerer, Zustaendigkeitsverteilung, Vollstreckung -
  je 5-6 Karten.
- `landesrecht-allgemein`: Landes-VwVfG (Vollgesetz oder Verweisung),
  Landesverfassungsgericht und Individualverfassungsbeschwerde,
  Kommunalverfassung mit Hauptorganen, Bauordnung, Pflichtstoff-Uebersicht -
  je 5 Karten.

Die Konvention ist nicht Deko: `examen.deck_topic_slugs()` loest die
`landesrecht_kategorien` eines Kurses ueber sie in konkrete Themen auf, und
`load_content()` warnt, wenn ein Kurs eine Kategorie referenziert, fuer die
ein Land kein Thema hat. Ein Landesrecht-Thema fuer ein Land ohne Profil ist
eine Warnung, ein unbekanntes Kuerzel ein Fehler.

Was Landesrecht-Karten bewusst **nicht** sind: eine Kopie der bundesrecht-
lichen Karten mit ausgetauschter Norm. Der Aufbau (Ermaechtigungsgrundlage,
formelle/materielle Rechtmaessigkeit, Stoerer, Verhaeltnismaessigkeit) bleibt
im Thema `or-sicherheitsrecht-generalklausel-standardmassnahmen`; die
Landesrecht-Karte liefert die Fundstelle und die landesspezifische
Abweichung (Zweispurigkeit Ordnungsbehoerde/Polizei, Magistratsverfassung,
Popularklage, LVwG als Vollgesetz in SH).

### 3.3 Kurse und Decks

`content/examen/kurse/<slug>.yaml`, oberste Ebene `kurs:`. Ein Kurs ist ein
kanonischer Zuschnitt, wie ihn fast jede Fakultaet anbietet (BGB AT,
Schuldrecht AT, Strafrecht AT I, Staatsrecht II, ...), plus drei
Examenskurse je Rechtsgebiet. Felder: `title`, `area`, `semester_default`,
`beschreibung`, `lernziele`, `klausurformat` (Typ und Minuten),
`topic_slugs` (muessen existieren - CI-Fehler sonst), `landesrecht_kategorien`,
`fehlende_themen` (ehrlicher Hinweis auf P3-Stoff, der noch nicht in
`content/` liegt), `examenskurs`. Ein Kurs ohne Themen und ohne
Landesrecht-Kategorie ist ein Fehler: "ein leeres Deck ist kein
Vorbereitungsdeck".

Das **Deck** entsteht zur Laufzeit (`examen.resolve_deck()`): Themen des
Kurses + Landesrecht des Nutzers, je Thema Kartenstand (gesamt, begonnen,
reif, faellig), dazu Schemata und Faelle dieser Themen. `GET
/v1/cards/due?deck=<slug>` startet die normale FSRS-Lernschleife nur fuer
diese Themen - kein zweiter Kartenstapel, keine zweite Outbox, derselbe
Sync (`docs/02-architektur.md`, Abschnitt 4).

### 3.4 Universitaeten

`content/examen/universitaeten/<slug>.yaml`, oberste Ebene `universitaet:`.
Pflicht: `slug`, `name`, `bundesland` (muss ein Profil haben), `quellen`,
`kurse` (Liste aus `kurs` + `semester`, optional `titel_lokal`). Alle 41
Fakultaeten mit Staatsexamens-Studiengang sind angelegt (39 staatliche,
Bucerius Law School, EBS), jede mit dem kanonischen Standard-Studienverlaufs-
plan (Semester 1-7). Lokale Modulnamen und Semesterlagen sind **nicht**
verifiziert - Abschnitt 8.

Die Universitaet legt das Bundesland fest: `PATCH /auth/me` mit
`universitaet_slug` setzt `bundesland` mit, wenn keines mitgeschickt wird.
Wer in Muenchen studiert und in Hamburg Examen macht, setzt beides explizit.

### 3.5 Datenbank

Drei neue Tabellen (`bundeslaender`, `universitaeten`, `kurse`; Schluessel +
`data` JSON) und drei neue Spalten (`users.bundesland`,
`users.universitaet_slug`, `topics.bundesland`). Die Tabellen legt
`create_all` beim Start an; die Spalten **nicht** (`docs/22-deploy-runbook.md`,
Abschnitt 2.2). Vor dem Deploy dieses Standes einmalig:

```sql
ALTER TABLE users  ADD COLUMN bundesland VARCHAR(2);
ALTER TABLE users  ADD COLUMN universitaet_slug VARCHAR(160);
ALTER TABLE topics ADD COLUMN bundesland VARCHAR(2);
CREATE INDEX ix_users_bundesland  ON users (bundesland);
CREATE INDEX ix_topics_bundesland ON topics (bundesland);
```

---

## 4. Sichtbarkeit und Gewichtung

`examen.visible_topics_query(db, user)`: alle Themen mit `bundesland IS NULL`
plus die mit `bundesland == user.bundesland`. Angewendet in:

| Endpunkt | Wirkung |
|---|---|
| `GET /cards/due` | Faellige und neue Karten nur aus sichtbaren Themen; `deck=` schneidet weiter zu |
| `GET /progress/coverage` | Landesrecht anderer Laender fehlt in `topics`, `by_area` und `weighted_coverage` |
| `POST /plan` | Planer bekommt nur sichtbare Themen (`examen.topic_inputs`) |
| `GET /examen/kurse/{slug}/deck` | Landesrecht-Kategorien werden nur mit Bundesland aufgeloest, sonst `landesrecht_fehlt` |

Die Gewichtung je Rechtsgebiet (`examen.area_weights`) ist die normierte
Klausurverteilung des Landes; ohne Bundesland ein Drittel je Gebiet. Sie
geht in die Komponente "Wissen" der Examensreife und in die Auswahl des
naechsten Klausurfalls ein - **nicht** in `/progress/coverage`, dessen
Relevanz-Gewichtung unveraendert bleibt (das Dashboard zeigt Kartenreife,
der Examen-Reiter zeigt Examensreife; zwei Zahlen, zwei Fragen).

---

## 5. Examensreife

Fuenf Komponenten (`examen.readiness`), jede 0..1, jede mit `label`,
`value` (oder `null` = nicht messbar) und `detail`:

| Komponente | Gewicht | Definition | `null` wenn |
|---|---|---|---|
| Wissen | 0,35 | Reife-Anteil je Rechtsgebiet (nach Themenrelevanz, nur bundesrechtliche Themen), gewichtet nach Klausurverteilung | nie |
| Landesrecht | 0,10 | reife / gesamte Landesrecht-Karten des eigenen Landes | kein Bundesland |
| Anwendung | 0,25 | Anteil sichtbarer Faelle, deren beste Abgabe >= 4 Punkte ("ausreichend", JAP-Skala) erreicht hat | nie |
| Technik | 0,15 | Mittel der Strukturscores der letzten 5 Abgaben / 100 | keine Abgabe |
| Klausurpraxis | 0,15 | Abgaben im Modus `klausur` in den letzten 8 Wochen / 8, gedeckelt bei 1 | nie |

Gesamt = Summe (Gewicht x Wert) ueber die verfuegbaren Komponenten, geteilt
durch die Summe ihrer Gewichte. Die API liefert die tatsaechlich verwendete
Formel als String mit (`examensreife.formel`), die App zeigt sie an.
Die Reife-Definition fuer Karten ist dieselbe wie in `/progress/coverage`
(`stability >= 21` und `state == review`, `docs/13` Abschnitt 1.2).

Warum keine Kalibrierung gegen Examensnoten? Weil es keine Daten gibt. Die
Gewichte sind eine begruendete Setzung (Wissen und Anwendung tragen 60 %,
Technik und Praxis 30 %, Landesrecht 10 % als eigener Posten, damit er nicht
in "Wissen" untergeht). Sobald Nutzer echte Examensergebnisse zurueckmelden
(Fachschafts-Beta, `docs/28`), lassen sich die Gewichte pruefen. Bis dahin
gilt: Komponenten anzeigen, Formel offenlegen, Gesamtwert nicht als Prognose
verkaufen - im UI steht "Kein Notenersatz".

---

## 6. Der Examen-Reiter (App)

Fuenfter Tab in `HomeShell` (`Icons.school_outlined`), ein Aufruf
(`GET /v1/examen/cockpit`), von oben nach unten:

1. **Profil.** Ohne Bundesland oder Examensdatum steht der Editor oben:
   Bundesland, Universitaet (nach Land gefiltert; die Wahl einer Universitaet
   setzt das Land), Examenstermin (Datepicker), Tagesbudget. Mit Profil eine
   Zeile plus Bearbeiten-Stift. Das ist zugleich die erste UI fuer
   `User.exam_date`, das bisher nur per API setzbar war.
2. **Countdown und Phase.** Tage bis zum Examen, Phase mit Fortschrittsbalken
   und den drei Phasengrenzen. Der Vorbereitungsbeginn ist stabil
   (`examen.phase_info`: spaetestens 12 Monate vor dem Examen, fruehestens
   Registrierung), nicht der Aufrufzeitpunkt - das behebt den in `docs/13`
   Abschnitt 2.3 beschriebenen Aenderungsbedarf fuer den Reiter; `POST /plan`
   selbst rechnet weiterhin ab heute (unveraendert, eigenes Folgeticket).
3. **Examensreife.** Gesamtwert, Formel, fuenf Komponenten als
   `SubsumoProgressMeter` (nicht messbare als Text), danach die drei
   Rechtsgebiete mit "n Klausuren, Gewicht x %".
4. **Heute.** Bloecke des heutigen Plantags aus `generate_plan` (Wiederholung,
   neuer Stoff, Fall, Klausur, Puffer) mit Minuten, Rueckstandshinweis, die
   naechsten Tage kompakt. Nur mit Examensdatum.
5. **Naechste Klausur.** Naechster Samstag (`KLAUSUR_WEEKDAY`), Vorschlag aus
   dem schwaechsten Rechtsgebiet (Coverage-Defizit x Klausurgewicht), darin der
   schwerste noch nicht im Klausurmodus geschriebene Fall. "Klausur schreiben"
   oeffnet den Gutachten-Trainer mit `mode: klausur` - dieselbe Bewertung,
   aber die Abgabe zaehlt fuer die Klausurpraxis.
6. **Landesrecht-Deck.** Die Themen des eigenen Landes mit Reife und
   Direkteinstieg in die Lernschleife (`topic=`-Filter). Mit Hinweis auf den
   Redaktionsstatus.
7. **Kurs-Decks.** In der Reihenfolge des Studienverlaufsplans der
   Universitaet (ohne Universitaet: Katalog nach `semester_default`). Deck-
   Detail: Beschreibung, Klausurformat, Reife, "Deck lernen (n faellig)",
   Lernziele, Themen, Schemata, Faelle (oeffnen den Gutachten-Trainer),
   fehlende Themen, Landesrecht-Hinweis.
8. **Schwachstellen.** Aus den letzten 20 Abgaben: Themen mit den meisten
   verfehlten Pruefpunkten (mit Beispielen) und die haeufigsten Strukturfehler
   nach `Finding.code` (`docs/13` Abschnitt 3.2).
9. **Checkliste.** Die Checkliste des Landes, "jetzt dran" nach Restzeit
   markiert und nach vorn sortiert. Ohne Persistenz - bewusst, bis klar ist,
   ob Nutzer Haekchen wollen.
10. **Pruefung im Land.** Klausurstruktur, Pruefungsamt, Pruefungsordnung,
    Termine/Freiversuch/Abschichtung/Notenverbesserung, Hilfsmittel,
    Landesrecht-Schwerpunkte und Normenspiegel, Besonderheiten - als
    aufklappbare Abschnitte, mit "Angaben ohne Gewaehr"-Hinweis, solange der
    Status `in-pruefung` ist.

Deck-Lernschleife: `DeckReviewPage` setzt `AppState.activeDeck` und zeigt
den unveraenderten `ReviewPage`-Screen (inklusive Lesemodus); beim Verlassen
wird der Filter geloescht. Ein gefilterter Stapel wird nicht in den
Offline-Cache geschrieben, damit ein Offline-Start den vollen Stapel zeigt.

Design: Flaechen statt Schatten (Hero-Karten auf `surfaceContainerHighest`),
eine Fortschrittsfarbe, Outline-Icons, keine wertabhaengige Farbe
(`docs/25-ui-relaunch-brief.md`, Abschnitt 6 und 8.3; der Widget-Test
prueft, dass kein `CircleAvatar` auftaucht).

---

## 7. Redaktionsstatus und Pruefliste je Bundesland

Alle Bundesland-Profile, Landesrecht-Themen und Universitaeten tragen
`redaktion.status: in-pruefung` und `normzitate_geprueft: false`. Das ist
keine Formalie: Klausurzahlen, Termine, Freiversuchsregeln und
Paragraphennummern stammen aus Redaktionswissen, nicht aus einem Abgleich mit
der jeweils geltenden Fassung von JAG/JAPO und Landesgesetzen. Die App zeigt
das an ("Redaktionsstatus: in Pruefung", "Angaben ohne Gewaehr"), die CI
buendelt die 89 Warnungen zu einer Zeile je Verzeichnis.

Jedes Profil traegt eine `pruefliste_redaktion`; die Standardpunkte:

1. Zahl, Dauer und Verteilung der Aufsichtsarbeiten gegen JAG/JAPO pruefen
2. Hausarbeits-/Aktenvortragsanteil pruefen (ueberall als `false` gesetzt)
3. Pruefungstermine des laufenden Jahres beim Pruefungsamt abgleichen
4. Freiversuchs- und Notenverbesserungsregel (Semesterzahl, Fristen)
5. Zugelassene Hilfsmittel gegen die Hilfsmittelbekanntmachung
6. Alle Normzitate im Normenspiegel gegen die geltende Gesetzesfassung

Laender mit ausdruecklich markierten Unsicherheiten: **SN** (Paragraphen-
nummern in SaechsPVDG/SaechsPBG nach der Reform 2019), **NW**
(Abschichtungsregel im Detail), **BE** (Vollstreckungsverweis). Wo eine
Fundstelle nicht sicher war, nennt die Karte nur das Gesetz, keine Nummer -
lieber eine luecke als eine falsche Zahl auf einer Lernkarte.

Empfohlener Weg zur Freigabe: je Land eine Person mit Examen in diesem Land
(Fachschafts-Beta, `docs/28`) arbeitet die Pruefliste ab, korrigiert die
YAML-Datei und setzt `status: mensch-freigegeben` - genau der Prozess aus
`docs/08-ki-redaktion.md`, nur dass hier der Erstentwurf von einer
Coding-Session statt vom Collector-Agenten stammt. Zuerst die Laender mit
den meisten Fakultaeten (NW 6, BY 7, BW 5), dann der Rest.

---

## 8. Offene Punkte und Folgetickets

| Punkt | Warum offen | Vorschlag |
|---|---|---|
| Menschliche Pruefung der 16 Profile und 32 Landesrecht-Themen | kein Agent kann das Gate schliessen (`docs/12` Abschnitt 1.1) | Pruefliste je Land, Abschnitt 7; Reihenfolge NW, BY, BW |
| Lokale Modulnamen und Semesterlage je Universitaet | nicht recherchierbar ohne Fachschaftskontakt | `titel_lokal`/`semester` je Kurs nachtragen, Status auf `mensch-freigegeben` |
| Migrationsskript fuer die drei neuen Spalten | Runbook-Regel: `create_all` legt keine Spalten an | SQL aus Abschnitt 3.5 ins Deploy-Runbook, Alembic bleibt M3-Thema |
| Pro-Gating des Examen-Reiters | Produktvision zaehlt den adaptiven Lernplan zu Pro; die Paywall ist derzeit aus | Entscheidung mit `docs/19`: Cockpit frei, Klausurmodus und Decks Pro? |
| Offline-Cache fuer Cockpit und Decks | `AppState` cached nur Karten und Outbox | mit drift (M2) zusammen loesen |
| Checklisten-Haekchen persistieren | kein Bedarf nachgewiesen | nach Beta-Feedback |
| `POST /plan` mit stabilem Vorbereitungsbeginn | `docs/13` Abschnitt 2.3, hier nur im Cockpit umgesetzt | `phase_info` in `plan.py` wiederverwenden |
| Kurse ohne Content (ZPO, HGB, ArbR, FamR/ErbR, StPO, Bauplanungsrecht) | P3-Stoff, nicht in v1.0 (`docs/12`) | als `fehlende_themen` an den Examenskursen sichtbar; Kurse anlegen, sobald Themen existieren |
| Kalibrierung der Reife-Gewichte | keine Examensergebnisse | Rueckmeldung aus der Beta, dann Gewichte pruefen |
| Landesrecht-Faelle | nur Karten, keine Faelle mit Erwartungshorizont je Land | KI-Redaktion mit Landesrecht-Backlog, Prioritaet Polizeirecht BY/NW/BW |

---

## 9. Bezug zu bestehenden Dokumenten

- `docs/12-content-produktionsplan.md`: hebt die Ausklammerung des Landesrechts
  teilweise auf - fuer Normenkenntnis, nicht fuer Faelle.
- `docs/13-lernarchitektur.md`: Abschnitt 1.2 Option 2 (Anwendung in die
  Mastery einrechnen) ist hier als eigene Komponente statt als Formelaenderung
  umgesetzt; Abschnitt 2.3 (Phasenberechnung) fuer den Reiter geloest.
- `docs/05-content-pipeline.md`: drei neue Dateitypen, `topic.bundesland`,
  neue CI-Regeln.
- `docs/04-datenmodell.md`: drei neue Tabellen, drei neue Spalten.
- `docs/20-release-g2-bezahlstrecke.md`: Free-Tier-Limits wirken unveraendert
  auch auf Deck-Lernschleifen (dieselbe `/cards/due`-Quote).
