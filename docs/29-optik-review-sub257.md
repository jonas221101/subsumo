# Optik-Review: UI-Relaunch-Brief gegen den gelieferten Build (SUB-257)

> **Auftrag** ([SUB-257](/SUB/issues/SUB-257), Kind von [SUB-254](/SUB/issues/SUB-254)
> Abschnitt 6/7 Punkt 3): Sichtprüfung am laufenden Build gegen
> `docs/25-ui-relaunch-brief.md`, über alle Seiten unter `app/lib/pages/`.
> Befunde nach Schwere geordnet, ausdrücklich getrennt in *vor Code-Freeze
> 28.09.* und *nach Release*.
>
> **Methode:** Release-Web-Build (`flutter run -d web-server --release`)
> gegen ein lokales Backend mit echtem Content (60 Themen, 444 Karten, 64
> Schemata, 60 Fälle), per `agent-browser`/Playwright bei zwei Fensterbreiten
> besucht — 1400px (Desktop) und 390px (Handy-Portrait, unter dem
> 800px-Breakpoint aus docs/25 Abschnitt 3). Alle öffentlichen Seiten,
> Login/Registrierung, Dashboard, Karteikarten, Schemata, Fälle, Gutachten
> und Konto wurden durchlaufen. Screenshots liegen als Anhänge an diesem
> Ticket.
>
> **Nicht geprüft:** Checkout-Seite visuell — in dieser Umgebung ist
> `paywall_enabled=false` (siehe `docs/26-projektreview-sub254.md`
> Abschnitt 3.1), jeder Testnutzer ist automatisch Pro, der "Pro
> werden"-Button erscheint daher nicht. Beurteilung dort nur per Code-Lesung
> (`checkout_page.dart`), keine Sichtprüfung.

---

## 1. Gesamtbild

