import 'package:flutter/material.dart';

/// Rohe Palette. Nicht direkt in Widgets verwenden - immer ueber
/// [buildColorScheme] bzw. [SubsumoColors] gehen, damit Light/Dark und
/// Rollen (Text auf Flaeche, Fuellung auf Flaeche) konsistent bleiben.
///
/// Kontrastwerte sind in docs/11-designsystem.md nachgerechnet.
class SubsumoPalette {
  const SubsumoPalette._();

  // Marke: gedecktes Navyblau. Bewusst kein Startup-Blau oder Gruen mit
  // hoher Saettigung - die Zielgruppe verbringt Stunden am Stueck mit
  // Fliesstext, keine Flaeche soll um Aufmerksamkeit werben.
  static const brand900 = Color(0xFF12233B);
  static const brand700 = Color(0xFF1F3A5F);
  static const brand500 = Color(0xFF3B5980);
  static const brand300 = Color(0xFF7C97B3);
  static const brand100 = Color(0xFFDCE4EC);

  // Neutral/Text ("Ink"), Light-Mode-Werte.
  static const ink900 = Color(0xFF14181D);
  static const ink700 = Color(0xFF3C434B);
  static const ink500 = Color(0xFF6B727A);
  static const ink300 = Color(0xFFB7BCC2);
  static const ink100 = Color(0xFFE7E9EC);

  // Flaechen Light. surface1/2 bewusst etwas staerker von surface0
  // abgesetzt als in der ersten Fassung (SUB-157) - Karten sollen ohne
  // staerkere Schatten (elevation.dart bleibt unveraendert) allein durch
  // die Flaechenfarbe sichtbar bleiben. Kontraste in docs/11-designsystem.md
  // Abschnitt 5 nachgerechnet.
  static const surface0Light = Color(0xFFFFFFFF);
  static const surface1Light = Color(0xFFF0F1F4);
  static const surface2Light = Color(0xFFE4E7EB);

  // Flaechen Dark, gleiche Begruendung wie Light.
  static const surface0Dark = Color(0xFF12151A);
  static const surface1Dark = Color(0xFF20242C);
  static const surface2Dark = Color(0xFF2D3340);

  // Neutral/Text, Dark-Mode-Werte.
  static const ink900Dark = Color(0xFFEDEFF2);
  static const ink700Dark = Color(0xFFC3C8CF);
  static const ink500Dark = Color(0xFF8B929B);

  // Feedback: nur fuer eine punktuelle Rueckmeldung auf eine konkrete
  // Handlung (Struktur-Finding im Gutachten, Formularfehler) - nie fuer
  // Dauerzustaende wie einen Lernstand. Bewusst entsaettigt, damit selbst
  // "negativ" nicht wie ein Alarm wirkt (Leitprinzip "Kein Druck durch
  // Design", docs/01-produktvision.md).
  static const feedbackPositive = Color(0xFF2E7D5B);
  static const feedbackHint = Color(0xFF8A6D1D);
  static const feedbackNegative = Color(0xFFA23B3B);
  static const feedbackPositiveDark = Color(0xFF7FC4A4);
  static const feedbackHintDark = Color(0xFFD9B65B);
  static const feedbackNegativeDark = Color(0xFFD98787);

  // Marken-Akzent (SUB-159, CI-Konzept freigegeben auf SUB-154): gedecktes
  // Gold/Bernstein, ausschliesslich fuer Marken-/Leerzustandsflaechen
  // (Landingpage, oeffentlicher Header) - niemals fuer Fortschritt oder
  // Feedback, das bleibt bei feedbackPositive/-Hint/-Negative oben. Bewusst
  // als eigene Konstanten statt einer Abstufung der Feedback-Farben, damit
  // ein Review eine falsche Verwendung (Akzent auf einer Fortschritts-
  // anzeige) sofort am Tokennamen erkennt.
  static const accent500 = Color(0xFF96650F);
  static const accent300 = Color(0xFFD9B15C);
}

