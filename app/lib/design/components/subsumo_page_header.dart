import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'subsumo_eyebrow.dart';

/// Seitenkopf der eingeloggten App: Eyebrow, Serifen-Titel, optional eine
/// Unterzeile und rechts eine Aktion. Jede Seite beginnt mit genau einem
/// davon - so hat die App eine wiedererkennbare Kopfzeile, ohne dass die
/// AppBar den Titel tragen muss (dort steht auf schmalen Geraeten die
/// Wortmarke).
class SubsumoPageHeader extends StatelessWidget {
  const SubsumoPageHeader({
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = theme.extension<SubsumoTypography>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                SubsumoEyebrow(eyebrow!),
                const SizedBox(height: Spacing.sm),
              ],
              Text(title, style: typography.headingLarge.copyWith(color: theme.colorScheme.onSurface)),
              if (subtitle != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: Spacing.lg),
          trailing!,
        ],
      ],
    );
  }
}
