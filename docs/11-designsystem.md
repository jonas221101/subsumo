# Designsystem v1

Fundament fuer alle Screens bis v1.0: Tokens (Farbe, Abstand, Radius,
Typoskala, Elevation) und ein kleines Set an Basiskomponenten, auf denen
`theme.dart` und die Screens aufbauen. **Kein** Redesign einzelner Seiten -
das ist [SUB-37](/SUB/issues/SUB-37). Code: `app/lib/design/`.

## 1. Markenbasis

**Split oeffentliche Flaeche vs. App-Screen (SUB-227, UI-Relaunch-Brief,
[docs/25-ui-relaunch-brief.md](25-ui-relaunch-brief.md)):** Die Leitprinzipien
4/5 ("Ehrlichkeit vor Motivation", "Kein Druck durch Design",
`docs/01-produktvision.md`) schuetzen die *Lernsituation*, nicht die
Marketingflaeche. Oeffentliche Flaechen (Landing, Preise, Login-/
Rechtstexte-Rahmen) duerfen seit SUB-227 deutlich mutiger sein - vollbreite
Farbbaender, ein tragender Hero, Bewegung beim Scrollen (Details:
[SUB-241](/SUB/issues/SUB-241)). App-Screens (Dashboard, Karteikarten,
Gutachten, spaeter Klausur-Simulator) bleiben beim zurueckhaltenden,
handwerklichen Ansatz dieses Dokuments - **keine** neuen Marken-/
Marketing-Rollen dort (Details: [SUB-242](/SUB/issues/SUB-242)). Die Tokens
unten sind entsprechend markiert, wo eine neue Rolle nur fuer oeffentliche
Flaechen gilt.

### Farbwelt

Subsumo ist kein Konsum-Produkt, das um Aufmerksamkeit wirbt, sondern ein
Werkzeug, mit dem Nutzer Stunden am Stueck Fliesstext lesen und schreiben
(Gutachten, Falltexte, Schemata). Die Palette (`design/tokens/colors.dart`,
`SubsumoPalette`) ist deshalb bewusst zurueckhaltend:

- **Marke: gedecktes Navyblau** (`brand700 #1F3A5F`, mit vier weiteren
  Abstufungen `brand900`…`brand100`). Kein Startup-Blau, kein Gruen mit
  hoher Saettigung - juristisch-sachlich statt verspielt. Der Ton war
  bereits vor diesem Ticket als `ColorScheme.fromSeed`-Seed im Code
  (`theme.dart`) gesetzt; dieses Dokument formalisiert ihn als Token und
  pinnt die davon abgeleiteten Rollen explizit (siehe 2.1).
- **Neutralpalette ("Ink") fuer Text und Flaechen** (`ink900`…`ink100`,
  getrennte Werte fuer Light/Dark). Fliesstext braucht den hoechsten
  Kontrast im System - er ist die meistgenutzte Flaeche der App.
- **Feedback-Farben** (`feedbackPositive`, `feedbackHint`,
  `feedbackNegative`) ausschliesslich fuer eine punktuelle Rueckmeldung auf
  eine konkrete Handlung (ein Struktur-Finding im Gutachten, ein
  Formularfehler) - nie fuer Dauerzustaende. Alle drei sind entsaettigt:
  selbst "negativ" soll sachlich wirken, nicht wie ein Alarm.
- **Marken-Akzent** (`accent500`/`accent300`, SUB-159, CI-Konzept
  freigegeben auf SUB-154): gedecktes Gold/Bernstein, ausschliesslich fuer
  Marken-/Leerzustandsflaechen (Landingpage, oeffentlicher Header) -
  niemals fuer Fortschritt oder Feedback, dafuer bleiben die Feedback-Farben
  zustaendig. Getrennt von der Palette der Feedback-Farben, damit eine
  falsche Verwendung (Akzent auf einer Fortschrittsanzeige) im Review am
  Tokennamen auffaellt.

**Bindende Regel aus den Leitprinzipien** (`docs/01-produktvision.md`,
"Ehrlichkeit vor Motivation" und "Kein Druck durch Design"): **Lernstand ist
keine Ampel.** Eine Fortschritts- oder Mastery-Anzeige verwendet immer *eine*
Farbe unabhaengig vom Wert - 62 % sieht optisch identisch aus wie 95 %, nur
die Fuellhoehe/-laenge und die Zahl unterscheiden sich. Deshalb gibt es in
der Palette absichtlich **keine** dritte Kategorie "Warnfarbe fuer niedrigen
Fortschritt". `SubsumoProgressMeter` (Abschnitt 3) erzwingt das technisch:
die Fuellfarbe ist immer `colorScheme.primary`, unabhaengig vom `value`.

Die bestehende Wissenslandkarte (`dashboard_page.dart`) tat vor diesem
Ticket genau das Verbotene - eine Karten-Mastery unter 80 % wurde je nach
Fortschritt rot oder gelb eingefaerbt (klassische Ampel). Das ist mit diesem
Ticket korrigiert (Abschnitt 6), weil es ein direkter Verstoss gegen einen
bindenden Leitgrundsatz war, keine hypothetische Zukunftsanforderung.