/// Baut das Material3-[ColorScheme] aus der Palette.
///
/// Ausgangspunkt ist [ColorScheme.fromSeed] - das befuellt auch selten
/// sichtbare Rollen (z. B. inversePrimary, scrim) sinnvoll, ohne dass wir
/// sie einzeln pflegen muessen. Die Rollen, die staendig sichtbar sind
/// (Text, Flaechen, Primaerfarbe, Fehler), werden danach auf die
/// handverlesenen, kontrastgeprueften Palettenwerte gepinnt.
ColorScheme buildColorScheme(Brightness brightness) {
  final seeded = ColorScheme.fromSeed(
    seedColor: SubsumoPalette.brand700,
    brightness: brightness,
  );

  if (brightness == Brightness.dark) {
    return seeded.copyWith(
      primary: SubsumoPalette.brand300,
      onPrimary: SubsumoPalette.surface0Dark,
      primaryContainer: SubsumoPalette.brand900,
      onPrimaryContainer: SubsumoPalette.brand100,
      surface: SubsumoPalette.surface0Dark,
      onSurface: SubsumoPalette.ink900Dark,
      surfaceContainerHighest: SubsumoPalette.surface1Dark,
      onSurfaceVariant: SubsumoPalette.ink700Dark,
      outline: SubsumoPalette.ink500Dark,
      outlineVariant: SubsumoPalette.surface2Dark,
      error: SubsumoPalette.feedbackNegativeDark,
      onError: SubsumoPalette.surface0Dark,
    );
  }

  return seeded.copyWith(
    primary: SubsumoPalette.brand700,
    onPrimary: SubsumoPalette.surface0Light,
    primaryContainer: SubsumoPalette.brand100,
    onPrimaryContainer: SubsumoPalette.brand900,
    surface: SubsumoPalette.surface0Light,
    onSurface: SubsumoPalette.ink900,
    surfaceContainerHighest: SubsumoPalette.surface1Light,
    onSurfaceVariant: SubsumoPalette.ink700,
    outline: SubsumoPalette.ink300,
    outlineVariant: SubsumoPalette.ink100,
    error: SubsumoPalette.feedbackNegative,
    onError: SubsumoPalette.surface0Light,
  );
}

/// Zusaetzliche semantische Farbrollen, die Material3s [ColorScheme] nicht
/// kennt: "positiv" und "hinweis" fuer den Feedback-Block. Fuer "negativ"
/// wird bewusst die vorhandene Rolle [ColorScheme.error] wiederverwendet -
/// eine zweite Fehlerfarbe waere nur eine Quelle fuer Inkonsistenz.
@immutable
class SubsumoColors extends ThemeExtension<SubsumoColors> {
  const SubsumoColors({
    required this.feedbackPositive,
    required this.feedbackHint,
    required this.accent,
    required this.accentWash,
    required this.heroGradientStart,
    required this.heroGradientEnd,
    required this.legalAreaZivilrecht,
    required this.legalAreaStrafrecht,
    required this.legalAreaOeffentlichesRecht,
  });

  final Color feedbackPositive;
  final Color feedbackHint;

  /// Marken-Akzent - nur fuer Marken-/Leerzustandsflaechen (siehe
  /// [SubsumoPalette.accent500]), niemals fuer Fortschritt/Feedback.
  final Color accent;

  /// [accent] bei niedriger Deckkraft ueber der Flaeche - nur fuer die
  /// "Ehrlich ueber den Umfang"-Sektion der Landingpage (SUB-227/SUB-228),
  /// niedrig genug gewaehlt, dass Fliesstextkontrast darauf nicht spuerbar
  /// sinkt (nachgerechnet in docs/11-designsystem.md Abschnitt 5). Bewusst
  /// keine neue Hex-Konstante, sondern [accent] selbst mit reduzierter
  /// Deckkraft - eine zweite, fast gleiche Markenfarbe waere nur eine
  /// weitere Pflegestelle.
  final Color accentWash;

  /// Verlaufsanfang fuer das Hero-Band auf Landing-/Preisseite
  /// (`brand700`) - bewusst brightness-unabhaengig: das Hero-Band ist
  /// immer eine dunkle Markenflaeche, unabhaengig vom System-Farbschema
  /// (wie bereits `accent500` fuer die Wortmarke keine reine Light-Rolle
  /// ist, siehe SUB-159).
  final Color heroGradientStart;

  /// Verlaufsende fuer das Hero-Band (`brand900`) - dunkelster Punkt, gegen
  /// den `onPrimary`-Text (weiss) neu nachgerechnet ist (docs/11 Abschnitt
  /// 5), da er dunkler ist als das bisher gegen `brand700` geprüfte Ende.
  final Color heroGradientEnd;

