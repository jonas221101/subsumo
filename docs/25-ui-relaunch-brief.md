# UI-Relaunch: Design-Brief

> Lieferung zu [SUB-227](/SUB/issues/SUB-227), Kind von [SUB-224](/SUB/issues/SUB-224)
> ("Front end und user interface sehen immernoch sehr langweilig aus").
> **Kein Code in diesem Dokument** — reine Design-Richtung, damit drei
> Entwickler (Token-Ebene, öffentliche Seiten, App-Screens) parallel arbeiten
> können, ohne sich zu widersprechen. Bindend erst nach Freigabe über die
> `request_confirmation`-Interaktion auf SUB-227, die auf diese Revision
> zeigt.

---

## 1. Der Zielkonflikt — Entscheidung

`docs/11-designsystem.md` und `docs/01-produktvision.md` (Leitprinzipien 4/5,
"Ehrlichkeit vor Motivation", "Kein Druck durch Design") legen bewusst eine
zurückhaltende Gestaltung fest. Der Eigentümer-Wunsch nach einem "spannenden
Design" kollidiert damit auf den ersten Blick. Auflösung:

**Die Leitprinzipien 4/5 schützen die Lernsituation, nicht die
Marketingfläche.** "Kein Druck durch Design" heißt: kein Ampel-Lernstand,
keine Streak-Mechanik, kein Konfetti — das ist eine Aussage über
*Fortschrittsanzeigen innerhalb des Produkts*, nicht über die Optik der
Landingpage. Eine Landingpage, die für ein zahlungspflichtiges Produkt gegen
finanzierte Wettbewerber (Jurafuchs, Constellatio, `docs/14-marktanalyse.md`)
antritt, darf und soll überzeugender aussehen, ohne dass das ein Bruch der
Produktvision ist.

Ich übernehme die Arbeitsannahme des Coordinators mit einer Präzisierung:

- **Öffentliche Flächen (Landing, Preise, Login-Rahmen, Rechtstexte-Rahmen):
  deutlich mutiger.** Vollbreite Farbbänder, ein tragender Hero, Bewegung
  beim Scrollen. Begrenzung: **Design darf laut sein, Text bleibt ehrlich.**
  Die in `docs/21-landing-preisseite-launchtext.md` Abschnitt 1 festgelegten
  redaktionellen Leitplanken (keine Superlative zum Umfang, keine erfundene
  Dringlichkeit/Verknappung, keine KI-Werbung für den Struktur-Check) gelten
  unverändert — die Wortwahl bleibt sachlich, nur die visuelle Bühne wird
  größer. Die Launch-Texte selbst ändern sich in diesem Ticket **nicht**
  (siehe Abschnitt 3).
- **App-Screens (Dashboard, Karteikarten, Gutachten, Klausur — Klausur-
  Simulator existiert laut `docs/03-roadmap.md` erst ab v1.1, hier nur als
  Prinzip mitgeführt): mehr gestalterisches Handwerk, keine Gamification.**
  Siehe Abschnitt 5. Das Ampel-Verbot (`SubsumoProgressMeter`, Abschnitt 6
  in docs/11) ist **nicht verhandelbar** und bleibt unverändert bestehen.

---

## 2. Referenzen (3–5 Websites, je EINE übernommene Sache)

Der Eigentümer hat Orientierung an anderen Websites ausdrücklich erlaubt.
Keine der folgenden Referenzen wird als Ganzes kopiert — pro Referenz wird
genau ein strukturelles Element übernommen und unten in Abschnitt 3/4
konkretisiert.