### Typografie

Eigene Schriftdatei `Subsumo` (DejaVu Sans, siehe `assets/fonts/LIZENZ.md`)
statt System- oder Web-Font-Nachladen - Begruendung in
`docs/07-spike-web-editor.md`, Nebenbefund 2. Die Typoskala
(`design/tokens/typography.dart`, `TypeScale`) ist auf lange Lesestrecken
ausgelegt, nicht auf dekorative Ueberschriften:

- Fliesstext (`bodyLarge`/`bodyMedium`) bleibt bei 15-16px mit 1.5-facher
  Zeilenhoehe - der Wert stand schon vor diesem Ticket im Code und hat sich
  an echten Gutachtentexten bewaehrt; kleinere Werte lassen lange
  Lesestrecken auf breiten Fenstern schwerer verfolgbar werden.
- Ueberschriften (`titleLarge/Medium/Small`) sind knapp gestuft (22/17/15px,
  `FontWeight.w600`) - sie sollen Struktur geben, nicht dominieren. Sie
  bleiben unveraendert die Rolle fuer Karten-/Gutachten-/Klausur-Screens.
- **Display-Rolle** (`displayLarge`/`displayMedium`, SUB-159, CI-Konzept
  freigegeben auf SUB-154): eigene, deutlich groessere/kraeftigere Rolle
  (32/24px, `FontWeight.w700`, leichte Laufweite) ausschliesslich fuer
  Ueberschriften auf Marken-/Rahmenflaechen (Wortmarke, oeffentlicher
  Header, Login) - als `ThemeExtension` `SubsumoTypography`, getrennt vom
  geteilten `ThemeData.textTheme`, damit sie nicht ueber `headlineSmall` &
  Co. versehentlich in Gutachten-/Klausur-Screens durchsickert (siehe die
  Gutachten-Punktzahl in `gutachten_page.dart`, die weiterhin
  `headlineSmall` nutzt). Nutzt bewusst weiterhin die eingebettete
  `Subsumo`-Schriftdatei (DejaVu Sans) statt einer zweiten Schriftfamilie:
  ein eigenes, lizenziertes Zweitschrift-Asset war in diesem Ticket nicht
  beschaffbar (siehe `assets/fonts/LIZENZ.md` - ein Schriftwechsel ist
  ohnehin als spaetere, bewusste Entscheidung fuer M5/Store-Release
  vorgesehen). Die Rolle unterscheidet sich daher ueber Groesse/Gewicht/
  Laufweite, nicht ueber eine zweite Schriftdatei.
- **Hero-Rolle** (`heroLarge`/`heroSmall`, SUB-227/SUB-228): eigene,
  deutlich groessere Rolle (64/36px, `FontWeight.w600`, Laufweite -0.5) -
  **ausschliesslich** fuer den H1 auf dem Landing-/Preisseiten-Hero
  (`pages/public/`), ebenfalls als `SubsumoTypography`-Feld, damit sie
  nicht ueber `ThemeData.textTheme` in Karteikarten-/Gutachten-/
  Klausur-Screens durchsickert - dieselbe Schutzlogik wie bei
  `displayLarge/Medium` oben. Anders als `displayLarge/Medium` nutzt sie
  die neue Schriftdatei **Fraunces** (Variable Font, SIL OFL 1.1, siehe
  `assets/fonts/LIZENZ.md`) statt `Subsumo`/DejaVu Sans - ein bewusst eng
  begrenzter Sonderfall (nur diese zwei Felder), kein Ersatz der
  Wortmarken-Schrift. `displayLarge/Medium` und der gesamte Fliesstext
  bleiben unveraendert bei `Subsumo`/DejaVu Sans.

### Tonalitaet

Sachlich, direkt, keine Ausrufezeichen-Rhetorik. Ein leerer Zustand heisst
"Nichts faellig. Gut gemacht." statt "🎉 Super gemacht!!!". Fehlermeldungen
benennen das Problem ("Bitte E-Mail eingeben"), nicht die Schuld. Das ist
bereits durchgaengiger Stil im bestehenden Code (siehe `login_page.dart`,
`review_page.dart`) und wird mit diesem System nicht veraendert, nur nicht
gebrochen.

### Bildsprache

Keine Illustrationen, keine Stockfotos, keine Maskottchen. Das einzige
visuelle Vokabular sind Material-Icons (outline-Stil, `Icons.*_outlined`) -
konsistent mit der bisherigen Navigation (`main.dart`,
`_HomeShellState._destinations`). Ein Icon transportiert Funktion
(Kategorie, Zustand), nie Dekoration.

