# Innovationsthesen — Halten, Ändern, Verwerfen

Löst [SUB-45](/SUB/issues/SUB-45), Spur T5 der
[Release-Roadmap](/SUB/issues/SUB-39#document-plan). `docs/01-produktvision.md`
behauptet: „Der Unterschied ist nicht die Feature-Liste, sondern die
Verzahnung." Diese These war bei Erstellung des Vision-Dokuments unbelegt.
Inzwischen liegen zwei Eingaben vor, die eine Prüfung erlauben:

- **T6 Marktanalyse** (`docs/14-marktanalyse.md`), Abschnitt 2/3: recherchierte
  Wettbewerbsdaten, Stand 14.09.2026.
- **T4 Lernarchitektur** (`docs/13-lernarchitektur.md`), Abschnitt 3: konkrete
  Implementierungsskizze für die Fehlertaxonomie, auf der die Verzahnungsthese
  technisch aufbaut.

Jeder Kandidat unten bekommt eine Entscheidung — Halten, Ändern oder
Verwerfen — mit Begründung. Jede gehaltene These bekommt ein Messkriterium,
gegen das sie nach Launch geprüft werden kann.

---

## 1. Struktur-Feedback in Millisekunden — **Halten**

`backend/app/services/gutachten.py` liefert einen regelbasierten,
deterministischen, offline lauffähigen Struktur-Check (Obersatz, Definition,
Subsumtion, Ergebnis, Gutachten- vs. Urteilsstil) — fertig, kein LLM nötig
(`docs/13-lernarchitektur.md`, Abschnitt 1.3).

**Prüfung der im Ticket gestellten Frage — ist das sichtbar genug?** Ja,
inzwischen an drei Stellen:

1. **Im Produkt:** `app/lib/pages/gutachten_page.dart` zeigt die Checkpoints
   inkl. Rückführung jedes Abzugs auf einen Prüfpunkt.
2. **In der Außendarstellung:** `docs/21-landing-preisseite-launchtext.md`
   führt den „Struktur-Check" als eigenständiges, mehrfach wiederholtes
   Verkaufsargument (u. a. Abschnitte 2.1, FAQ, Preistabelle) — nicht als
   Fußnote zur KI-Korrektur, sondern als Feature, das unabhängig von deren
   AVV-Status funktioniert.
3. **Im Geschäftsmodell:** Bereits im kostenlosen Free-Tier „unbegrenzt"
   (`docs/01-produktvision.md`, Geschäftsmodell), im Pro-Tier ohne Limit
   gegenüber 3 Struktur-Checks/Woche im Free-Tier
   (`docs/21-landing-preisseite-launchtext.md`, Preistabelle) — das Feature
   trägt bereits eine Konversionsfunktion.

**Warum halten, obwohl die KI-Korrektur laut Marktanalyse kein
Alleinstellungsmerkmal mehr ist:** Der Struktur-Check ist der einzige Teil des
Korrektur-Angebots, der ohne AVV, ohne LLM-Kosten und ohne
Kalibrierungsrisiko sofort und für alle Nutzer funktioniert
(`docs/18-release-2-wochen.md`, Abschnitt 2). Er ist damit in v1.0 kein
Nice-to-have neben der eigentlichen These, sondern trägt sie in der Phase, in
der die KI-Korrektur bedingt ist.

**Messkriterium:** Anteil aktiver Free-Tier-Nutzer, die mindestens einen
Struktur-Check pro Woche nutzen, sowie Konversionsrate Free → Pro unter
Nutzern, die das wöchentliche Struktur-Check-Limit erreichen. Ziel: klar
höhere Pro-Konversion in dieser Gruppe als im Nutzerdurchschnitt — sonst zieht
das Feature keine Zahlungsbereitschaft, sondern wird nur konsumiert.

---

## 2. Verzahnung — **Halten, aber konkretisiert**

### Befund aus der Marktanalyse

`docs/14-marktanalyse.md`, Abschnitt 3, widerlegt die Verzahnungsthese nicht,
sondern präzisiert, wogegen sie überhaupt antritt: Die KI-Korrektur allein
differenziert nicht mehr (Constellatio, KorrekturKai, KlausurenKiste bieten
sie bereits an). Aber **bei keinem der drei Anbieter ist die Kette
Karte → Schema → Fall → Korrektur → Wiederholung in einem System belegt** —
Constellatio kombiniert Korrektur mit Karten/Lexikon, aber ohne belegte
Rückkopplung von Fehlern in neue Wiederholungskarten; KorrekturKai und
KlausurenKiste sind reine Korrektur-Insellösungen ohne Karteikarten-Ökosystem.
Die These ist also nicht durch den Markt entwertet — sie ist der Teil der
alten Positionierung, der noch trägt, während die KI-Korrektur selbst das
nicht mehr allein tut.

### Befund aus der Lernarchitektur: bisher nur implizit, nicht gebaut

`docs/13-lernarchitektur.md`, Abschnitt 1.1, stellt fest, dass die im
Vision-Dokument behauptete Verzahnung im Code heute **nicht existiert**:
`Card`, `Schema` und `Case` teilen sich nur ein gemeinsames `topic_slug`
(`backend/app/models.py:123,179,200`), es gibt keine Fremdschlüsselkette und
keinen Mechanismus, der aus einem konkreten Fehler in einem Fall eine
konkrete Wiederholungskarte erzeugt. Die These aus der Produktvision war zum
Zeitpunkt ihrer Formulierung ein Zielbild, keine Beschreibung des Codes.

### Entscheidung: Halten, aber auf den in T4 entworfenen, minimal nötigen Umfang konkretisiert

Verwerfen wäre falsch, weil die Marktanalyse zeigt, dass genau hier die Lücke
liegt, die kein Wettbewerber schließt. Unverändert halten wäre unehrlich,
weil die These bisher nicht mehr als eine Behauptung in einem Vision-Dokument
ist. Die Konkretisierung aus `docs/13-lernarchitektur.md`, Abschnitt 3.2/3.3,
beantwortet die im Ticket gestellte Frage „wie wäre das implementiert, was
kostet es":

- **Implementierung:** `Pruefpunkt` bekommt ein additives Feld `card_slugs`
  (Vorschlag, nicht umgesetzt: `evaluator.py`, YAML-Contentformat,
  `content.py`-Validierung). Verfehlt ein Nutzer einen Prüfpunkt
  (`pruefpunkt_verfehlt`), werden die verlinkten Karten sofort fällig
  gesetzt; verfehlt er einen Pflichtprüfpunkt
  (`pruefpunkt_verfehlt_pflicht`), zusätzlich auf `relearning` zurückgesetzt
  (`docs/13-lernarchitektur.md`, Tabelle in Abschnitt 3.2). Das ist die
  wörtliche Umsetzung von „ein Fehler im Fall erzeugt eine
  Wiederholungskarte".
- **Kosten:** Additiv und ohne Breaking Change — bestehende Fälle ohne
  `card_slugs` fallen auf die heutige reine Textrückmeldung zurück. Die
  Zuordnung Prüfpunkt → Karte ist überwiegend redaktioneller Aufwand (die
  Redaktion kennt die Karten eines Themas beim Schreiben eines Falls
  ohnehin), nicht primär Backend-Aufwand. Nicht enthalten ist die
  themenübergreifende Technik-Karten-Ebene für Kategorie-A-Fehler (z. B.
  Urteilsstil) — die verlangt einen neuen `Area`-Wert und einen eigenen
  Inhaltsblock (`docs/13-lernarchitektur.md`, Abschnitt 3.3, Option 1) und
  ist explizit als Folgeticket nach Gate B eingeplant, nicht Teil dieser
  Konkretisierung.
- **Abgrenzung zu v1.0:** `Pruefpunkt.card_slugs` ist in
  `docs/13-lernarchitektur.md`, Abschnitt 6, Punkt 7, als „Ja — Voraussetzung
  für die Kernthese" markiert, aber die inhaltliche Bewertung
  (`evaluator.py`), an die dieser Mechanismus hängt, läuft in v1.0 ohnehin nur
  heuristisch (`llm_provider=none`, `docs/18-release-2-wochen.md`, Abschnitt
  2). Die Verzahnung ist damit **v1.1-Umsetzung, sobald die KI-Korrektur
  aktiviert wird** (bedingt am AVV, siehe dort) — keine v1.0-Anforderung, aber
  auch keine, die auf unbestimmte Zeit vertagt werden sollte, weil sie laut
  Marktanalyse der tragfähigere Teil der Differenzierung ist als die
  KI-Korrektur selbst.

**Messkriterium:** Anteil der über `card_slugs` erzeugten
Wiederholungskarten, die beim nächsten Fälligkeitstermin korrekt beantwortet
werden (`Review.rating != AGAIN`), verglichen mit der allgemeinen
Erstantwort-Erfolgsquote neuer Karten desselben Kartentyps. Zusätzlich:
Anteil der Nutzer mit ≥ 2 Abgaben desselben Falls, bei denen derselbe
Prüfpunkt beim zweiten Versuch nicht mehr verfehlt wird (Anschluss an Metrik
2 aus `docs/13-lernarchitektur.md`, Abschnitt 5.2). Beide sollten spürbar über
dem Zufallsniveau liegen — sonst erzeugt die Verzahnung zwar Karten, aber
keinen Lerneffekt, und die These wäre trotz Implementierung nicht belegt.

### Nachtrag (SUB-261, 24.09.2026): Kopplung an die KI-Korrektur/AVV widerlegt

Die „Abgrenzung zu v1.0" oben nahm an, die Verzahnung hänge an der
*inhaltlichen* Bewertung und laufe deshalb erst „v1.1-Umsetzung, sobald die
KI-Korrektur aktiviert wird". Verifikation am Code (`backend/app/services/
evaluator.py:159-235`, `backend/app/api/v1/gutachten.py:56-93`) widerlegt
diese Kopplung: Der Auslöser des Mechanismus ist nicht die LLM-Bewertung,
sondern ein *verfehlter Prüfpunkt* — und `HeuristicEvaluator.evaluate()`
erzeugt für jeden nicht getroffenen Prüfpunkt bereits heute ein
`PruefpunktResult(hit=False)`, per Stichwort-/Normabgleich, vollständig
offline und unabhängig davon, ob ein LLM-Provider konfiguriert ist oder der
Nutzer der KI-Auswertung zugestimmt hat (`get_evaluator()`,
`evaluator.py:350-361`, läuft in v1.0 ohnehin ausschließlich heuristisch,
`llm_provider=none`). `submit_case` (`gutachten.py:76-79`) ruft diesen
Evaluator bei **jeder** Abgabe auf, ganz ohne AVV-Bezug.

Der Kreis Prüfpunkt → Karte lässt sich also **ohne AVV schließen** — die
Heuristik erkennt nur *ob* ein Stichwort/eine Norm vorkommt, nicht ob die
Argumentation trägt, ist also schwächer in der Trefferquote als die
LLM-Variante, aber funktionsfähig (`docs/13-lernarchitektur.md`, Abschnitt
1.3, zur Deckelung der Heuristik). Die Konsequenzseite ist ebenfalls klein:
`UserCard.state`/`due` (`backend/app/models.py:147,151`) tragen bereits die
Zustände `due=jetzt` und `RELEARNING`, die `docs/13` Abschnitt 3.2 für die
Konsequenz vorsieht.

**Neue Einordnung:** Nicht mehr „v1.1, an KI-Korrektur-Aktivierung gekoppelt",
sondern **AVV-unabhängig, aber weiterhin nach dem v1.0-Freeze** — SUB-261
selbst ordnet die Umsetzung explizit „nach Release, nicht vor dem Freeze" ein,
unabhängig vom Ausgang des AVV-Stichtags 27.09.2026 (der Stichtag betrifft nur
die inhaltliche Trefferquote der KI-Korrektur, nicht ob dieser Mechanismus
überhaupt gebaut werden kann). Umsetzungsschnitt (Backend, Contentformat,
Validierung, Redaktion) ist als Folgetickets vorbereitet, siehe
SUB-261-Kommentar.

---

## 3. Nachvollziehbare Korrektur (Punktabzug klickbar) — **Halten**

Bereits implementiert: `evaluator.py` liefert `checkpoints` je Prüfpunkt
(`PruefpunktResult.hit`, `docs/13-lernarchitektur.md`, Abschnitt 1.3), und
`app/lib/pages/gutachten_page.dart:437-462` rendert jeden Checkpoint mit
Rückführung auf den zugehörigen Prüfpunkt — der Kommentar im Code
(`gutachten_page.dart:460`) benennt die These wörtlich: „Jeder Punktabzug ist
auf einen Pruefpunkt zurueckfuehrbar". Das gilt bereits für die heutige
Heuristik (gedeckelt auf 11 von 18 Punkten,
`evaluator.py::HEURISTIK_MAX_PUNKTE`) und unverändert nach Aktivierung der
KI-Korrektur.

**Warum halten:** Der Vertrauensvorteil gegenüber Blackbox-KI, den das Ticket
unterstellt, ist real und wettbewerbsrelevant. Bei keinem der drei
KI-Korrektur-Anbieter aus der Marktanalyse (Constellatio, KorrekturKai,
KlausurenKiste) ist eine vergleichbare Struktur belegt — KorrekturKai bietet
stattdessen ein menschliches Remonstrationsrecht als Vertrauensmechanismus
(`docs/14-marktanalyse.md`, Abschnitt 2), was auf denselben Bedarf hindeutet,
den Subsumo hier bereits im UI löst. Anders als bei der Verzahnung (Punkt 2)
ist hier kein weiterer Implementierungsschritt nötig, nur die Fortführung
nach Aktivierung der KI-Korrektur.

**Messkriterium:** In Nutzerbefragung (Anschluss an Interviewleitfaden
`docs/14-marktanalyse.md`, Abschnitt 5, Fragen zu Vertrauen/Nachvollziehbarkeit)
Anteil Zustimmung zur Aussage „Ich verstehe, warum ich Punkte verloren habe"
nach Nutzung. Ziel: deutlich über 80 % — bei niedrigerer Zustimmung trägt die
Klickbarkeit allein den behaupteten Vertrauensvorteil nicht, und das
UI-Konzept müsste überarbeitet werden, nicht nur beworben.

---

## 4. Offline-5h-Klausur inklusive Windows — **Halten, Zeitpunkt v1.1**

### Marktbefund

`docs/14-marktanalyse.md`, Abschnitt 3, bestätigt die Lücke unverändert: Bei
keinem der geprüften Wettbewerber (auch nicht bei den drei
KI-Korrektur-Anbietern) ist ein **nativer, plattformübergreifender
5-Stunden-Offline-Klausursimulator mit Pacing/Ablenkungssperre** belegt — alle
wirken als Web-Einreichungstools für bereits fertige Texte. Jurafuchs hat ein
separates Klausurportal (Beta, 3.445 Klausuren), aber ohne belegtes Pacing
oder Lockdown; Constellatio hat dafür keinen Beleg. Das ist damit die
seltenste, am schwersten kopierbare der vier Thesen — genau deshalb aber auch
die teuerste.

### Aufwand vs. Nutzen

Laut `docs/03-roadmap.md`, M4, ist der Klausur-Simulator (300-Minuten-Modus,
Pacing-Leiste, Auto-Save, Ablenkungssperre, offline) mit 4 Wochen veranschlagt
— der teuerste Einzelblock nach der Content-Produktion. Der ursprüngliche
Risikopunkt „Flutter-Web-Texteditor untauglich für 5-h-Klausur" ist bereits
vorab entkräftet (Spike in M0+, GO-Ergebnis 48 ms Ø-Latenz,
`docs/07-spike-web-editor.md`, referenziert in `docs/03-roadmap.md:225`) — das
senkt das technische Restrisiko, nicht den Aufwand selbst.

**Trägt sie den Aufwand?** Ja, unter einer Bedingung: nicht in v1.0.
`docs/18-release-2-wochen.md` weist den Simulator bereits explizit v1.1 zu
(Nachtrag 16.09.2026 in `docs/01-produktvision.md` und
`docs/14-marktanalyse.md`, Abschnitt 3) — diese These bestätigt diese
Entscheidung, ändert sie aber nicht. Der Aufwand (M4, 4 Wochen) ist in der
Zwei-Wochen-Frist für v1.0 ohnehin nicht darstellbar; die Frage ist also nicht
„jetzt oder nie", sondern „v1.1 oder verwerfen". Verwerfen wäre falsch, weil
die Lücke laut Marktanalyse real ist und mit steigendem Wettbewerbsdruck bei
der KI-Korrektur (die inzwischen drei Anbieter haben) genau das Merkmal wird,
das am längsten hält, weil es am aufwendigsten nachzubauen ist.

**Messkriterium:** Nach Verfügbarkeit in v1.1 — Anteil zahlender Pro-Nutzer,
die den Simulator mindestens einmal vor einer echten Klausurphase nutzen,
sowie in der Kündigungsbefragung (falls vorhanden) Anteil, der den Simulator
explizit als Grund für den Verbleib nennt. Ziel: der Simulator sollte in den
ersten zwei Examens-Zyklen nach Launch als eigenständiger Bindungsgrund
sichtbar werden — sonst rechtfertigt er die 4 Wochen Aufwand nicht gegenüber
alternativen Investitionen (z. B. Content-Ausbau, M6).

---

## 5. Ausdrücklich nicht verfolgt

Das Ticket benennt drei Kandidaten, die bewusst nicht weiterverfolgt werden.
Die Begründung dafür ist Teil der Abnahme dieses Dokuments, nicht nur der
Ticketbeschreibung, und wird hier bestätigt statt nur wiederholt:

- **KI-Chatbot als Tutor — Verwerfen.** Austauschbar (jeder Anbieter mit
  LLM-Zugang kann das bauen, kein Vorsprung), mit Halluzinationsrisiko im
  Rechtsbereich, das gegen Leitprinzip 4 („Ehrlichkeit vor Motivation",
  `docs/01-produktvision.md`) läuft, und ohne erkennbaren Burggraben. Die
  Marktanalyse liefert keinen Hinweis, der das relativiert — im Gegenteil,
  DeepWrite (BMBF-Forschungsprojekt Uni Passau zu KI-Klausurbewertung,
  `docs/14-marktanalyse.md`, Abschnitt 2) zeigt, dass selbst Hochschulen an
  vergleichbaren Themen arbeiten, ohne dass daraus ein Produktvorteil für
  einen zusätzlichen Chatbot folgt.
- **Gamification-Ausbau — Verwerfen.** Widerspricht direkt Leitprinzip 5
  („Kein Druck durch Design. Streaks brechen nicht an einem Krankheitstag",
  `docs/01-produktvision.md`). `docs/13-lernarchitektur.md`, Abschnitt 2.4,
  bestätigt, dass im Code bewusst kein Streak-Zähler existiert — das ist
  keine Lücke, sondern konsistent umgesetztes Produktdesign. Ausbau in diese
  Richtung wäre eine Rücknahme einer bereits getroffenen, begründeten
  Entscheidung, kein Fortschritt.
- **Video-Content — Verwerfen.** Fremde Kernkompetenz gegenüber den
  etablierten Repetitorien (hemmer, Alpmann Schmidt, Jura Intensiv), die laut
  `docs/14-marktanalyse.md`, Abschnitt 2, ihr gesamtes Geschäftsmodell auf
  Präsenz-/Video-Lehre aufbauen. Subsumo würde dort antreten, wo etablierte
  Anbieter am stärksten sind, statt dort, wo die Marktanalyse eine Lücke
  zeigt (Verzahnung, Offline-Klausur).

---

## 6. Zusammenfassung

| # | These | Entscheidung | Zeitpunkt | Messkriterium |
|---|---|---|---|---|
| 1 | Struktur-Feedback in Millisekunden | Halten | bereits live (v1.0) | Nutzungsrate + Free→Pro-Konversion bei Vielnutzern des Limits |
| 2 | Verzahnung (Fehler → Wiederholungskarte) | Halten, konkretisiert auf `Pruefpunkt.card_slugs` | nach v1.0-Freeze, **AVV-unabhängig** (SUB-261, Nachtrag 24.09.2026) | Erfolgsquote der erzeugten Wiederholungskarten vs. Baseline; wiederholte Prüfpunkt-Fehler sinken |
| 3 | Nachvollziehbare Korrektur (Punktabzug klickbar) | Halten | bereits live (v1.0) | Zustimmung „verstehe Punktabzug" in Nutzerbefragung > 80 % |
| 4 | Offline-5h-Klausur inkl. Windows | Halten | v1.1 (M4, 4 Wochen) | Nutzung vor Klausurphasen + Nennung als Bindungsgrund |
| — | KI-Chatbot als Tutor | Verwerfen | — | — |
| — | Gamification-Ausbau | Verwerfen | — | — |
| — | Video-Content | Verwerfen | — | — |

**Fazit für die Positionierung:** Von den vier ursprünglichen Kandidaten
tragen nach der Marktanalyse zwei die alte Erwartung nicht mehr allein
(Struktur-Feedback und nachvollziehbare Korrektur sind wertvoll, aber nicht
mehr exklusiv, sobald Wettbewerber nachziehen), während die beiden
aufwendigsten — Verzahnung und Offline-Klausur — laut Recherche die einzigen
sind, die kein Wettbewerber belegt anbietet. Das deckt sich mit der in
`docs/14-marktanalyse.md`, Abschnitt 3, formulierten präzisierten
Positionierung: nicht „wir haben KI-Korrektur", sondern die Kombination aus
Korrektur, Verzahnung und Offline-Klausursimulator im selben System — nur
dass diese Kombination laut `docs/18-release-2-wochen.md` erst mit v1.1
vollständig steht, nicht mit v1.0. Für die Verzahnung gilt seit der
Verifikation in SUB-261 (Nachtrag zu Punkt 2, 24.09.2026) einschränkend: der
Zeitpunkt „v1.1" ist eine Umsetzungsentscheidung (nach dem v1.0-Freeze), keine
technische Abhängigkeit vom AVV-Ausgang mehr — die KI-Korrektur-Bedingung aus
`docs/18-release-2-wochen.md` betrifft nur die inhaltliche Trefferquote, nicht
den Verzahnungsmechanismus selbst.

## Quellen

- `docs/01-produktvision.md` (ursprüngliche Verzahnungsthese, Leitprinzipien)
- `docs/14-marktanalyse.md`, Abschnitt 2–3 (Wettbewerbsbefunde,
  Positionierung)
- `docs/13-lernarchitektur.md`, Abschnitt 1.1, 1.3, 3.2, 3.3, 5.2, 6
  (Implementierungsstand, Fehlertaxonomie, Kosten der Verzahnung)
- `docs/18-release-2-wochen.md`, Abschnitt 2, 2.1 (v1.0-Schnitt,
  KI-Korrektur-Bedingung)
- `docs/03-roadmap.md`, M4, Risikotabelle (Aufwand Klausur-Simulator)
- `backend/app/services/gutachten.py`, `backend/app/services/evaluator.py`,
  `backend/app/models.py`
- `app/lib/pages/gutachten_page.dart:437-462`
- `docs/21-landing-preisseite-launchtext.md` (Sichtbarkeit Struktur-Check in
  der Außendarstellung)
