import 'package:flutter/material.dart';

import 'design/tokens/tokens.dart';

/// Ruhige, textlastige Oberflaeche in der Anmutung eines gesetzten
/// juristischen Kommentars ("Kanzlei-Editorial"): warmes Papier als Canvas,
/// Karten mit Haarlinie statt Schatten, Serife fuer Titel und Kennzahlen,
/// Grotesk fuer den Fliesstext. Juristische Inhalte sind lang - Kontrast
/// und Zeilenlaenge entscheiden ueber die Lesbarkeit, nicht Farbigkeit.
///
/// Baut auf den Tokens in `design/tokens/` auf statt auf Einzelwerten -
/// Begruendung fuer Farben, Abstaende und Typoskala steht in
/// docs/11-designsystem.md.
ThemeData buildTheme(Brightness brightness) {
  final scheme = buildColorScheme(brightness);
  final typography = SubsumoTypography.standard();
  // Material2021-Typografie traegt 'Roboto' fest in jedem TextStyle - ein
  // blosses ThemeData(fontFamily: ...) ueberschreibt das nicht.
  // TextTheme.apply() ist der dokumentierte Weg, das zu tun. Ohne eigene
  // Schrift wuerde Flutter Web sie zur Laufzeit von fonts.gstatic.com
  // nachladen - siehe docs/07-spike-web-editor.md, Nebenbefund 2.
  final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
  final textTheme = base.textTheme.apply(fontFamily: 'Subsumo').copyWith(
        // Die Material-Headline-Rollen tragen die Serife, damit auch die
        // oeffentlichen Seiten (Landing, Preise, Rechtstexte) und das
        // Gutachten-Ergebnis dieselbe Ueberschriftenschrift haben wie die
        // App-Screens - ohne jede Seite einzeln anzufassen.
        headlineMedium: typography.headingLarge,
        headlineSmall: typography.headingMedium,
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

  // Haarlinie fuer Karten, Eingabefelder, Trenner: ein Strich statt eines
  // Schattens - auf Papier wirkt ein Schatten wie ein Fremdkoerper.
  final hairline = BorderSide(color: scheme.outlineVariant);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // Canvas ist die Papierflaeche (surface1), Karten liegen als hellere
    // surface0 darauf - Tiefe ueber den Helligkeitsschritt, nicht ueber
    // Elevation (docs/25 Abschnitt 6).
    scaffoldBackgroundColor: scheme.surfaceContainerHighest,
    fontFamily: 'Subsumo',
    textTheme: textTheme,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Subsumo'),
    extensions: [SubsumoColors.forBrightness(brightness), typography],
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerHighest,
      foregroundColor: scheme.onSurface,
      elevation: Elevation.level0,
      scrolledUnderElevation: Elevation.level0,
      centerTitle: false,
      titleTextStyle: typography.headingMedium.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: Elevation.level0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: hairline,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: textTheme.titleSmall?.copyWith(color: scheme.onSurface),
      unselectedLabelTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      useIndicator: true,
      minExtendedWidth: 224,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
      elevation: Elevation.level0,
      labelTextStyle: WidgetStatePropertyAll(textTheme.bodySmall),
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
        side: BorderSide(color: scheme.outline),
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
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: hairline,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: hairline,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.onPrimaryContainer,
      side: hairline,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
      // Farbe explizit und zustandsabhaengig: die Typoskala oben traegt
      // bewusst keine Farbe, ein Chip ohne diese Angabe waere sonst
      // weiss auf weiss.
      labelStyle: textTheme.bodySmall?.copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurface,
        ),
      ),
      secondaryLabelStyle: textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 16),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.zero),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
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