**Wortmarke** (`SubsumoWordmark`, SUB-159, CI-Konzept freigegeben auf
SUB-154): reine Wortmarke "Subsumo" in der Display-Rolle, kein Maskottchen/
Icon-lastiges Logo - konsistent mit obiger Regel. Das im Konzept genannte
abstrakte Symbol (Subsumtionslogik als Klammer-/Treppen-Motiv) ist dort
ausdruecklich optional und ohne finales Asset; dieses Ticket setzt nur den
freigegebenen Wortmarken-Teil um. Eingesetzt im oeffentlichen Header
(`PublicScaffold`, zweifarbige Akzent-Variante) und der Login-Kopfzeile
(einfarbig, Navy) - ausschliesslich Marketing-/Rahmenflaechen, nicht in
Karteikarten-/Gutachten-/Klausur-Screens.

## 2. Tokens

Code: `app/lib/design/tokens/`. Alle Werte sind `const`, damit sie zur
Compile-Zeit geprueft werden und `flutter analyze` eine falsche Verwendung
(z. B. Farbliteral statt Token) nicht verhindern kann, ein Review aber
leicht auf den Token statt auf den Hex-Wert schauen kann.

### 2.1 Farbe (`colors.dart`)

`SubsumoPalette` haelt die Rohwerte, `buildColorScheme(Brightness)` baut
daraus das Material3-`ColorScheme`, das `theme.dart` und alle Standard-
Widgets (Card, FilledButton, …) konsumieren.

Ansatz bewusst hybrid statt komplett handgepflegt: Ausgangspunkt ist
`ColorScheme.fromSeed(seedColor: brand700)` - das befuellt auch selten
sichtbare Rollen (`inversePrimary`, `scrim`, `shadow`, …) sinnvoll, ohne
dass 30 Rollen einzeln gepflegt werden muessen. Die staendig sichtbaren
Rollen (Text, Flaechen, Primaerfarbe, Fehler) werden danach per
`.copyWith()` auf die folgenden, kontrastgeprueften Werte gepinnt:

| Rolle | Light | Dark |
|---|---|---|
| `primary` / Fuellung Primaerbutton | `brand700` `#1F3A5F` | `brand300` `#7C97B3` |
| `onPrimary` / Text auf Primaerbutton | `#FFFFFF` | `surface0Dark` `#12151A` |
| `primaryContainer` | `brand100` `#DCE4EC` | `brand900` `#12233B` |
| `surface` / Seitenhintergrund | `surface0Light` `#FFFFFF` | `surface0Dark` `#12151A` |
| `onSurface` / Fliesstext | `ink900` `#14181D` | `ink900Dark` `#EDEFF2` |
| `surfaceContainerHighest` / Kartenflaeche | `surface1Light` `#F0F1F4` | `surface1Dark` `#20242C` |
| `onSurfaceVariant` / sekundaerer Text | `ink700` `#3C434B` | `ink700Dark` `#C3C8CF` |
| `outline` / Rahmen, Trennlinien | `ink300` `#B7BCC2` | `ink500Dark` `#8B929B` |
| `error` / negatives Feedback | `feedbackNegative` `#A23B3B` | `feedbackNegativeDark` `#D98787` |

Drei Rollen kennt Material3 nicht (kein "success"/"warning"/"brand-accent"):
`positiv`, `hinweis` und `accent` kommen ueber die `ThemeExtension`
`SubsumoColors` (`theme.extension<SubsumoColors>()`), befuellt mit
`feedbackPositive`/`feedbackHint`/`accent500` (Light) bzw.
`accent300` (Dark) aus der Palette. "Negativ" nutzt bewusst die vorhandene
Material-Rolle `error` statt einer eigenen dritten Fehlerfarbe - eine
zweite Rot-Variante waere nur eine Quelle fuer Inkonsistenz. `accent` ist
strikt von `positiv`/`hinweis`/`error` getrennt (SUB-159): ausschliesslich
Marken-/Leerzustandsflaechen, nie Fortschritt/Feedback.

**SUB-227/SUB-228:** Vier weitere Rollen in `SubsumoColors`, alle nur fuer
oeffentliche Flaechen (`pages/public/*`) und ohne neue Hex-Konstante -
reine *Verwendungen* bestehender Palettenwerte:

| Rolle | Aufbau | Einsatz |
|---|---|---|
| `heroGradientStart`/`heroGradientEnd` | `brand700` -> `brand900`, brightness-unabhaengig | Hero-Band, Landing/Preise |
| `accentWash` | `accent` (500/300 je Brightness) bei 8 % Deckkraft | "Ehrlich ueber den Umfang"-Sektion |
| `legalAreaZivilrecht` | `brand500` (Light) / `brand300` (Dark) | Kategorischer Akzent, Rechtsgebiets-Karten |
| `legalAreaStrafrecht` | `accent500` (Light) / `accent300` (Dark) | wie oben |
| `legalAreaOeffentlichesRecht` | `ink500` (Light) / `ink500Dark` (Dark) | wie oben |

