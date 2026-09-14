import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Fortschrittsanzeige fuer Lernstaende und Struktur-Scores.
///
/// Bewusst **eine** Markenfarbe unabhaengig vom Wert - keine Ampel von rot
/// nach gruen. Ein Lernstand von 62 % ist eine Tatsache, kein Alarm
/// (Leitprinzip "Ehrlichkeit vor Motivation", docs/01-produktvision.md).
/// Screens, die frueher `mastery >= 0.8 ? Colors.green : ...` gerechnet
/// haben, ersetzen das durch diese Komponente.
class SubsumoProgressMeter extends StatelessWidget {
  const SubsumoProgressMeter({
    required this.value,
    this.label,
    this.minHeight = 8,
    super.key,
  }) : assert(value >= 0 && value <= 1, 'value ist ein Anteil zwischen 0 und 1');

  /// Anteil zwischen 0.0 und 1.0.
  final double value;

  /// Beschriftung links vom Prozentwert, z. B. "Zivilrecht".
  final String? label;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (value * 100).round();

    return Semantics(
      label: label == null ? '$percent Prozent' : '$label: $percent Prozent',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Row(
              children: [
                Expanded(child: Text(label!, style: theme.textTheme.bodyMedium)),
                const SizedBox(width: Spacing.sm),
                Text('$percent %', style: theme.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: Spacing.xs),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: value,
              minHeight: minHeight,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