| Referenz | Übernommene Sache |
|---|---|
| **stripe.com** | Sektionswechsel über vollbreite, unterschiedlich eingefärbte Bänder statt einer durchgehend weißen Spalte — der wichtigste strukturelle Hebel gegen den "Word-Dokument"-Befund. |
| **linear.app** | Ein großer, knapper Hero-Satz in einer deutlich größeren Displaygröße (60px+) statt vieler gleich großer Textblöcke — Aufmerksamkeit durch Kontrast in der Typoskala, nicht durch mehr Text. |
| **claude.com (Anthropic)** | Eine charaktervolle Display-/Serifenschrift ausschließlich für Marketing-Überschriften, kombiniert mit einer neutralen Grotesk für Fließtext — Vorbild für die Schriftentscheidung in Abschnitt 4, nicht für den Fließtext selbst. |
| **vercel.com** | Abstrakte geometrische Verlaufsflächen als Sektionshintergrund/-trenner statt Fotos oder Illustrationen — Vorbild für die Bildsprache-Entscheidung in Abschnitt 5. |
| **notion.so** (Marketingseite) | Rhythmus aus dichten Feature-Grids und bewusst leeren, ruhigen Zwischensektionen statt gleichmäßiger Textdichte auf der ganzen Seite — Vorbild für den Sektionsrhythmus in Abschnitt 3. |

Bewusst **nicht** als Referenz: Duolingo/Anki-artige Lern-Apps mit
Gamification-Ästhetik (Streak-Zähler, Maskottchen, Konfetti) — das ist genau
das Gegenteil dessen, was für App-Screens gilt (Abschnitt 5).

---

## 3. Landingpage: Sektion für Sektion

Voraussetzung für alle Sektionen: `PublicScaffold` hört auf, jede Seite
pauschal auf `maxWidth: 720` zu zwingen (`public_scaffold.dart`). Neue
Komponente **`SubsumoSection`**: ein randloses Band mit eigener
Hintergrundfläche (Farbe/Verlauf), das seinen Inhalt weiterhin über
`ReadableWidth` innen begrenzt. `PublicScaffold` reicht nur noch AppBar,
Footer und die Fensterbreite durch — jede Sektion entscheidet selbst über
ihre Hintergrundfarbe.

**Ein einziger Breakpoint für alle Zweispalten-/Mehrspalten-Wechsel:
800px**, identisch mit dem bereits bestehenden `HomeShell`-Breakpoint
(`main.dart`, Wechsel `NavigationBar` → `NavigationRail`). Kein neuer,
zweiter Breakpoint-Wert — Konsistenz über die App hinweg ist wichtiger als
ein auf die Landingpage optimierter Wert.

Die Texte in `docs/21-landing-preisseite-launchtext.md` Abschnitt 2.2 sind
wortgleich und ändern sich **nicht** — das hier ist ausschließlich Layout.

1. **Hero.** Vollbreites Band, Verlauf `brand700` → `brand900` (bestehende
   Tokens). ≥800px: zweispaltig — links H1 (neue `heroLarge`-Rolle, siehe
   Abschnitt 4) + Subheadline + beide CTAs untereinander, rechts eine
   abstrakte Grafik (Subsumtions-Klammer-Motiv, siehe Abschnitt 5).
   <800px: einspaltig gestapelt, Grafik entfällt oder wird stark verkleinert
   als Hintergrundtextur hinter dem Text (nie über dem Text, sonst
   Kontrastrisiko). Text durchgehend `onPrimary`-Rolle (weiß) — Kontrast
   gegen `brand900` muss in docs/11 Abschnitt 5 neu nachgerechnet werden
   (gegen `brand700` ist er das bereits, 11.48:1, aber nicht gegen den
   dunkleren Verlaufsendpunkt).
2. **Für wen.** Flächenfarbe `surface0` (neutral, bewusst ruhiger
   Gegenpunkt nach dem Hero). Einspaltig, zentriert, max. Lesebreite,
   etwas größere Textrolle als aktuell `bodyMedium` (z. B. `titleMedium`),
   damit der eine Satz nicht wie eine Fußnote wirkt.