Die drei `legalArea*`-Rollen sind bewusst fest pro Rechtsgebiet (Abschnitt 1)
- keine Ampel, weil sie nichts ueber Lernstand aussagen, nur ueber
Wiedererkennung. `SubsumoSection` (Abschnitt 3) baut `heroGradient`/
`accentWash`/`brandDark` (Alias fuer `heroGradientEnd`) zu fertigen
Hintergrundflaechen zusammen, damit Seiten nicht selbst mit `Gradient`/
`Color.alphaBlend` hantieren.

### 2.2 Abstand (`spacing.dart`)

Vielfache von 4 (`xs=4, sm=8, md=12, lg=16, xl=24, xxl=32, xxxl=48`). Deckt
sich mit Material3s Grid und ersetzt krumme Einzelwerte, die in den
urspruenglichen Screens entstanden waren (`EdgeInsets.all(20)`,
`SizedBox(height: 14)`, …) - eine begrenzte Skala macht Abstaende
untereinander vergleichbar und Abweichungen im Review auffaellig.

### 2.3 Radius (`radii.dart`)

Vier Stufen: `sm=10` (Buttons, Eingabefelder - der Wert stand schon vorher
hart codiert in `theme.dart`), `md=14` (Karten), `lg=20`, `pill=999` (Chips,
abgerundete Leisten). **Korrektur (SUB-228):** `lg=20` stand bereits vor
diesem Ticket im Code, fehlte hier aber in der Dokumentation - kein neuer
Wert, nur ein Dokumentationsnachtrag. Bewusst keine fuenfte Stufe - der
UI-Relaunch-Brief (SUB-227) verlangt keine weitere Radius-Stufe, eine
zusaetzliche waere eine Regel ohne Anwendungsfall.

### 2.4 Elevation (`elevation.dart`)

`level0=0, level1=1, level2=4`. Niedrig gehalten, weil starke Schatten auf
einer textlastigen, langen Lesestrecke unruhig wirken - `level1` fuer
Karten im Ruhezustand (Standardfall), `level2` nur fuer temporaer im
Vordergrund stehende Flaechen (z. B. ein Dialog). Kein `level3+`, solange
kein Screen das braucht.

### 2.5 Typoskala (`typography.dart`)

Siehe Abschnitt 1, "Typografie" - die Zahlenwerte stehen als benannte
Konstanten in `TypeScale`, damit `theme.dart` (und spaeter Komponenten, die
bewusst von der Theme-Textur abweichen wollen) sie referenzieren statt
Literale zu wiederholen. **SUB-227/SUB-228:** `heroLarge`/`heroSmall`
(64/36px, `FontWeight.w600`, Laufweite -0.5, Schrift Fraunces) kommen als
zwei weitere `SubsumoTypography`-Felder dazu, exakt so von `ThemeData.
textTheme` getrennt wie `displayLarge/Medium` - sie sickern nicht in
Karteikarten-/Gutachten-/Klausur-Screens durch, per grep gegenprueft
(keine Verwendung ausserhalb `pages/public/`).

### 2.6 Bewegung (`motion.dart`)

**SUB-158:** `fast=150ms, normal=220ms`, Kurve `Curves.easeInOut`. Reine
Timing-/Easing-Verbesserung fuer bestehende State-Uebergaenge (Kartenwechsel,
Auf-/Zuklappen) - bewusst kein Bounce-Overshoot und keine sonstigen
Gamification-Effekte (kein Konfetti, keine Partikel), nur ein "gemachtes"
statt statisches Gefuehl. Exemplarisch eingesetzt im Karteikarten-Lernmodus
(`pages/review_page.dart`): die Antwortseite blendet ueber `AnimatedSwitcher`
mit `Motion.normal`/`Motion.curve` ein, statt instantan zu erscheinen.

## 3. Komponenteninventar

Code: `app/lib/design/components/`. Alle Komponenten sind duenne Wrapper um
Material3-Widgets - sie erzwingen Konsistenz (Radius, Abstand, Farbrolle),
erfinden aber keine neue Interaktionslogik. Ein Screen, der eine Material-
Komponente direkt braucht, die hier fehlt, verwendet weiter
`Theme.of(context)` - die zentral gesetzten Component-Themes in
`theme.dart` greifen trotzdem.

