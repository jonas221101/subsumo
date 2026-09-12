import 'package:flutter/material.dart';

/// Ruhige, textlastige Oberflaeche. Juristische Inhalte sind lang - Kontrast
/// und Zeilenlaenge entscheiden ueber die Lesbarkeit, nicht Farbigkeit.
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1F3A5F),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(fontSize: 15, height: 1.5),
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
