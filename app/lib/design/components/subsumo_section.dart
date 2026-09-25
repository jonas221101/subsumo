import 'package:flutter/material.dart';

import '../../theme.dart';
import '../tokens/tokens.dart';

/// Feste, tokenisierte Hintergrundflaechen fuer [SubsumoSection] - bewusst
/// ein Enum statt eines freien Color-/Gradient-Parameters, damit jede
/// oeffentliche Seite aus demselben, kontrastgeprueften Vokabular waehlt
/// statt eigene Verlaeufe/Deckkraeften zu erfinden (SUB-227/SUB-228,
/// docs/25-ui-relaunch-brief.md Abschnitt 3).
enum SubsumoSectionBackground {
  /// Neutrale Standardflaeche (`colorScheme.surface`).
  surface0,

  /// Etwas abgesetzte Flaeche fuer den Wechsel zwischen Sektionen
  /// (`colorScheme.surfaceContainerHighest`, siehe SUB-157).
  surface1,

  /// Verlauf `brand700` -> `brand900` - nur fuer das Hero-Band. Text darauf
  /// braucht die `onPrimary`-Rolle (weiss), siehe docs/11 Abschnitt 5.
  heroGradient,

  /// [SubsumoColors.accentWash] auf der Standardflaeche - nur fuer die
  /// "Ehrlich ueber den Umfang"-Sektion, niedrige Deckkraft damit der
  /// Fliesstextkontrast nicht spuerbar sinkt.
  accentWash,

  /// Durchgehend dunkle Markenflaeche (`brand900`) - fuer den Footer als
  /// Bookend-Kontrast zum Hero.
  brandDark,
}

/// Randloses Band mit eigener Hintergrundflaeche, das seinen Inhalt
/// weiterhin ueber [ReadableWidth] innen auf Lesebreite begrenzt (SUB-227
/// Abschnitt 3, SUB-228/SUB-240). Ersetzt die pauschale `maxWidth`-Zwang in
/// `PublicScaffold` fuer oeffentliche Flaechen - jede Sektion entscheidet
/// selbst ueber ihre Hintergrundfarbe, `PublicScaffold` reicht nur noch
/// AppBar/Footer/Fensterbreite durch (Folgeaufgabe SUB-241).
///
/// Bewusst nur fuer `pages/public/*` - Karteikarten-/Gutachten-/
/// Klausur-Screens bleiben bei `SubsumoCard`/direktem `Theme.of(context)`.
class SubsumoSection extends StatelessWidget {
  const SubsumoSection({
    required this.child,
    this.background = SubsumoSectionBackground.surface0,
    this.padding = const EdgeInsets.symmetric(vertical: Spacing.xxxl, horizontal: Spacing.xl),
    this.maxContentWidth = 760,
    super.key,
  });

  final Widget child;
  final SubsumoSectionBackground background;

  /// Innenabstand des Bandes - Vorgabe der aufrufenden Sektion, da
  /// Hero/FAQ/Footer unterschiedlich viel vertikalen Raum brauchen.
  final EdgeInsetsGeometry padding;

  /// An [ReadableWidth.maxWidth] durchgereicht. Standard 760 (Fliesstext-
  /// Sektionen); mehrspaltige Sektionen (Grid, 3-Spalten-Reihe) geben einen
  /// groesseren Wert mit.
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<SubsumoColors>()!;

    final Decoration decoration = switch (background) {
      SubsumoSectionBackground.surface0 => BoxDecoration(color: scheme.surface),
      SubsumoSectionBackground.surface1 =>
        BoxDecoration(color: scheme.surfaceContainerHighest),
      SubsumoSectionBackground.heroGradient => BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.heroGradientStart, colors.heroGradientEnd],
          ),
        ),
      SubsumoSectionBackground.accentWash =>
        BoxDecoration(color: Color.alphaBlend(colors.accentWash, scheme.surface)),
      SubsumoSectionBackground.brandDark =>
        BoxDecoration(color: colors.heroGradientEnd),
    };

    return DecoratedBox(
      decoration: decoration,
      child: Center(
        child: ReadableWidth(
          maxWidth: maxContentWidth,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