| Komponente | Einsatz | Nicht fuer |
|---|---|---|
| `SubsumoCard` | Inhaltlicher Block: Kartenfrage, Fallbeschreibung, Struktur-Feedback, Ergebnis | Reine Listenzeilen ohne Rahmen (dafuer `ListTile` direkt) |
| `SubsumoButton.primary/.secondary/.tertiary` | Genau eine `primary`-Handlung pro Screen (das Wichtigste); `secondary` fuer gleichwertige Alternativen ("Erneut versuchen"); `tertiary` fuer niedrigste Prioritaet (Link-artige Aktionen) | Mehr als eine `primary` pro Screen - das ist ein Zeichen, dass die Handlungshierarchie unklar ist |
| `SubsumoTextField` | Formulareingabe, einzeilig oder expandierend (Login, Gutachten-Editor) | Suchfelder mit Sofort-Feedback pro Tastendruck (eigener Bedarf, kein Formularfeld) |
| `SubsumoProgressMeter` | Jede Fortschritts-/Mastery-Anzeige: Gesamtcoverage, Rechtsgebiet, Struktur-Score. Fuellfarbe ist immer `primary`, nie wertabhaengig | Ladeindikatoren ohne bekannten Zielwert (dafuer `CircularProgressIndicator`) |
| `SubsumoChip` (`.filter` / `.action` / Basis) | Kartentyp, Rechtsgebiets-Filter, Norm-Verweis, Status ("offline" - seit SUB-161 app-weit im `AppBar` von `HomeShell`, siehe `main.dart` -, "aktualisiert") | Mehrfachauswahl mit komplexer Logik (eigener Zustand noetig, Chip bleibt nur die Darstellung) |
| `SubsumoFeedbackBlock` | Punktuelle Rueckmeldung: Struktur-Finding im Gutachten, Formularfehler, Leerzustand-Hinweis. Farbe ist immer nur ein kleines Icon, nie eine Flaechenfarbe | Dauerzustaende wie Lernfortschritt - dafuer `SubsumoProgressMeter` |
| `SubsumoWordmark` (SUB-159) | Marken-Wortmarke "Subsumo" in der Display-Rolle: oeffentlicher Header (`PublicScaffold`, zweifarbige Akzent-Variante), Login-Kopfzeile | Karteikarten-/Gutachten-/Klausur-Screens |
| `SubsumoSection` (SUB-227/SUB-228) | Randloses Band mit eigener Hintergrundflaeche (`SubsumoSectionBackground.surface0/surface1/heroGradient/accentWash/brandDark`), begrenzt seinen Inhalt intern ueber `ReadableWidth`. Ersetzt die pauschale `maxWidth`-Zwang in `PublicScaffold` fuer oeffentliche Flaechen (Landing, Preise, Login-/Rechtstexte-Rahmen), siehe SUB-241 | Karteikarten-/Gutachten-/Klausur-Screens - dort bleibt die zurueckhaltende Flaechenlogik aus Abschnitt 6 der Beispiel-Migration/SUB-242 |

Jede Komponente traegt Screenreader-Semantik direkt (siehe Abschnitt 4) -
ein Screen muss sie nicht nachtraeglich mit `Semantics` umwickeln.

## 4. Barrierefreiheit

- **Kontrast ≥ 4.5:1** fuer jede Text/Flaeche-Kombination, die im System
  vorkommt - nachgerechnet in Abschnitt 5, nicht geschaetzt.
- **Dynamische Schriftgroessen:** Kein Widget im System setzt `TextStyle`
  mit absoluter Pixelgroesse *ohne* Bezug zum Theme - alle Texte laufen
  ueber `Theme.of(context).textTheme.*`, was `MediaQuery.textScaler`
  respektiert. Eigene Layouts (`ReadableWidth`, feste `SizedBox`-Hoehen in
  einzelnen Screens) sind eine bekannte Restarbeit fuer SUB-37, nicht Teil
  dieses Fundaments.
