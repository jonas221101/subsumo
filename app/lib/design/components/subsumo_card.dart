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
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) => Card(
        margin: margin,
        child: Padding(padding: padding, child: child),
      );
}
