import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

enum FeedbackSeverity { positive, hint, negative, neutral }

/// Textliche Rueckmeldung auf eine konkrete Handlung: ein Struktur-Finding
/// im Gutachten, ein Formularfehler, ein Hinweis im leeren Zustand.
///
/// Ausdruecklich **nicht** fuer Dauerzustaende wie Lernfortschritt gedacht -
/// dafuer ist [SubsumoProgressMeter] da. Farbe ist immer nur ein kleines
/// Icon, nie eine vollflaechige Einfaerbung - selbst ein Fehlerhinweis soll
/// sachlich wirken, nicht wie ein Alarm.
class SubsumoFeedbackBlock extends StatelessWidget {
  const SubsumoFeedbackBlock({
    required this.message,
    this.severity = FeedbackSeverity.neutral,
    this.detail,
    this.iconSize = 20,
    super.key,
  });

  final String message;
  final String? detail;
  final FeedbackSeverity severity;

  /// Groesser fuer Leerzustaende (siehe [ScreenStatus.empty]) - reine
  /// Groessenverfeinerung, das Icon-Vokabular selbst bleibt unveraendert
  /// (docs/25-ui-relaunch-brief.md Abschnitt 6).
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subsumo = theme.extension<SubsumoColors>();

    final (icon, color, semanticLabel) = switch (severity) {
      FeedbackSeverity.positive => (
          Icons.check_circle_outline,
          subsumo?.feedbackPositive ?? theme.colorScheme.primary,
          'Positiv: ',
        ),
      FeedbackSeverity.hint => (
          Icons.info_outline,
          subsumo?.feedbackHint ?? theme.colorScheme.primary,
          'Hinweis: ',
        ),
      FeedbackSeverity.negative => (
          Icons.error_outline,
          theme.colorScheme.error,
          'Fehler: ',
        ),
      FeedbackSeverity.neutral => (
          Icons.circle_outlined,
          theme.colorScheme.onSurfaceVariant,
          '',
        ),
    };

    return Semantics(
      label: '$semanticLabel$message${detail == null ? '' : '. $detail'}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: theme.textTheme.bodyMedium),
                if (detail != null) ...[
                  const SizedBox(height: Spacing.xs),
                  Text(detail!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