Der Relaunch-Brief ist auf der Landingpage weitgehend eingelöst, nicht nur
strukturell (Token-Ebene aus PR #64), sondern sichtbar im laufenden Build:
vollbreite Farbbänder statt Einheitsspalte, ein tragender Hero mit
`heroLarge`/Fraunces, das abstrakte Subsumtions-Motiv, drei kategorische
Rechtsgebiets-Akzenttöne, Akkordeon-FAQ, dunkles Footer-Bookend. Die
App-Screens (Dashboard, Karten, Schemata, Fälle, Gutachten) sind sachlich,
ampelfrei und handwerklich ruhig geblieben, wie Abschnitt 6 des Briefs es
verlangt. `flutter analyze` läuft ohne Meldung.

Zwei echte Layoutbrüche wurden gefunden (Abschnitt 2), beide klein und
isoliert reparierbar. Ein Stück des Briefs (Login-/Rechtstexte-Rahmen) ist
im Code nicht umgesetzt, aber vom Brief selbst als Feinschliff-Aufgabe
eingestuft (Abschnitt 3).

---

## 2. Vor dem Freeze (28.09.) noch machbar — klein und isoliert

### 2.1 Rechtsgebiets-Chips laufen aus der Karte (mittel)

**Fundort:** Landingpage, Sektion "Die drei Rechtsgebiete"
(`app/lib/pages/public/public_landing_page.dart`, `_RechtsgebietTile`) —
reproduzierbar bei **beiden** geprüften Fensterbreiten (1400px und 390px),
also kein Breakpoint-Problem, sondern ein Widget-Bug.

Jede Karte ist auf `SizedBox(width: 220)` begrenzt und zeigt bis zu drei
`SubsumoChip`s mit den echten Themennamen (`GET /v1/content/topics`, z. B.
"Anfechtung von Willenserklärungen, §§ 119 ff. BGB"). `SubsumoChip` baut
intern nur `Chip(label: Text(label))` ohne Breitenbegrenzung
(`app/lib/design/components/subsumo_chip.dart`). Ein `Wrap` verteilt zwar
mehrere Chips auf mehrere Zeilen, zwingt aber keinen einzelnen Chip in die
verfügbare Breite — bei einem langen Themennamen läuft der Chip-Text sichtbar
über den Kartenrand hinaus in die Sektionsfläche daneben, ungekürzt und ohne
Ellipse. Screenshot: `crop_chip_zoom.png` (Anhang), sichtbar auch im
Volllayout `01_landing_wide.png`.

**Reproduktion:** `/` öffnen, zur Sektion "Die drei Rechtsgebiete" scrollen.

**Behebung (klein):** `SubsumoChip.label` in `Text(..., overflow:
TextOverflow.ellipsis, maxLines: 1)` innerhalb einer `ConstrainedBox`/
`Flexible` fassen, oder die Chip-Erzeugung in `_RechtsgebietTile` auf
gekürzte Themennamen umstellen. Betrifft nur diese eine Komponente, kein
Risiko für andere Chip-Einsätze (Kartentyp, Norm-Verweis), die bisher kurze,
kontrollierte Labels nutzen.

### 2.2 Gutachten-Falltext überlappt den Feedback-Hinweis bei schmalen Fenstern (mittel)

**Fundort:** `app/lib/pages/gutachten_page.dart`, einspaltiges Layout
(`LayoutBuilder`, `constraints.maxWidth <= 900`, Zeilen 234–242): Editor und
Fallkarte stecken gemeinsam in einem festen `SizedBox(height: 420, child:
editor)`. `_buildEditor()` zeigt zuerst die `SubsumoCard` mit dem
Sachverhalt (`_case!['facts']`) in ihrer natürlichen Höhe, erst danach den
`Expanded`-Editor — bei einem langen Sachverhalt (z. B. Fall "Der Hund im
Auto", ~500 Zeichen) überschreitet allein die Fallkarte die 420px-Vorgabe.
Da `Column` nicht automatisch clippt, malt die letzte Zeile ("... kostet den
Halter 300 Euro.") über den Kartenrand hinaus und wird vom nachfolgenden
Feedback-Hinweisblock ("Schreib los...") überdeckt — für die Nutzerin
unlesbar. Screenshot: `crop_gutachten_cutoff.png` (Anhang, aus
`12_gutachten_narrow.png`).

**Reproduktion:** Bei 390px Fensterbreite registrieren → Fälle → "Der Hund
im Auto" öffnen.

**Warum vor dem Freeze:** Der Struktur-Check ist laut
`docs/26-projektreview-sub254.md` Abschnitt 4.1 eines von zwei Dingen, die
Subsumo am Starttag wirklich differenzieren — ausgerechnet dort ist der
Sachverhalt für eine nicht kleine Nutzergruppe (Handy-Breite) teilweise
unlesbar.

**Behebung (klein):** Die feste `SizedBox(height: 420)` ersetzen durch eine
Aufteilung, die nur den Editor auf eine Mindesthöhe zwingt (z. B.
`ConstrainedBox(minHeight: ...)` nur um das `TextField`), während die
Fallkarte ihre natürliche Höhe behält und die `ListView` insgesamt scrollt —
das Verhalten, das die einspaltige Variante ohnehin schon als `ListView`
anlegt, nur die künstliche Höhenklammer um beide Kinder muss weg.

---

## 3. Nach dem Release — bewusst nicht vor dem Freeze anfassen

### 3.1 Login-Rahmen setzt den Brief nicht um (klein, kein Bruch)

Brief Abschnitt 1 zählt "Login-Rahmen" ausdrücklich zu den öffentlichen
Flächen, die "deutlich mutiger" werden sollen, Abschnitt 3 verlangt dieselbe
`SubsumoSection`-Logik auch für den "äußeren Rahmen von Login". Im Code ist
`login_page.dart` weiterhin ein nackter `Scaffold` ohne `PublicScaffold`,
ohne `SubsumoSection`, ohne AppBar/Footer — pixelgleich mit dem
Vor-Relaunch-Stand (Vergleich: `docs/assets/sub-37/login_after.png`).
Screenshot: `05_login_wide.png`.

Die Rechtstexte-Seiten (`public_legal_page.dart`) sind technisch bereits in
`SubsumoSection` gefasst, aber mit der Default-Fläche (`surface0`/Weiß) —
inhaltlich sieht das Dokument dadurch weiterhin aus wie vorher, nur AppBar
(Wordmark) und Footer (dunkles Band) kommen jetzt über `PublicScaffold`
automatisch mit. Screenshot: `03_legal_impressum_wide.png`.

**Warum nach Release vertretbar:** Der Brief selbst stuft das als
Feinschliff ein (`docs/25` Abschnitt 11: "Preisseite/Login/Rechtstexte im
gleichen Detailgrad wie die Landingpage durchgeplant ... Feinschnitt ist
Aufgabe der Umsetzung"). Nichts ist kaputt, nur ungenutztes Potenzial. Ein
Umbau von `login_page.dart` auf `PublicScaffold`/`SubsumoSection` vier Tage
vor dem Freeze ist genau die Art Umbau, vor der `docs/18` Abschnitt 1 warnt
("Termin vor Umfang").

### 3.2 Preisseite bleibt sichtbar zurückhaltender als die Landingpage (kosmetisch)

`public_pricing_page.dart` nutzt zwei `SubsumoSection`-Bänder (Default +
`surface1`), aber keinen Hero-Verlauf, kein Marken-Motiv — dadurch wirkt die
Seite neben der Landingpage flach. Auch das ist laut Brief Abschnitt 11
bewusst nicht im gleichen Detailgrad geplant, kein Fehler.

---

## 4. Stichproben ohne Befund (positiv)

- **800px-Breakpoint** funktioniert konsistent: 2×2-Grid → 1 Spalte,
  3-Spalten-Rechtsgebiete → gestapelt, `NavigationRail` → `NavigationBar`
  unten, jeweils genau beim dokumentierten Wert, kein zweiter
  Breakpoint-Wert gefunden.
- **Kein Ampel-Verstoß** gefunden: Dashboard-Fortschrittsbalken, Karten- und
  Schemata-Listen zeigen keine wertabhängigen Farben; `CircleAvatar`-Suche
  in den App-Screens leer.
- **Rechtsgebiets-Akzentfarben** sind sichtbar unterschiedlich (Navy /
  Gold / Grau) und rein kategorisch — keine Bewertungslogik im Rendering.
- **Fraunces** korrekt eng begrenzt: `grep` nach `heroLarge`/`heroSmall`
  außerhalb `pages/public/` liefert keinen Treffer, Lizenzeintrag vorhanden,
  selbst gehostet (kein `fonts.gstatic.com`).
- **Pro-Preiskarte** hebt sich wie vorgeschrieben nur über Rahmenfarbe +
  `surface2` ab, keine neue Elevation-Stufe.
- **FAQ-Akkordeon**, **Footer-Band**, **Struktur-Feedback-Flächen** im
  Gutachten (surface1/surface2 statt nur Icon-Farbe) — alle wie im Brief
  beschrieben.
- Keine hartkodierten Ampel-/Warnfarben (`Colors.red/green/amber/...`)
  außerhalb der Tokens in `app/lib/pages/` gefunden.

---

## 5. Anhänge

Screenshots (Release-Build, Playwright-Kaptur bei 1400px bzw. 390px
Fensterbreite) liegen als Anhänge an [SUB-257](/SUB/issues/SUB-257):
Landingpage, Preisseite, zwei Rechtstexte, Login/Registrierung, Dashboard,
Karten, Schemata, Fälle, Gutachten, Konto — jeweils für beide Breiten, plus
die beiden Detail-Crops zu Abschnitt 2.
