import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Skalenwert als Punktreihe (z. B. Pruefungsrelevanz 4/5, Schwierigkeit
/// 2/5): [value] von [max] Punkten gefuellt, der Rest nur umrissen.
///
/// Bewusst **eine** Farbe unabhaengig vom Wert - eine Relevanz von 5 ist
/// eine Eigenschaft des Themas, keine Warnung (Ampel-Verbot, docs/11
/// Abschnitt 1). Nicht fuer Lernstaende gedacht: dafuer ist
/// [SubsumoProgressMeter] da, das einen Anteil statt einer Stufe zeigt.
class SubsumoDots extends StatelessWidget {
  const SubsumoDots({
    required this.value,
    required this.label,
    this.max = 5,
    this.size = 8,
    super.key,
  })  : assert(max > 0, 'max muss positiv sein'),
        assert(value >= 0 && value <= max, 'value liegt zwischen 0 und max');

  final int value;
  final int max;

  /// Bedeutung der Skala fuer Screenreader, z. B. "Relevanz" -> "Relevanz 4
  /// von 5".
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label $value von $max',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < max; i++)
            Padding(
              padding: EdgeInsets.only(right: i == max - 1 ? 0 : Spacing.xs),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < value ? scheme.primary : Colors.transparent,
                  border: Border.all(color: i < value ? scheme.primary : scheme.outline),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
