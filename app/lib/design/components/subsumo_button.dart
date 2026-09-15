import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

enum SubsumoButtonVariant { primary, secondary, tertiary }

/// Drei Gewichtsstufen statt Material-Rohwidgets direkt zu verwenden:
///
/// - `primary` (Fuellung): genau eine Handlung pro Screen, die wichtigste.
/// - `secondary` (Kontur): gleichwertige Alternative ("Erneut versuchen").
/// - `tertiary` (Text): niedrigste Prioritaet, z. B. "Konto erstellen"-Link.
///
/// Groesse und Radius kommen zentral aus theme.dart, damit ein Button in der
/// Gutachten-Seite und einer im Login gleich aussehen.
class SubsumoButton extends StatelessWidget {
  const SubsumoButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : variant = SubsumoButtonVariant.primary;

  const SubsumoButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : variant = SubsumoButtonVariant.secondary;

  const SubsumoButton.tertiary({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  }) : variant = SubsumoButtonVariant.tertiary;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SubsumoButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: Spacing.sm),
              Text(label),
            ],
          );

    return switch (variant) {
      SubsumoButtonVariant.primary => FilledButton(onPressed: onPressed, child: child),
      SubsumoButtonVariant.secondary => OutlinedButton(onPressed: onPressed, child: child),
      SubsumoButtonVariant.tertiary => TextButton(onPressed: onPressed, child: child),
    };
  }
}
