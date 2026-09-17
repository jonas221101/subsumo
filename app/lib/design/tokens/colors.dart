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
  const SubsumoColors({required this.feedbackPositive, required this.feedbackHint});

  final Color feedbackPositive;
  final Color feedbackHint;

  factory SubsumoColors.forBrightness(Brightness brightness) =>
      brightness == Brightness.dark
          ? const SubsumoColors(
              feedbackPositive: SubsumoPalette.feedbackPositiveDark,
              feedbackHint: SubsumoPalette.feedbackHintDark,
            )
          : const SubsumoColors(
              feedbackPositive: SubsumoPalette.feedbackPositive,
              feedbackHint: SubsumoPalette.feedbackHint,
            );

  @override
  SubsumoColors copyWith({Color? feedbackPositive, Color? feedbackHint}) => SubsumoColors(
        feedbackPositive: feedbackPositive ?? this.feedbackPositive,
        feedbackHint: feedbackHint ?? this.feedbackHint,
      );

  @override
  SubsumoColors lerp(ThemeExtension<SubsumoColors>? other, double t) {
    if (other is! SubsumoColors) return this;
    return SubsumoColors(
      feedbackPositive: Color.lerp(feedbackPositive, other.feedbackPositive, t)!,
      feedbackHint: Color.lerp(feedbackHint, other.feedbackHint, t)!,
    );
  }
}
