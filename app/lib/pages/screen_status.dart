import 'package:flutter/material.dart';

import '../design/design.dart';

/// Einheitliche Lade-, Fehler- und Leerzustaende fuer die sechs Hauptscreens.
///
/// Vorher hatte jeder Screen seine eigene Variante (mal nur ein Spinner, mal
/// Klartext ohne Icon, mal gar kein Hinweis bei leeren Listen). Baut auf
/// [SubsumoFeedbackBlock] auf, damit Icon/Farbe zur Bedeutung passen statt
/// pro Screen neu erfunden zu werden.
class ScreenStatus extends StatelessWidget {
  const ScreenStatus.loading({super.key})
      : message = null,
        detail = null,
        severity = FeedbackSeverity.neutral,
        onRetry = null,
        retryLabel = null,
        _loading = true;

  const ScreenStatus.error({
    required String this.message,
    this.detail,
    this.onRetry,
    this.retryLabel = 'Erneut versuchen',
    super.key,
  })  : severity = FeedbackSeverity.negative,
        _loading = false;

  const ScreenStatus.empty({
    required String this.message,
    this.detail,
    this.severity = FeedbackSeverity.hint,
    this.onRetry,
    this.retryLabel = 'Neu laden',
    super.key,
  }) : _loading = false;

  final String? message;
  final String? detail;
  final FeedbackSeverity severity;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final bool _loading;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SubsumoFeedbackBlock(message: message!, detail: detail, severity: severity),
            if (onRetry != null) ...[
              const SizedBox(height: Spacing.lg),
              SubsumoButton.secondary(label: retryLabel!, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
