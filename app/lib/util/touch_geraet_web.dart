import 'package:web/web.dart' as web;

/// Web: Geraet mit grobem Hauptzeiger (Touchscreen) und ohne feinen Zeiger.
/// Erkennt Tablets auch dann, wenn Flutter noch kein Touch-Ereignis gesehen hat
/// (z. B. Taps ueber die Bedienungshilfen-Ebene, Nutzertest W12).
bool istTouchGeraet() =>
    web.window.matchMedia('(pointer: coarse)').matches &&
    !web.window.matchMedia('(any-pointer: fine)').matches;
