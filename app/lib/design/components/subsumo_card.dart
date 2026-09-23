import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Standard-Behaelter fuer inhaltliche Bloecke (Kartenfrage, Fallbeschreibung,
/// Struktur-Feedback, Ergebnis). Radius und Erhebung kommen aus
/// `Theme.of(context).cardTheme` (siehe theme.dart) - hier wird nur der
/// Innenabstand vereinheitlicht, den bisher jeder Screen einzeln gewaehlt
/// hat.
class SubsumoCard extends StatelessWidget {
  const SubsumoCard({
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.margin,
    this.color,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// Ohne Angabe nutzt [Card] die Themevorgabe. Explizit gesetzt fuer Karten,
  /// die sich bewusst per Flaeche (statt einer weiteren Elevation-Stufe) von
  /// gleichrangigen Elementen absetzen sollen, z. B. die Coverage-Hero-Karte
  /// im Dashboard (`colorScheme.surfaceContainerHighest`, docs/25 Abschnitt 6).
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
        margin: margin,
        color: color,
        child: Padding(padding: padding, child: child),
      );
}