3. **Was du heute bekommst.** Flächenfarbe `surface1`. ≥800px: 2×2-Grid der
   vier Bullet-Punkte (Icon in `accent`-Kreisfläche + Überschrift + Text),
   <800px: einspaltig gestapelt. Icons bleiben Outline-Icons (Abschnitt 5),
   nur größer (32–40px) als der aktuelle Fließtext-Icon-Einsatz. Der
   Struktur-Check-Abgrenzungssatz ("Lernhilfe, keine Rechtsberatung, keine
   Note") bleibt als eigener, nicht im Grid versteckter Absatz darunter.
4. **Wie es funktioniert.** Flächenfarbe `surface0`. ≥800px: die drei
   Schritte horizontal nebeneinander mit verbindender Linie/Pfeil,
   <800px: nummeriert gestapelt (heutiges Layout).
5. **Ehrlich über den Umfang.** Eigene, bewusst abgesetzte Fläche: sehr
   heller `accent500`-Wash über `surface0` (Deckkraft niedrig genug, dass
   der Fließtextkontrast nicht spürbar sinkt — vor Umsetzung nachrechnen,
   nicht annehmen). Zweck: diese Sektion ist inhaltlich die ehrlichste
   Stelle der Seite (180 Karten, nicht Tausende) — sie bekommt eine eigene,
   ruhige Bühne statt im Fluss unterzugehen. Einspaltig, zentriert,
   `Ehrlichkeit vor Motivation` visuell unterstrichen statt konterkariert.
6. **Die drei Rechtsgebiete.** Flächenfarbe `surface1`. ≥800px: die drei
   Karten aus dem heutigen `Wrap` werden zu einer festen 3-Spalten-Reihe,
   <800px: gestapelt (heutiges Verhalten bleibt). Jede Karte bekommt einen
   schmalen oberen Farbakzent, der das Rechtsgebiet **kategorisch**
   unterscheidet (drei feste, wertunabhängige Farbtöne aus der bestehenden
   Palette, z. B. `brand500`/`accent500`/`ink500` je Gebiet) — ausdrücklich
   **keine** Bewertung, nur Wiedererkennung. Das ist keine Ampel, weil sie
   nichts über Lernstand aussagt, sondern nur, welches Gebiet gemeint ist.
7. **Preis-Teaser.** Flächenfarbe `surface0`. ≥800px: Free- und
   Pro-Kurzvergleich als zwei nebeneinanderliegende Karten statt Fließtext
   in zwei Absätzen, <800px: gestapelt. Die Pro-Karte hebt sich über einen
   2px-Rahmen in `accent`-Farbe und `surface2` statt `surface1` ab — **keine**
   neue Elevation-Stufe (Begründung docs/11 Abschnitt 2.4 bleibt gültig,
   starke Schatten wirken auf einer textlastigen Seite unruhig).
8. **FAQ.** Flächenfarbe `surface1`. Wird zu einem Akkordeon
   (`ExpansionTile` o. ä.) statt drei permanent sichtbaren Text-Blöcken —
   reduziert die visuelle Dichte am Seitenende. Text pro Frage/Antwort
   bleibt wortgleich, nur initial eingeklappt (erste Frage optional
   voreingeklappt geöffnet, damit der wichtigste FAQ-Punkt — "ist das KI?"
   — nicht versteckt wirkt).
9. **Footer.** Flächenfarbe `brand900` (dunkler Bookend-Kontrast zum Hero),
   Linktext in einer hellen, kontrastgeprüften Rolle. Struktur unverändert
   (`PublicFooter`, fünf Rechtstexte-Links).

Gleiche Sektions-Logik (Bänder statt Einheitsspalte) gilt für die Preisseite
(`public_pricing_page.dart`) und den äußeren Rahmen von Login/Rechtstexten —
nicht Teil dieser detaillierten Sektionsbeschreibung, aber gleiche
`SubsumoSection`-Komponente.

---

## 4. Zweite Schriftfamilie — Entscheidung: ja, scoped

**Fraunces** (SIL Open Font License 1.1, Google Fonts, "The Fraunces Project
Authors" — https://fonts.google.com/specimen/Fraunces). Als Variable- oder
Static-Font-Datei selbst hostbar (wie `Subsumo`/DejaVu Sans bereits heute),
also **keine** Laufzeit-Abhängigkeit von `fonts.gstatic.com` — vereinbar mit
"Offline ist Pflicht, nicht Komfort" (`docs/01-produktvision.md`). Ein
weicher Serifencharakter (Soft-Serif, "Old Style"), der zum sachlich-
juristischen, aber nicht kalten Markenton passt — kein verspieltes Display,
keine Handschrift.

**Scope, bewusst eng:**

- Neue `SubsumoTypography`-Rollen `heroLarge` (64px, ≥800px) und
  `heroSmall` (36px, <800px) — **ausschließlich** für den H1 auf Landing-
  und Preisseiten-Hero. FontWeight 600 (SemiBold), `letterSpacing: -0.5`
  (Serifen brauchen bei großen Größen eher engere statt weitere Laufweite —
  Gegenteil der positiven Laufweite bei `displayLarge`).
- **`displayLarge`/`displayMedium` (Wortmarke, öffentlicher Header, Login,
  SUB-159) bleiben unverändert bei `Subsumo`/DejaVu Sans.** Kein
  Schriftwechsel für die Wortmarke — das wäre ein Bruch mit der gerade erst
  auf SUB-159 freigegebenen CI, ohne dass dieses Ticket das verlangt.
  Fraunces ersetzt nichts, es kommt als dritte, noch enger begrenzte Rolle
  dazu.
- Fließtext (`bodyLarge/Medium/Small`, `titleLarge/Medium/Small`) bleibt
  vollständig unangetastet — betrifft keinen App-Screen.

**Folgearbeit (nicht Teil dieses Briefs):** Font-Datei beschaffen
(statische Weights oder Variable Font von Google Fonts herunterladen),
`app/assets/fonts/` ergänzen, `LIZENZ.md`-Eintrag analog zum bestehenden
DejaVu-Eintrag anlegen, `pubspec.yaml` erweitern — das ist eine
Umsetzungsaufgabe für den Frontend-/UI-Developer, keine Design-Entscheidung
mehr.

---

## 5. Bildsprache — Entscheidung: outline-Icons bleiben Standard, EIN
abstraktes Marken-Motiv kommt dazu

`docs/11-designsystem.md` Abschnitt "Bildsprache" bleibt in der Substanz
bestehen: **keine Stockfotos, keine Illustrationen, keine Maskottchen.**
Diese Regel schützt die Ernsthaftigkeit der Marke (Jura-Zielgruppe,
sachlicher Ton) — Stockfotos wären hier ein Rückschritt, kein Fortschritt,
und ich verwerfe sie bewusst auch für den Marketing-Bereich.

**Ergänzung, eng begrenzt:** Das im CI-Konzept (freigegeben auf SUB-154,
bislang ohne Asset umgesetzt) bereits genannte **Subsumtionslogik-Motiv**
(Klammer-/Treppen-Form) wird als **ein einziges, selbst erzeugtes
abstraktes SVG-Motiv** gebaut — Verlauf/Flächen aus den bestehenden
`brand`/`accent`-Tokens, keine neue Formensprache pro Sektion. Einsatz:

- Hero-Band (Abschnitt 3.1), als große, dezente Grafik neben dem
  Headline-Text.
- Optional als sehr sparsame Hintergrundtextur im Footer-Band.

**Nicht** eingesetzt: in App-Screens, in der "Ehrlich über den Umfang"-
Sektion (die lebt bewusst nur von Fläche + Text, kein weiteres visuelles
Element lenkt vom ehrlichen Ton ab), nicht als wiederkehrendes Deko-Element
pro Karte/Chip. Funktionale Icons (Navigation, Feature-Grid, Chips) bleiben
in jedem Fall `Icons.*_outlined` — das abstrakte Motiv ist Marke, kein
Ersatz für Funktions-Icons.

---

## 6. App-Screens: Handwerk statt Gamification

Gilt für Dashboard, Karteikarten-Lernmodus, Gutachten-Editor. Kein neuer
Screen für den Klausur-Simulator (v1.1, `docs/03-roadmap.md`) — die
Prinzipien unten gelten dort mit, sobald der Screen existiert.

- **Tiefe/Hierarchie über Fläche, nicht Schatten:** konsequentere Nutzung
  von `surface0`/`surface1`/`surface2` (bestehend, SUB-157), um die
  wichtigste Fläche eines Screens (z. B. die Coverage-Hero-Karte im
  Dashboard) klar vor Listenelementen abzusetzen — keine neue
  Elevation-Stufe, keine neue Farbe.
- **Bessere Leerzustände:** größeres Outline-Icon (z. B. 48px statt der
  aktuell impliziten Textgröße) + der bestehende sachliche Text ("Nichts
  fällig. Gut gemacht.") — reine Typo-/Icon-Größen-Verfeinerung, kein neuer
  Mechanismus, kein neues visuelles Vokabular.
- **Ruhigere Übergänge:** konsequenterer Einsatz der bestehenden
  `Motion.normal`/`curve` (SUB-158) auf weitere State-Wechsel (z. B.
  Filter-Auswahl, Struktur-Feedback-Block-Erscheinen im Gutachten) — keine
  neue Motion-Konstante.
- **Struktur-Feedback klarer abgesetzt:** `SubsumoFeedbackBlock`-Instanzen
  im Gutachten bekommen eine klarere Flächenabgrenzung (`surface1`/`surface2`
  statt nur Icon-Farbe auf `surface0`), damit mehrere Findings im langen
  Fließtext leichter auffindbar sind — **alle** Findings weiterhin dieselbe
  neutrale Fläche, unabhängig vom Schweregrad (Ampel-Verbot gilt
  unverändert für jede Flächenfarbe, nicht nur für Fortschrittsbalken).

**Ausdrücklich nicht:** neue Farbrollen, Ampel-Logik in irgendeiner Form,
Konfetti/Partikel/Bounce-Overshoot, Streak-Zahlen mit Farbwechsel,
Maskottchen, Stockfotos, Illustrationen. `SubsumoProgressMeter` bleibt exakt
wie in docs/11 Abschnitt 1 festgelegt: Füllfarbe immer `primary`,
unabhängig vom Wert.

---

## 7. Token-Deltas (Zusammenfassung)

| Bereich | Delta | Scope |
|---|---|---|
| Typografie | Neue Rollen `heroLarge` (64px) / `heroSmall` (36px), Schrift Fraunces, `FontWeight.w600`, `letterSpacing: -0.5` | Nur Landing-/Preisseiten-Hero-H1 |
| Schriftart | Neues Asset Fraunces (SIL OFL 1.1) | Nur `heroLarge`/`heroSmall`; `displayLarge/Medium` bleiben DejaVu |
| Farbe | Keine neuen Hex-Konstanten. Neue *Verwendungen* bestehender Tokens: Verlauf `brand700`→`brand900` (Hero-Band), `accent500`-Wash niedriger Deckkraft (Umfangs-Sektion), drei feste Rechtsgebiets-Akzenttöne aus der Palette | Nur `pages/public/*` |
| Radius | Keine neue Stufe. **Korrektur:** `Radii.lg = 20` existiert bereits im Code, fehlt aber in docs/11 Abschnitt 2.3 (dort nur drei Stufen dokumentiert) — beim Doku-Update mitkorrigieren | docs-Fix, kein Code-Delta |
| Elevation | Keine neue Stufe — Pro-Preiskarte hebt sich über Rahmenfarbe + `surface2` ab, nicht über Schatten | Nur `pages/public/*` |
| Bewegung | Keine neue Duration/Curve. Scroll-Reveal (Fade + 8–12px Slide) nutzt ausschließlich `Motion.normal`/`curve`, max. 40ms Versatz zwischen Geschwister-Elementen | Nur `pages/public/*`, nie App-Screens |
| Neue Komponente | `SubsumoSection` (randloses Band + innen `ReadableWidth`), ersetzt die pauschale Breitenbegrenzung in `PublicScaffold` | Nur `pages/public/*` |
| Neues Asset | Ein abstraktes Subsumtionslogik-SVG-Motiv (Abschnitt 5) | Nur Hero-/Footer-Band |

---

## 8. Abnahmekriterien je Folgeaufgabe

### 8.1 Token-Ebene

- Alle neuen Tokens sind additiv — kein bestehender Wert für App-Screens
  (`displayLarge/Medium`, `Elevation.*`, `Motion.*`, alle Hex-Konstanten in
  `colors.dart`) wird verändert. Prüfbar per Diff: nur neue Konstanten/Felder,
  keine geänderten Zeilen in den bestehenden.
- Jede neue Farbkombination (Verlaufsendpunkt, Accent-Wash, neue
  Rechtsgebiets-Akzenttöne als Text-/Icon-Farbe) hat einen nachgerechneten
  Eintrag in docs/11-designsystem.md Abschnitt 5 (≥ 4.5:1 für Text, ≥ 3:1
  für nicht-textuelle Elemente) **vor** Merge — kein geschätzter Wert.
- `flutter analyze` läuft ohne jede Meldung (Warnungen brechen die CI,
  siehe SUB-108-Erfahrung).
- `heroLarge`/`heroSmall` sind als eigene `SubsumoTypography`-Felder
  implementiert, nicht über `ThemeData.textTheme` — prüfbar per grep: keine
  Verwendung von `heroLarge`/`heroSmall` außerhalb `pages/public/`.

### 8.2 Öffentliche Seiten

- `PublicScaffold` erzwingt keine pauschale `maxWidth: 720` mehr — mind.
  drei Sektionen der Landingpage nutzen unterschiedliche, randlos volle
  Hintergrundflächen (`SubsumoSection`), Inhalt bleibt innen über
  `ReadableWidth` lesbar begrenzt.
- Alle Text-Assertions aus `public_landing_page_test.dart` und
  `public_pricing_page_test.dart` bleiben grün — Layout darf sich ändern,
  der wortgleiche Text aus `docs/21-landing-preisseite-launchtext.md`
  nicht.
- Zweispalten-/Mehrspalten-Sektionen sind bei mind. zwei Fensterbreiten
  (z. B. 400 und 1200 logische Pixel je Seite eines Golden-/Widget-Tests)
  auf das beschriebene Breakpoint-Verhalten (800px) geprüft.
- Rechtsgebiets-Akzenttöne sind nachweisbar kategorisch (fest pro Gebiet),
  nicht aus einem Lernstand/einer Mastery-Zahl abgeleitet — prüfbar per
  Code-Review: keine Verzweigung auf einen Prozent-/Score-Wert.
- Scroll-Reveal-Bewegung (falls umgesetzt) nutzt ausschließlich
  `Motion.normal`/`curve`, keine neue Duration, kein Bounce — prüfbar per
  Review gegen `motion.dart`.
- Fraunces-Lizenzeintrag existiert (`assets/fonts/LIZENZ.md`-Ergänzung)
  **bevor** die Schriftdatei eingebunden wird.

### 8.3 App-Screens

- Kein neues visuelles Signal ist wertabhängig — `dashboard_page_test.dart`
  (verbietet `CircleAvatar`-Ampel) bleibt grün, keine neue vergleichbare
  Ampel-Logik andernorts eingeführt.
- Keine Gamification-Elemente (kein Konfetti, keine Partikel, kein
  Bounce-Overshoot, keine farbwechselnden Streak-Zahlen) — prüfbar per
  Review gegen dieses Dokument und `docs/01-produktvision.md` Leitprinzip 5.
- Keine neue Bildsprache außerhalb `Icons.*_outlined` in App-Screens (kein
  Stockfoto, keine Illustration, kein Maskottchen, auch nicht das
  Marken-Motiv aus Abschnitt 5).
- Bestehende App-Screen-Widgettests (`dashboard_page_test.dart`,
  `review_page_test.dart`, `gutachten_page_test.dart`,
  `checkout_page_test.dart`, `account_page_test.dart`,
  `login_page_test.dart`, `home_shell_test.dart`) bleiben grün ohne
  Änderung an geprüfter Kernlogik — nur layoutbedingte Finder-Anpassungen
  (z. B. Icon-Größe) sind erlaubt, keine Verhaltensänderung.

---

## 9. Betroffene Widget-Tests (14 gesamt unter `app/test/`)

**Zwingend anzupassen (Layout- bzw. neue Testfälle):**

- `public_landing_page_test.dart` — Text-Assertions bleiben gültig,
  vermutlich neue Testfälle für Sektions-Flächenfarben/Breakpoints.
- `public_pricing_page_test.dart` — gleiche Begründung für die
  Preis-Teaser-Kartenumstellung (Abschnitt 3, Sektion 7).
- `design_components_test.dart` — neue Komponente `SubsumoSection` und die
  neuen Typografie-Rollen brauchen eigene Testfälle; bestehende Fälle
  bleiben unverändert grün (additiv).

**Voraussichtlich unverändert:**

- `public_legal_page_test.dart`, `public_routing_test.dart` — Footer-/
  Routing-Grundstruktur ändert sich nicht.
- `dashboard_page_test.dart`, `review_page_test.dart`,
  `gutachten_page_test.dart`, `checkout_page_test.dart`,
  `account_page_test.dart`, `login_page_test.dart`, `home_shell_test.dart`,
  `api_test.dart`, `state_test.dart` — App-Screen-Arbeit ist gestalterische
  Verfeinerung ohne Struktur- oder Verhaltensbruch (Abschnitt 6).

---

## 10. Aktualisierungspflicht `docs/11-designsystem.md`

Muss vor Abschluss der Umsetzungsaufgaben nachgezogen werden, sonst steht
die Begründung im Code gegen die Doku:

1. **Abschnitt 1 "Farbwelt"/"Typografie"/"Bildsprache":** den Split
   öffentliche Fläche (mutig) vs. App-Screen (zurückhaltend) aus Abschnitt 1
   dieses Briefs explizit dokumentieren, mit Verweis auf SUB-227.
2. **Abschnitt 2.1 Farbe:** Hero-Verlauf, Accent-Wash und
   Rechtsgebiets-Akzenttöne als dokumentierte *Verwendungen* bestehender
   Tokens ergänzen.
3. **Abschnitt 2.3 Radius:** die bestehende, bisher undokumentierte
   `Radii.lg = 20` nachtragen (Korrektur, kein neuer Wert).
4. **Abschnitt 2.5 Typoskala:** `heroLarge`/`heroSmall` + Fraunces-Rolle
   ergänzen, mit dem gleichen "sickert nicht in App-Screens durch"-Hinweis
   wie bei `displayLarge/Medium`.
5. **Abschnitt 2.6 Bewegung:** Scroll-Reveal-Regel (nur `pages/public/*`,
   nur bestehende Duration/Curve) ergänzen.
6. **Abschnitt 3 Komponenteninventar:** `SubsumoSection` eintragen,
   inklusive "Nicht für"-Spalte (App-Screens).
7. **Abschnitt 5 Kontrastwerte:** neue Einträge für Text auf
   Verlaufsendpunkt `brand900`, Text auf Accent-Wash, Text/Icon auf jedem
   der drei Rechtsgebiets-Akzenttöne.
8. **Abschnitt 8 Getroffene Annahmen:** neuen Eintrag für SUB-227 mit dem
   Verweis, dass die bisherige Annahme "zurückhaltend für alle Flächen"
   für öffentliche Flächen bewusst und begründet abgelöst wurde.

---

## 11. Nicht Teil dieses Briefs

- Konkrete Fraunces-Font-Datei beschaffen/einbinden, SVG-Motiv final
  gestalten und exportieren — Umsetzungsaufgabe.
- Preisseite/Login/Rechtstexte im gleichen Detailgrad wie die Landingpage
  durchgeplant (Abschnitt 3 beschreibt nur die Landingpage vollständig) —
  gleiche `SubsumoSection`-Logik gilt, Feinschnitt ist Aufgabe der
  Umsetzung.
- Klausur-Simulator-Screen (v1.1, existiert noch nicht).
