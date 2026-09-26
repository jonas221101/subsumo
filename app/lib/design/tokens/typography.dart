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

  // Lese-/Ueberschriften-Rollen fuer App-Screens (Relaunch "Kanzlei-
  // Editorial"): Fraunces traegt in der eingeloggten App Seitentitel,
  // Kartenfragen und grosse Kennzahlen - das ist die typografische
  // Signatur, die die App von generischen Material-Lern-Apps unterscheidet.
  // Fliesstext (body*) bleibt serifenlos, weil lange Gutachten-/Falltexte
  // auf Bildschirm in der Grotesk besser lesbar bleiben. Alle Werte bewusst
  // kleiner als heroLarge/heroSmall: das sind Arbeits-, keine Marketing-
  // Flaechen.
  static const double headingLarge = 30;
  static const double headingMedium = 22;
  static const double headingSmall = 18;
  static const double headingHeight = 1.2;
  static const FontWeight headingWeight = FontWeight.w600;
  static const double headingLetterSpacing = -0.2;

  // Grosse Kennzahl (faellige Karten, Lernstand in Prozent). Eine Zahl, die
  // gross gesetzt ist, braucht engere Laufweite und keine Zeilenhoehe.
  static const double numeral = 56;
  static const FontWeight numeralWeight = FontWeight.w500;
  static const double numeralLetterSpacing = -1.5;

  // Lesetext auf Karteikarten: die Frage steht in der Serife, etwas groesser
  // als body, damit sie wie ein gesetzter Lehrbuchsatz wirkt.
  static const double reading = 20;
  static const double readingHeight = 1.4;

  // Vorspann ("Eyebrow"): kleines, gesperrtes Label ueber Titeln und
  // Bloecken ("HEUTE", "SACHVERHALT"). Immer in Versalien gesetzt - die
  // Sperrung ersetzt das Fettgewicht.
  static const double eyebrow = 12;
  static const FontWeight eyebrowWeight = FontWeight.w600;
  static const double eyebrowLetterSpacing = 1.4;
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
    required this.headingLarge,
    required this.headingMedium,
    required this.headingSmall,
    required this.numeral,
    required this.reading,
    required this.eyebrow,
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

  /// Seitentitel in der eingeloggten App (Fraunces). Siehe [TypeScale.headingLarge].
  final TextStyle headingLarge;

  /// Blocktitel innerhalb einer Seite (Fraunces), z. B. "Rechtsgebiete".
  final TextStyle headingMedium;

  /// Titel eines Listeneintrags/einer Karte (Fraunces), z. B. Fall- oder
  /// Schematitel.
  final TextStyle headingSmall;

  /// Grosse Kennzahl (Fraunces), z. B. "12" faellige Karten oder "62 %".
  final TextStyle numeral;

  /// Kartenfrage im Lernmodus (Fraunces, Lesegroesse).
  final TextStyle reading;

  /// Gesperrtes Versal-Label ueber Titeln/Bloecken (Grotesk). Der Aufrufer
  /// setzt den Text selbst in Versalien - siehe `SubsumoEyebrow`.
  final TextStyle eyebrow;

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
        headingLarge: TextStyle(
          fontSize: TypeScale.headingLarge,
          height: TypeScale.headingHeight,
          fontFamily: 'Fraunces',
          fontWeight: TypeScale.headingWeight,
          letterSpacing: TypeScale.headingLetterSpacing,
          fontVariations: [FontVariation('wght', 600), FontVariation('opsz', 30), FontVariation('WONK', 0)],
        ),
        headingMedium: TextStyle(
          fontSize: TypeScale.headingMedium,
          height: TypeScale.headingHeight,
          fontFamily: 'Fraunces',
          fontWeight: TypeScale.headingWeight,
          letterSpacing: TypeScale.headingLetterSpacing,
          fontVariations: [FontVariation('wght', 600), FontVariation('opsz', 22), FontVariation('WONK', 0)],
        ),
        headingSmall: TextStyle(
          fontSize: TypeScale.headingSmall,
          height: TypeScale.headingHeight,
          fontFamily: 'Fraunces',
          fontWeight: TypeScale.headingWeight,
          letterSpacing: 0,
          fontVariations: [FontVariation('wght', 600), FontVariation('opsz', 18), FontVariation('WONK', 0)],
        ),
        numeral: TextStyle(
          fontSize: TypeScale.numeral,
          height: 1.0,
          fontFamily: 'Fraunces',
          fontWeight: TypeScale.numeralWeight,
          letterSpacing: TypeScale.numeralLetterSpacing,
          fontVariations: [FontVariation('wght', 500), FontVariation('opsz', 56), FontVariation('WONK', 0)],
        ),
        reading: TextStyle(
          fontSize: TypeScale.reading,
          height: TypeScale.readingHeight,
          fontFamily: 'Fraunces',
          fontWeight: FontWeight.w400,
          fontVariations: [FontVariation('wght', 400), FontVariation('opsz', 20), FontVariation('WONK', 0)],
        ),
        eyebrow: TextStyle(
          fontSize: TypeScale.eyebrow,
          fontFamily: 'Subsumo',
          fontWeight: TypeScale.eyebrowWeight,
          letterSpacing: TypeScale.eyebrowLetterSpacing,
        ),
      );

  @override
  SubsumoTypography copyWith({
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? heroLarge,
    TextStyle? heroSmall,
    TextStyle? headingLarge,
    TextStyle? headingMedium,
    TextStyle? headingSmall,
    TextStyle? numeral,
    TextStyle? reading,
    TextStyle? eyebrow,
  }) =>
      SubsumoTypography(
        displayLarge: displayLarge ?? this.displayLarge,
        displayMedium: displayMedium ?? this.displayMedium,
        heroLarge: heroLarge ?? this.heroLarge,
        heroSmall: heroSmall ?? this.heroSmall,
        headingLarge: headingLarge ?? this.headingLarge,
        headingMedium: headingMedium ?? this.headingMedium,
        headingSmall: headingSmall ?? this.headingSmall,
        numeral: numeral ?? this.numeral,
        reading: reading ?? this.reading,
        eyebrow: eyebrow ?? this.eyebrow,
      );

  @override
  SubsumoTypography lerp(ThemeExtension<SubsumoTypography>? other, double t) {
    if (other is! SubsumoTypography) return this;
    return SubsumoTypography(
      displayLarge: TextStyle.lerp(displayLarge, other.displayLarge, t)!,
      displayMedium: TextStyle.lerp(displayMedium, other.displayMedium, t)!,
      heroLarge: TextStyle.lerp(heroLarge, other.heroLarge, t)!,
      heroSmall: TextStyle.lerp(heroSmall, other.heroSmall, t)!,
      headingLarge: TextStyle.lerp(headingLarge, other.headingLarge, t)!,
      headingMedium: TextStyle.lerp(headingMedium, other.headingMedium, t)!,
      headingSmall: TextStyle.lerp(headingSmall, other.headingSmall, t)!,
      numeral: TextStyle.lerp(numeral, other.numeral, t)!,
      reading: TextStyle.lerp(reading, other.reading, t)!,
      eyebrow: TextStyle.lerp(eyebrow, other.eyebrow, t)!,
    );
  }
}
