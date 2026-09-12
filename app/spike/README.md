# Spike-Werkzeug: Editor-Benchmark

Kein Teil der App. Diagnosewerkzeug fuer die Entscheidung in
[`../../docs/07-spike-web-editor.md`](../../docs/07-spike-web-editor.md) —
dort stehen Methodik, Ergebnis und die Reproduktionsanleitung.

`fonts/DejaVuSans.ttf` (Bitstream-Vera-Lizenz, frei redistribuierbar) wird
nur fuer den Spike-Build lokal eingebunden, damit CanvasKit beim Messen nicht
von Googles Font-CDN abhaengt (siehe Spike-Befund 2). Er ist kein Teil der
echten App - dort wird eine eigene Schriftart reguraer als Flutter-Asset
eingebunden (M1-Actionpunkt).
