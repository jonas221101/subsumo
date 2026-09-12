import 'package:flutter/material.dart';

/// Ruhige, textlastige Oberflaeche. Juristische Inhalte sind lang - Kontrast
/// und Zeilenlaenge entscheiden ueber die Lesbarkeit, nicht Farbigkeit.
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1F3A5F),
    brightness: brightness,
  );
  // Material2021-Typografie traegt 'Roboto' fest in jedem TextStyle - ein
  // blosses ThemeData(fontFamily: ...) ueberschreibt das nicht.
  // TextTheme.apply() ist der dokumentierte Weg, das zu tun. Ohne eigene
  // Schrift wuerde Flutter Web sie zur Laufzeit von fonts.gstatic.com
  // nachladen - siehe docs/07-spike-web-editor.md, Nebenbefund 2.
  final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
  final textTheme = base.textTheme
      .apply(fontFamily: 'Subsumo')
      .copyWith(
        bodyLarge: const TextStyle(fontSize: 16, height: 1.5, fontFamily: 'Subsumo'),
        bodyMedium: const TextStyle(fontSize: 15, height: 1.5, fontFamily: 'Subsumo'),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Subsumo',
    textTheme: textTheme,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Subsumo'),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

/// Maximale Textbreite. Ueber ~70 Zeichen pro Zeile bricht die Lesbarkeit ein -
/// auf einem Windows-Vollbild sonst ein echtes Problem.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({required this.child, this.maxWidth = 760, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