  /// Drei feste, wertunabhaengige Akzenttoene zur **kategorischen**
  /// Unterscheidung der Rechtsgebiete auf oeffentlichen Flaechen (SUB-227
  /// Abschnitt 3.6) - keine Bewertung, nur Wiedererkennung. Ausdruecklich
  /// **keine** Ampel: die Zuordnung ist fest pro Gebiet, nie von einem
  /// Lernstand/einer Mastery-Zahl abgeleitet. Aus der bestehenden Palette
  /// wiederverwendet statt neuer Hex-Werte (`brand500`/`accent500`/
  /// `ink500`, je Brightness auf die Dark-Pendants gepinnt).
  final Color legalAreaZivilrecht;
  final Color legalAreaStrafrecht;
  final Color legalAreaOeffentlichesRecht;

  factory SubsumoColors.forBrightness(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final accentColor = isDark ? SubsumoPalette.accent300 : SubsumoPalette.accent500;
    return SubsumoColors(
      feedbackPositive:
          isDark ? SubsumoPalette.feedbackPositiveDark : SubsumoPalette.feedbackPositive,
      feedbackHint: isDark ? SubsumoPalette.feedbackHintDark : SubsumoPalette.feedbackHint,
      accent: accentColor,
      // withValues() statt einer const-Farbe, weil die Wash-Rolle bewusst
      // ueber accent berechnet wird statt einen eigenen Hex-Wert zu
      // pflegen - siehe Begruendung am Feld oben.
      accentWash: accentColor.withValues(alpha: 0.08),
      heroGradientStart: SubsumoPalette.brand700,
      heroGradientEnd: SubsumoPalette.brand900,
      legalAreaZivilrecht: isDark ? SubsumoPalette.brand300 : SubsumoPalette.brand500,
      legalAreaStrafrecht: accentColor,
      legalAreaOeffentlichesRecht: isDark ? SubsumoPalette.ink500Dark : SubsumoPalette.ink500,
    );
  }

  @override
  SubsumoColors copyWith({
    Color? feedbackPositive,
    Color? feedbackHint,
    Color? accent,
    Color? accentWash,
    Color? heroGradientStart,
    Color? heroGradientEnd,
    Color? legalAreaZivilrecht,
    Color? legalAreaStrafrecht,
    Color? legalAreaOeffentlichesRecht,
  }) =>
      SubsumoColors(
        feedbackPositive: feedbackPositive ?? this.feedbackPositive,
        feedbackHint: feedbackHint ?? this.feedbackHint,
        accent: accent ?? this.accent,
        accentWash: accentWash ?? this.accentWash,
        heroGradientStart: heroGradientStart ?? this.heroGradientStart,
        heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
        legalAreaZivilrecht: legalAreaZivilrecht ?? this.legalAreaZivilrecht,
        legalAreaStrafrecht: legalAreaStrafrecht ?? this.legalAreaStrafrecht,
        legalAreaOeffentlichesRecht:
            legalAreaOeffentlichesRecht ?? this.legalAreaOeffentlichesRecht,
      );

  @override
  SubsumoColors lerp(ThemeExtension<SubsumoColors>? other, double t) {
    if (other is! SubsumoColors) return this;
    return SubsumoColors(
      feedbackPositive: Color.lerp(feedbackPositive, other.feedbackPositive, t)!,
      feedbackHint: Color.lerp(feedbackHint, other.feedbackHint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentWash: Color.lerp(accentWash, other.accentWash, t)!,
      heroGradientStart: Color.lerp(heroGradientStart, other.heroGradientStart, t)!,
      heroGradientEnd: Color.lerp(heroGradientEnd, other.heroGradientEnd, t)!,
      legalAreaZivilrecht: Color.lerp(legalAreaZivilrecht, other.legalAreaZivilrecht, t)!,
      legalAreaStrafrecht: Color.lerp(legalAreaStrafrecht, other.legalAreaStrafrecht, t)!,
      legalAreaOeffentlichesRecht:
          Color.lerp(legalAreaOeffentlichesRecht, other.legalAreaOeffentlichesRecht, t)!,
    );
  }
}