- **Screenreader-Labels:** `SubsumoProgressMeter` und `SubsumoFeedbackBlock`
  setzen `Semantics(label: …)` mit dem vollstaendigen Sinn ("Zivilrecht: 62
  Prozent", "Fehler: Obersatz fehlt") statt nur die sichtbaren Text-Kinder
  vorlesen zu lassen, die ohne Kontext ("62 %", nackter Icon) fuer einen
  Screenreader-Nutzer bedeutungsarm waeren.

## 5. Kontrastwerte (nachgerechnet)

Berechnet nach der WCAG-2-Formel fuer relative Luminanz und Kontrastverhaeltnis
(`(L1+0.05)/(L2+0.05)`, `L1` die hellere Farbe). Mindestanforderung fuer
Fliesstext und UI-Text: **4.5:1** (WCAG 2.1 AA).

| Kombination | Verhaeltnis | Ergebnis |
|---|---|---|
| `ink900` auf `surface0Light` (Fliesstext) | 17.82:1 | ✅ |
| `ink700` auf `surface0Light` (sekundaerer Text) | 10.02:1 | ✅ |
| `ink900` auf `surface1Light` (Text auf Karte) | 15.78:1 | ✅ |
| `brand700` auf `surface0Light` (Link/Icon) | 11.48:1 | ✅ |
| Weiss auf `brand700` (Primaerbutton, Light) | 11.48:1 | ✅ |
| `brand700` auf `brand100` (Text auf Container) | 8.94:1 | ✅ |
| `feedbackNegative` auf `surface0Light` | 6.51:1 | ✅ |
| `feedbackHint` auf `surface0Light` | 4.90:1 | ✅ (knapp - siehe Hinweis unten) |
| `feedbackPositive` auf `surface0Light` | 5.00:1 | ✅ |
| `ink900Dark` auf `surface0Dark` (Fliesstext, Dark) | 15.88:1 | ✅ |
| `ink700Dark` auf `surface0Dark` (sekundaer, Dark) | 10.87:1 | ✅ |
| `ink900Dark` auf `surface1Dark` (Text auf Karte, Dark) | 13.50:1 | ✅ |
| `brand300` auf `surface0Dark` (Link/Icon, Dark) | 6.04:1 | ✅ |
| `surface0Dark` auf `brand300` (Primaerbutton, Dark) | 6.04:1 | ✅ |
| `feedbackNegativeDark` auf `surface0Dark` | 6.77:1 | ✅ |
| `feedbackHintDark` auf `surface0Dark` | 9.40:1 | ✅ |
| `feedbackPositiveDark` auf `surface0Dark` | 9.00:1 | ✅ |
| `accent500` auf `surface0Light` (Wortmarken-Akzent, Light) | 5.04:1 | ✅ |
| `accent300` auf `surface0Dark` (Wortmarken-Akzent, Dark) | 9.05:1 | ✅ |
| Weiss auf `brand900` (Hero-Verlaufsende, SUB-227/SUB-228) | 15.80:1 | ✅ |
| `ink900` auf `accentWash` (Umfangs-Sektion, Light) | 16.12:1 | ✅ |
| `ink900Dark` auf `accentWash` (Umfangs-Sektion, Dark) | 13.97:1 | ✅ |
| `legalAreaZivilrecht`/`brand500` auf `surface0Light` (Text/Icon, Light) | 7.18:1 | ✅ |
| `legalAreaZivilrecht`/`brand300` auf `surface0Dark` (Text/Icon, Dark) | 6.04:1 | ✅ |
| `legalAreaStrafrecht`/`accent500` auf `surface0Light` (Text/Icon, Light) | 5.04:1 | ✅ (= Wortmarken-Akzent-Zeile oben, gleicher Palettenwert) |
| `legalAreaStrafrecht`/`accent300` auf `surface0Dark` (Text/Icon, Dark) | 9.05:1 | ✅ (= Wortmarken-Akzent-Zeile oben, gleicher Palettenwert) |
| `legalAreaOeffentlichesRecht`/`ink500` auf `surface0Light` (Text/Icon, Light) | 4.87:1 | ✅ (knapp, siehe `ink500`-Hinweis unten) |
| `legalAreaOeffentlichesRecht`/`ink500Dark` auf `surface0Dark` (Text/Icon, Dark) | 5.82:1 | ✅ |

`feedbackHint` (Light) liegt mit 4.90:1 am naechsten an der Grenze - genug
Reserve fuer Rendering-Unschaerfen, aber kein Wert, den man ohne erneute
Pruefung weiter abdunkeln sollte in eine hellere Richtung. `ink500` (Light,
tertiaerer Text, z. B. `bodySmall`-Metadaten) liegt bei 4.87:1 und wird
deshalb bewusst **nicht** fuer Fliesstext, nur fuer kurze Metadatenzeilen
verwendet, bei denen ein knapper Kontrast weniger schwer wiegt als bei
langen Lesestrecken.

*Nicht als Text verwendete Rollen* (`ink300`/`outline` als Rahmenfarbe,
`ink100`/`outlineVariant` als Trennlinie) unterliegen der niedrigeren
3:1-Anforderung fuer nicht-textuelle UI-Elemente (WCAG 1.4.11) und sind
hier nicht tabelliert, weil sie nie Text tragen.

**SUB-157:** `surface1`/`surface2` wurden gegenueber `surface0` etwas
staerker abgesetzt (Light: `#F5F6F8`→`#F0F1F4` bzw. `#EDEFF2`→`#E4E7EB`;
Dark: `#1B1F26`→`#20242C` bzw. `#242933`→`#2D3340`), damit Karten allein
ueber die Flaeche sichtbarer wirken, ohne `elevation.dart` zu aendern. Der
Tonabstand zu `surface0` (Kontrastverhaeltnis der Flaechen zueinander) ist
damit um ca. das 1.6- bis 1.75-fache gewachsen (z. B. Light `surface0`↔`surface1`
1.08:1 → 1.13:1, Dark `surface0`↔`surface2` 1.25:1 → 1.45:1) - deutlich
unter der intendierten Obergrenze einer Verdopplung. Alle Fliesstext-Werte
in der Tabelle oben bleiben komfortabel ueber 4.5:1.

**SUB-159:** `accent500`/`accent300` (Markenakzent, Abschnitt 1/2.1) sind so
gewaehlt, dass sie auch als Text/Icon (nicht nur als Flaeche) die 4.5:1-
Mindestanforderung einhalten, obwohl der aktuelle Einsatz (letzter
Buchstabe der Wortmarke) nur ein Icon-aehnliches, nicht fliesstext-langes
Element ist - so bleibt spaeterer Text-Einsatz auf Marken-/
Leerzustandsflaechen ohne erneute Farbpruefung moeglich.

**SUB-227/SUB-228:** `accentWash` ist `accent` (500 Light / 300 Dark) bei
8 % Deckkraft, mit `Color.alphaBlend` auf die jeweilige Standardflaeche
(`surface0Light`/`surface0Dark`) gerechnet, damit der resultierende Wert
selbst eine deckende Flaeche ist (kein transparentes Durchscheinen bei
uebereinanderliegenden Sektionen). Ergebnis: `#F7F3EC` (Light) bzw.
`#22211F` (Dark) - 8 % ist niedrig genug, dass der Fliesstextkontrast
gegenueber der reinen Standardflaeche nur marginal sinkt (Light: 17.82:1 ->
16.12:1, Dark: 15.88:1 -> 13.97:1, siehe Tabelle oben), aber hoch genug, um
die Sektion sichtbar abzusetzen. Der Hero-Verlauf (`heroGradientStart`/
`-End`, `brand700`/`brand900`) ist bewusst brightness-unabhaengig (siehe
Begruendung am Token in `colors.dart`) - `brand700` gegen Weiss war bereits
ueber die Primaerbutton-Zeile oben geprueft (11.48:1), `brand900` als
dunklerer Verlaufsendpunkt ist mit diesem Ticket neu nachgerechnet (15.80:1,
Tabelle oben). Die drei `legalArea*`-Rollen sind absichtlich Aliase auf
bereits gepruefte Palettenwerte (`brand500/300`, `accent500/300`,
`ink500`/`ink500Dark`) statt neuer Farben - jede Zeile in der Tabelle oben
ist eigenstaendig nachgerechnet, auch wo der Zahlenwert mit einer
bestehenden Zeile identisch ist, damit die Verwendung als Rechtsgebiets-
Akzent im Review nachvollziehbar bleibt.

## 6. Plattformregeln

Eine Codebasis (`app/`), vier Zielbilder - bereits harte Anforderung aus
der Produktvision (Android, iOS, Windows, Web), hier als Designregeln
konkretisiert:

- **Touch vs. Maus:** Alle interaktiven Elemente (Buttons, Chips,
  Listenzeilen) halten eine Mindest-Tastflaeche von 48×48 (Material3-
  Standard, `SubsumoButton` setzt `minimumSize: Size(0, 48)` zentral). Auf
  Maus-Plattformen (Windows, Web-Desktop) kommt zusaetzlich Hover-Feedback
  automatisch aus dem Material3-Theme - keine plattformspezifische
  Sonderbehandlung noetig.
- **Fensterbreiten:** `ReadableWidth` (`theme.dart`, unveraendert von
  diesem Ticket) begrenzt Fliesstext auf max. 760px (bzw. 420/1100px fuer
  Login/Gutachten) - ueber ~70 Zeichen pro Zeile bricht die Lesbarkeit ein,
  auf einem Windows-Vollbild sonst ein echtes Problem. Die Navigation
  (`main.dart`, `HomeShell`) schaltet bei ≥800px von unterer Navigationsleiste
  auf seitliche `NavigationRail` um - Layout, keine Komponente dieses
  Systems, aber eine Regel, die neue Screens uebernehmen.
- **Tastaturbedienung:** Alle Basiskomponenten sind Standard-Material3-
  Widgets (`FilledButton`, `TextFormField`, `FilterChip`, …) und erben
  damit Tab-Reihenfolge, Fokus-Ring und Enter/Space-Aktivierung ohne
  Zusatzaufwand. Wichtig fuer den spaeteren Klausur-Simulator (M4,
  `docs/03-roadmap.md`): eine 5-Stunden-Klausur am Windows-Desktop läuft
  ueberwiegend über Tastatur, nicht Touch - jede neue Komponente muss diese
  Erbschaft erhalten und darf keinen eigenen, tastatur-unerreichbaren
  Interaktionspfad einfuehren (z. B. ein Drag-only-Control ohne
  Tastatur-Alternative).

## 7. Beispiel-Migration: Wissenslandkarte

`app/lib/pages/dashboard_page.dart` ist der geforderte Nachweis, dass das
System traegt:

- Die Hero-Karte (Gesamtcoverage) nutzt `SubsumoCard` statt `Card` +
  manuellem `Padding`.
- Gesamtcoverage und jede Rechtsgebiets-Zeile nutzen `SubsumoProgressMeter`
  statt einzeln zusammengesetzter `LinearProgressIndicator` + `Text`.
- Die Themenliste hatte vor diesem Ticket eine Ampel (`Colors.red` /
  `Colors.amber` / `Colors.green` je nach Mastery, `_TopicTile`) - ein
  direkter Verstoss gegen "Kein Druck durch Design". Der farbige
  `CircleAvatar`-Punkt ist durch ein neutrales, wertunabhaengiges Icon
  ersetzt (`Icons.menu_book_outlined`, immer `onSurfaceVariant`). Getestet
  in `test/dashboard_page_test.dart` (`CircleAvatar` darf nicht mehr
  vorkommen).

Nicht angefasst: Struktur und Datenfluss der Seite (`AppState`, API-Calls,
`ListView`-Aufbau) - das ist bewusst kein Redesign, nur der Komponenten-
Austausch plus die eine inhaltliche Korrektur, die durch einen bindenden
Leitgrundsatz erzwungen war.

## 8. Getroffene Annahmen

- Die Marktfarbe (`brand700 #1F3A5F`) ist der bereits im Code vorhandene
  Seed-Wert aus dem urspruenglichen `theme.dart` - dieses Ticket formalisiert
  sie als Token, veraendert sie aber nicht. Eine bewusste Markenfarb-
  Entscheidung (z. B. im Rahmen eines spaeteren Branding-Vorhabens) ist
  hier nicht getroffen worden.
- `Radii.sm = 10` uebernimmt ebenfalls den vorher hart codierten
  Button-Radius, um bestehende Screens optisch nicht zu veraendern; `md`
  und `pill` sind neu gewaehlt und orientieren sich an Material3-
  Standardwerten fuer Karten und Chips.
- Kontrastwerte sind gegen die jeweilige Standardflaeche gerechnet
  (`surface0`/`surface1`); Text auf einer selten vorkommenden dritten
  Flaeche (`surface2`, z. B. eingebettete Listenzeilen) ist nicht einzeln
  tabelliert - `surface2` ist dunkler/heller als `surface1` in dieselbe
  Richtung, der Kontrast also nie schlechter als der jeweils tabellierte
  Wert.
- Figma o. ae. bewusst nicht erstellt (Vorgabe des Tickets) - das System
  lebt ausschliesslich im Code unter `app/lib/design/`.
- **SUB-161:** Der app-weite "offline"-Hinweis nutzt bewusst die bereits in
  `state.dart` vorhandenen Signale (`dueCardsFromCache`, `outbox`) statt
  eines neuen Connectivity-Plugins oder einer eigenen Netz-Pruefschleife -
  beides waere Zustandslogik und damit Aufgabe des Frontend-Developers, nicht
  des Design-Systems. Das macht die Anzeige *reaktiv* (sie erscheint erst
  nach einem tatsaechlich fehlgeschlagenen Serverkontakt), nicht *proaktiv*
  (kein sofortiges Aufleuchten beim App-Start im Flugmodus ohne vorherigen
  Ladeversuch) - im Zweifel lieber ehrlich verzoegert als optimistisch
  falsch, aber fachlich als bekannte Einschraenkung dokumentiert statt still
  in Kauf genommen.
- **SUB-160:** Fokussierter Lesemodus fuer Karteikarten (`pages/review_page.dart`)
  und Gutachten (`pages/gutachten_page.dart`) - ein lokaler `bool`-Umschalter
  (kein neuer `AppState`, reine Layout-Entscheidung) blendet Navigation/Titel
  aus, laesst Fliesstext-Typoskala und Feedback-Farben unveraendert. Im
  Karteikarten-Tab liegt der Zustand in `HomeShell`, weil dort auch
  `NavigationRail`/`NavigationBar` ausgeblendet werden, nicht in `ReviewPage`
  selbst; der Umschalter bleibt dort bewusst in jedem Kartenzustand sichtbar
  (auch im Leerzustand nach der letzten Karte), sonst waere die Rueckkehr aus
  dem Lesemodus blockiert. Bei `GutachtenPage` bleibt eine schmale AppBar mit
  nur dem Umschalter bestehen statt sie komplett zu entfernen - eine
  schwebende Schaltflaeche ueber dem Editor-Inhalt haette bei schmalen
  Fenstern den Falltext verdecken koennen.
- **SUB-227/SUB-228:** Die bisherige, durchgaengige Annahme "zurueckhaltend
  fuer alle Flaechen" gilt ab diesem Ticket nur noch fuer App-Screens.
  Oeffentliche Flaechen duerfen bewusst und begruendet mutiger sein (siehe
  Abschnitt 1) - die Leitprinzipien 4/5 schuetzen die Lernsituation, nicht
  die Marketingflaeche (Aufloesung des scheinbaren Zielkonflikts in
  `docs/25-ui-relaunch-brief.md` Abschnitt 1). Dieses Ticket liefert nur die
  Token-/Komponenten-Ebene (`SubsumoTypography.hero*`, die vier neuen
  `SubsumoColors`-Rollen, `SubsumoSection`, Fraunces-Asset) - additiv, kein
  bestehender Wert fuer App-Screens veraendert. Die tatsaechliche Umsetzung
  auf der Landingpage/Preisseite (SUB-241) und die App-Screen-Verfeinerung
  ohne Gamification (SUB-242) sind eigene Aufgaben; die dort faelligen
  docs/11-Nachtraege (Abschnitt 2.6 Scroll-Reveal-Regel) liefern diese
  Aufgaben selbst.
