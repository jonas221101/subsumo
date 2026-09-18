import 'package:flutter/material.dart';

import 'design/tokens/tokens.dart';

/// Ruhige, textlastige Oberflaeche. Juristische Inhalte sind lang - Kontrast
/// und Zeilenlaenge entscheiden ueber die Lesbarkeit, nicht Farbigkeit.
///
/// Baut auf den Tokens in `design/tokens/` auf statt auf Einzelwerten -
/// Begruendung fuer Farben, Abstaende und Typoskala steht in
/// docs/11-designsystem.md.
ThemeData buildTheme(Brightness brightness) {
  final scheme = buildColorScheme(brightness);
  // Material2021-Typografie traegt 'Roboto' fest in jedem TextStyle - ein
  // blosses ThemeData(fontFamily: ...) ueberschreibt das nicht.
  // TextTheme.apply() ist der dokumentierte Weg, das zu tun. Ohne eigene
  // Schrift wuerde Flutter Web sie zur Laufzeit von fonts.gstatic.com
  // nachladen - siehe docs/07-spike-web-editor.md, Nebenbefund 2.
  final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
  final textTheme = base.textTheme.apply(fontFamily: 'Subsumo').copyWith(
        titleLarge: const TextStyle(
          fontSize: TypeScale.titleLarge,
          fontFamily: 'Subsumo',
          fontWeight: TypeScale.titleWeight,
        ),
        titleMedium: const TextStyle(
          fontSize: TypeScale.titleMedium,
          fontFamily: 'Subsumo',
          fontWeight: TypeScale.titleWeight,
        ),
        titleSmall: const TextStyle(
          fontSize: TypeScale.titleSmall,
          fontFamily: 'Subsumo',
          fontWeight: TypeScale.titleWeight,
        ),
        bodyLarge: const TextStyle(
          fontSize: TypeScale.bodyLarge,
          height: TypeScale.bodyLargeHeight,
          fontFamily: 'Subsumo',
        ),
        bodyMedium: const TextStyle(
          fontSize: TypeScale.bodyMedium,
          height: TypeScale.bodyMediumHeight,
          fontFamily: 'Subsumo',
        ),
        bodySmall: const TextStyle(
          fontSize: TypeScale.bodySmall,
          height: TypeScale.bodySmallHeight,
          fontFamily: 'Subsumo',
        ),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Subsumo',
    textTheme: textTheme,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Subsumo'),
    extensions: [SubsumoColors.forBrightness(brightness), SubsumoTypography.standard()],
    cardTheme: CardThemeData(
      elevation: Elevation.level1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
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
