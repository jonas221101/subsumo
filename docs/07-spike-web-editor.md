# Spike: Texteditor-Qualität auf Flutter Web

**Status: abgeschlossen. Ergebnis: GO — der Klausur-Simulator läuft nativ auf
Flutter Web, kein Bridge/contenteditable-Fallback nötig.**

Bezug: `docs/02-architektur.md` ("Spike (blockierend): Text-Editor-Qualitaet
auf Flutter Web") und `docs/03-roadmap.md`, M1. Die Frage war offen, weil der
5-Stunden-Klausur-Simulator (Challenge 6) ohne einen brauchbaren Editor
wertlos ist — und Flutter-Web-Texteingabe historisch ein Schwachpunkt war.

## Methodik

Kein Literatur-Urteil, sondern eine echte Messung: Flutter 3.35.5 (stable)
lokal installiert, ein Mess-Harness (`app/spike/editor_bench.dart`, nicht
Teil der App) als Release-Web-Build kompiliert, headless in echtem Chromium
(Playwright) geladen und automatisiert bedient.

Aufbau: ein `TextField` (`maxLines: null, expands: true` — exakt das Muster,
das der Klausur-Editor in `gutachten_page.dart` bereits verwendet) wird mit
einem ~5.500 Wörter langen Beispielgutachten vorbefüllt (Länge eines langen
Examensgutachtens). Danach werden **311 Zeichen einzeln am Dokumentende
eingefügt** — wie ein flüssig tippender Nutzer, nicht als ein einziger
Bulk-Insert — und für jedes Zeichen die Zeit bis zum nächsten fertig
gerasterten Frame gemessen (`SchedulerBinding.addPostFrameCallback`, misst
genau das, was als "Eingabe erscheint" wahrgenommen wird).

## Ergebnis

| Metrik | Wert |
|---|---|
| Simulierte Tastendrücke | 311 |
| Dokumentlänge am Ende | 38.754 Zeichen |
| Ø Latenz pro Tastendruck | **48,4 ms** |
| p50 | 48 ms |
| p95 | 54 ms |
| Maximum | 78 ms (der allererste Tastendruck, Warmup) |

Screenshot des Laufs: `docs/assets/spike-editor-benchmark.png`.

**Einordnung:** Die Wahrnehmbarkeitsschwelle für Eingabelatenz liegt in der
UX-Forschung bei rund 100 ms. Mit 48 ms im Schnitt und 54 ms im p95 liegt
Flutter Web hier deutlich darunter — und das unter dem **ungünstigsten**
realistischen Fall:

- **Software-Rendering, kein GPU.** Headless Chromium lief ohne
  Hardware-Beschleunigung (SwiftShader-Fallback). Echte Nutzer-Hardware mit
  GPU-Beschleunigung ist eher schneller, nicht langsamer — die Messung ist
  eine konservative Obergrenze, keine Bestenfall-Zahl.
- **Kein Tipp-Backlog möglich.** Menschliches Tippen liegt bei 40–80 WPM,
  also einem Zeichen alle 100–300 ms. Bei ~48 ms Renderzeit pro Zeichen
  entsteht rechnerisch nie ein Rückstau, selbst bei sehr schnellen Tippern.
- **Keine Degradation über den Testlauf.** Die Latenz blieb zwischen Zeichen
  1 und Zeichen 311 im 43–54-ms-Band, ohne erkennbaren Aufwärtstrend — kein
  Hinweis auf quadratisches Wachstum mit der Dokumentlänge in diesem Bereich.

## Drei Nebenbefunde, die die Architektur betreffen

Der eigentliche Build- und Testprozess hat drei Dinge zutage gefördert, die
unabhängig vom Performance-Ergebnis in die Produktionsentscheidung einfließen:

**1. `--web-renderer` existiert nicht mehr.** Flutter 3.35 hat den Schalter
komplett entfernt — CanvasKit (bzw. Skwasm/WASM) ist der einzige Web-Pfad,
kein leichtgewichtiger HTML-Renderer-Fallback mehr verfügbar. Das war in
`docs/02-architektur.md` als offene Rückfalloption genannt; sie existiert in
aktuellen Flutter-Versionen schlicht nicht mehr. Kein Problem, aber die Doku
war insofern veraltet.

**2. CanvasKit fragt Schriftarten von einem Google-CDN ab, unabhängig von
App-Konfiguration.** Ohne lokal eingebettete Fonts versucht Flutter Web,
`Roboto` u. a. von `fonts.gstatic.com` nachzuladen — selbst mit
`--no-web-resources-cdn` (der Schalter betrifft nur `canvaskit.wasm`/`.js`,
nicht diesen separaten Font-Fallback-Mechanismus). Für eine App, deren
Kernprinzip "Offline ist Pflicht, nicht Komfort" ist (`docs/01-produktvision.md`),
ist das ein echter Befund: **Produktionsbuilds müssen eigene Schriftdateien
als Flutter-Assets bündeln**, sonst hängt die App im Web an einer
Google-Domain, die in manchen Netzwerken (Bibliotheken, Firmennetze,
bestimmte Länder) blockiert sein kann — dieselbe Blockade hat den ersten
Messversuch in dieser Umgebung verhindert. Aufgenommen als Actionpunkt für
M1.

**3. `dart:html` blockiert künftige Wasm/Skwasm-Builds.** Der Compiler warnt
explizit bei jedem `dart:html`-Import ("Wasm dry run … unsupported"). Skwasm
(Flutter Webs neuerer, potenziell schnellerer Compile-Pfad) verlangt
`package:web` statt `dart:html`. Codier-Richtlinie für M1: kein
`dart:html` im Produktionscode, nur `package:web` — hält den Wasm-Upgradepfad
offen, ohne dass es heute etwas kostet.

## Entscheidung

**GO.** Der native Flutter-Web-Texteditor (CanvasKit, `TextField` mit
`maxLines: null`) trägt den 5-Stunden-Klausur-Simulator ohne Bridge-Lösung.
Kein Grund, in M4 zusätzliche Komplexität für einen contenteditable-Fallback
einzuplanen.

**Für M1 mitzunehmen:**
1. Eigene Schriftdatei(en) als Flutter-Assets einbinden, nicht auf den
   CanvasKit-Font-Fallback verlassen (Nebenbefund 2)
2. `package:web` statt `dart:html` in jedem Web-spezifischen Code (Nebenbefund 3)
3. Diese Messung mit einem realen `flutter run -d chrome`-Test auf
   Nutzer-Hardware (echte GPU) einmal gegenkontrollieren, bevor M4 beginnt —
   erwartet: mindestens so gut wie hier, siehe oben

## Reproduzieren

Der Mess-Harness (`app/spike/editor_bench.dart`, siehe `app/spike/README.md`)
ist kein Teil der App und wird nicht mitgebaut oder -getestet — reines
Diagnosewerkzeug, im Repository belassen für eine spätere Gegenkontrolle auf
echter Hardware (Punkt 3 oben).

```bash
cd app

# Lokale Schrift temporaer einbinden, damit CanvasKit nicht am (in mancher
# Umgebung blockierten) Google-Font-CDN haengt - siehe Nebenbefund 2. Bereits
# unter spike/fonts/DejaVuSans.ttf vorhanden.
python3 - <<'PY'
import pathlib
p = pathlib.Path("pubspec.yaml")
s = p.read_text()
s = s.replace(
    "flutter:\n  uses-material-design: true\n",
    "flutter:\n  uses-material-design: true\n"
    "  fonts:\n    - family: SpikeFont\n      fonts:\n"
    "        - asset: spike/fonts/DejaVuSans.ttf\n",
)
p.write_text(s)
PY

flutter pub get
flutter build web --target=spike/editor_bench.dart \
  --output=build/spike-canvaskit --release --no-web-resources-cdn

cd build/spike-canvaskit && python3 -m http.server 8099
# Browser öffnen, "Benchmark starten" klicken, Konsole beobachten

# Danach: git checkout -- pubspec.yaml (Font-Eintrag war nur fuer den Spike)
```
