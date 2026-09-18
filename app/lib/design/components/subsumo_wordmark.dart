import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Wortmarke "Subsumo" in der Display-Typografie-Rolle - ausschliesslich
/// fuer Marketing-/Rahmenflaechen (oeffentlicher Header in
/// `PublicScaffold`, Login-Kopfzeile), nie in Karteikarten-/Gutachten-/
/// Klausur-Screens (Abnahme SUB-159, CI-Konzept freigegeben auf SUB-154).
/// Bewusst reine Wortmarke ohne Icon/Symbol - das im Konzept genannte
/// abstrakte Symbol ist dort ausdruecklich optional und ohne finales
/// Asset, dieses Ticket setzt nur den freigegebenen Wortmarken-Teil um.
class SubsumoWordmark extends StatelessWidget {
  const SubsumoWordmark({this.large = false, this.accent = false, super.key});

  /// `true` fuer die groessere Display-Rolle (z. B. Login-Kopfzeile), sonst
  /// die mittlere Rolle (z. B. AppBar-Titel).
  final bool large;

  /// Zweifarbige Wortmarken-Variante (letzter Buchstabe im Markenakzent) -
  /// laut Konzept nur auf tatsaechlichen Landingpage-/Marketing-Flaechen,
  /// niemals als Ersatz fuer die Navy-Hauptfarbe.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = theme.extension<SubsumoTypography>()!;
    final style = (large ? display.displayLarge : display.displayMedium)
        .copyWith(color: theme.colorScheme.primary);
    if (!accent) {
      return Text('Subsumo', style: style);
    }
    final accentColor = theme.extension<SubsumoColors>()!.accent;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'Subsum'),
          TextSpan(text: 'o', style: style.copyWith(color: accentColor)),
        ],
      ),
    );
  }
}
