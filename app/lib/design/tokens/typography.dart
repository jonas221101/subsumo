import 'package:flutter/material.dart';

/// Typoskala. Fliesstext dominiert die App (Gutachtentexte, Falltexte,
/// Schemata) - deshalb ist body* bewusst gross genug fuer lange
/// Lesestrecken, und Ueberschriften sind zurueckhaltend gestuft statt
/// dekorativ gross.
class TypeScale {
  const TypeScale._();

  static const double bodyLarge = 16;
  static const double bodyLargeHeight = 1.5;
  static const double bodyMedium = 15;
  static const double bodyMediumHeight = 1.5;
  static const double bodySmall = 13;
  static const double bodySmallHeight = 1.4;

  static const double titleLarge = 22;
  static const double titleMedium = 17;
  static const double titleSmall = 15;

  static const FontWeight titleWeight = FontWeight.w600;

  // Display-Rolle (SUB-159, CI-Konzept freigegeben auf SUB-154): eigene
  // Typografie-Rolle fuer Ueberschriften auf Marken-/Rahmenflaechen
  // (Wortmarke, oeffentlicher Header, Login) - deutlich groesser/kraeftiger
  // gestuft als titleLarge/Medium/Small, die unveraendert in Karten,
  // Gutachten- und Klausur-Screens weiterlaufen. Nutzt bewusst weiterhin
  // die eingebettete 'Subsumo'-Schriftdatei (DejaVu Sans, siehe
  // assets/fonts/LIZENZ.md) statt einer zweiten Schriftdatei: eine echte
  // zweite Schriftfamilie braucht ein eigenes, lizenziertes Font-Asset, das
  // in diesem Ticket nicht beschafft werden konnte (laut LIZENZ.md ohnehin
  // eine spaetere, bewusste Entscheidung fuer M5/Store-Release). Die Rolle
  // unterscheidet sich darum ueber Groesse/Gewicht/Laufweite, nicht ueber
  // eine zweite Schriftdatei.
  static const double displayLarge = 32;
  static const double displayMedium = 24;
  static const FontWeight displayWeight = FontWeight.w700;
  static const double displayLetterSpacing = 0.3;
}

/// Display-Textstile als eigene [ThemeExtension], getrennt von
/// [ThemeData.textTheme] - so sickert die Display-Rolle nicht ueber die
/// geteilten Material-Rollen (`headlineSmall` etc., siehe die
/// Gutachten-Punktzahl in `gutachten_page.dart`) versehentlich in
/// Karteikarten-/Gutachten-/Klausur-Screens durch. Abruf ueber
/// `Theme.of(context).extension<SubsumoTypography>()`.
@immutable
class SubsumoTypography extends ThemeExtension<SubsumoTypography> {
  const SubsumoTypography({required this.displayLarge, required this.displayMedium});

  final TextStyle displayLarge;
  final TextStyle displayMedium;

  factory SubsumoTypography.standard() => const SubsumoTypography(
        displayLarge: TextStyle(
          fontSize: TypeScale.displayLarge,
          fontFamily: 'Subsumo',
          fontWeight: TypeScale.displayWeight,
          letterSpacing: TypeScale.displayLetterSpacing,
        ),
        displayMedium: TextStyle(
          fontSize: TypeScale.displayMedium,
          fontFamily: 'Subsumo',
          fontWeight: TypeScale.displayWeight,
          letterSpacing: TypeScale.displayLetterSpacing,
        ),
      );

  @override
  SubsumoTypography copyWith({TextStyle? displayLarge, TextStyle? displayMedium}) =>
      SubsumoTypography(
        displayLarge: displayLarge ?? this.displayLarge,
        displayMedium: displayMedium ?? this.displayMedium,
      );

  @override
  SubsumoTypography lerp(ThemeExtension<SubsumoTypography>? other, double t) {
    if (other is! SubsumoTypography) return this;
    return SubsumoTypography(
      displayLarge: TextStyle.lerp(displayLarge, other.displayLarge, t)!,
      displayMedium: TextStyle.lerp(displayMedium, other.displayMedium, t)!,
    );
  }
}
