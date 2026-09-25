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

  // Hero-Rolle (SUB-227/SUB-228, UI-Relaunch-Brief): eigene, deutlich
  // groessere Rolle ausschliesslich fuer den H1 auf Landing-/
  // Preisseiten-Hero - displayLarge/Medium bleiben unveraendert die Rolle
  // fuer Wortmarke/oeffentlichen Header/Login. Nutzt die neue Fraunces-
  // Schriftdatei (siehe assets/fonts/LIZENZ.md) statt 'Subsumo'/DejaVu Sans -
  // laut Brief ein bewusst enger Sonderfall, kein Ersatz der Wortmarken-
  // Schrift. Serifen brauchen bei grossen Groessen engere statt weitere
  // Laufweite (Gegenteil von displayLetterSpacing oben), deshalb negativ.
  // heroHeight knapp gehalten (1.05 statt der body-typischen 1.5) - ein
  // tragender Hero-Satz ist kurz, eine grosszuegige Zeilenhoehe wuerde ihn
  // nur unnoetig strecken.
  static const double heroLarge = 64;
  static const double heroSmall = 36;
  static const FontWeight heroWeight = FontWeight.w600;
  static const double heroLetterSpacing = -0.5;
  static const double heroHeight = 1.05;
}

/// Display-Textstile als eigene [ThemeExtension], getrennt von
/// [ThemeData.textTheme] - so sickert die Display-Rolle nicht ueber die
/// geteilten Material-Rollen (`headlineSmall` etc., siehe die
/// Gutachten-Punktzahl in `gutachten_page.dart`) versehentlich in
/// Karteikarten-/Gutachten-/Klausur-Screens durch. Abruf ueber
/// `Theme.of(context).extension<SubsumoTypography>()`.
@immutable
class SubsumoTypography extends ThemeExtension<SubsumoTypography> {
  const SubsumoTypography({
    required this.displayLarge,
    required this.displayMedium,
    required this.heroLarge,
    required this.heroSmall,
  });

  final TextStyle displayLarge;
  final TextStyle displayMedium;

  /// Nur fuer den H1 auf Landing-/Preisseiten-Hero (SUB-227/SUB-228),
  /// ≥800px-Breakpoint. Siehe [heroSmall] fuer <800px.
  final TextStyle heroLarge;

  /// Wie [heroLarge], aber fuer <800px - selbe Rolle, kleinere Stufe statt
  /// eines Skalierungsfaktors, damit beide Werte einzeln kontrastgeprueft
  /// und im Review nachvollziehbar bleiben.
  final TextStyle heroSmall;

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
        heroLarge: TextStyle(
          fontSize: TypeScale.heroLarge,
          height: TypeScale.heroHeight,
          fontFamily: 'Fraunces',
          fontWeight: TypeScale.heroWeight,
          letterSpacing: TypeScale.heroLetterSpacing,
          // WONK explizit auf 0 (Standard) - Fraunces' verspielte
          // Wonk-Achse widerspricht dem Leitprinzip "kein Bounce/Overshoot"
          // (SUB-153/SUB-158). opsz folgt der Schriftgroesse: Fraunces'
          // optische-Groessen-Achse ist fuer genau diesen Zweck gedacht.
          fontVariations: [FontVariation('wght', 600), FontVariation('opsz', 64), FontVariation('WONK', 0)],
        ),
        heroSmall: TextStyle(
          fontSize: TypeScale.heroSmall,
          height: TypeScale.heroHeight,
          fontFamily: 'Fraunces',
          fontWeight: TypeScale.heroWeight,
          letterSpacing: TypeScale.heroLetterSpacing,
          fontVariations: [FontVariation('wght', 600), FontVariation('opsz', 36), FontVariation('WONK', 0)],
        ),
      );

  @override
  SubsumoTypography copyWith({
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? heroLarge,
    TextStyle? heroSmall,
  }) =>
      SubsumoTypography(
        displayLarge: displayLarge ?? this.displayLarge,
        displayMedium: displayMedium ?? this.displayMedium,
        heroLarge: heroLarge ?? this.heroLarge,
        heroSmall: heroSmall ?? this.heroSmall,
      );

  @override
  SubsumoTypography lerp(ThemeExtension<SubsumoTypography>? other, double t) {
    if (other is! SubsumoTypography) return this;
    return SubsumoTypography(
      displayLarge: TextStyle.lerp(displayLarge, other.displayLarge, t)!,
      displayMedium: TextStyle.lerp(displayMedium, other.displayMedium, t)!,
      heroLarge: TextStyle.lerp(heroLarge, other.heroLarge, t)!,
      heroSmall: TextStyle.lerp(heroSmall, other.heroSmall, t)!,
    );
  }
}
