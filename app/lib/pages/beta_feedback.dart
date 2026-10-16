import 'package:flutter/material.dart';

import '../api.dart';
import '../design/design.dart';
import '../state.dart';

const _categories = [
  (value: 'fehler', label: 'Fehler / etwas klappt nicht'),
  (value: 'inhalt', label: 'Juristischer Inhalt'),
  (value: 'bedienung', label: 'Bedienung / Verständlichkeit'),
  (value: 'idee', label: 'Idee / Wunsch'),
  (value: 'sonstiges', label: 'Sonstiges'),
];

/// Feedback-Dialog des Test-Zugangs ([kBetaMode]). [screen] ist der aktuell
/// offene Bereich und wird mitgeschickt, damit Rueckmeldungen zuordenbar sind.
Future<void> showBetaFeedbackDialog(BuildContext context,
        {required String screen}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _BetaFeedbackDialog(screen: screen),
    );

class _BetaFeedbackDialog extends StatefulWidget {
  const _BetaFeedbackDialog({required this.screen});

  final String screen;

  @override
  State<_BetaFeedbackDialog> createState() => _BetaFeedbackDialogState();
}

class _BetaFeedbackDialogState extends State<_BetaFeedbackDialog> {
  final _message = TextEditingController();
  String _category = _categories.first.value;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) {
      setState(() => _error = 'Bitte kurz beschreiben, worum es geht.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await AppScope.of(context).api.sendFeedback(
            message: _message.text.trim(),
            category: _category,
            screen: widget.screen,
          );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Danke! Dein Feedback ist angekommen.')),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on Exception {
      setState(() => _error =
          'Senden fehlgeschlagen - bitte später noch einmal versuchen.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Feedback geben'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bereich: ${widget.screen}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Spacing.md),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Art'),
                items: [
                  for (final c in _categories)
                    DropdownMenuItem(value: c.value, child: Text(c.label)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: Spacing.md),
              SubsumoTextField(
                label: 'Was ist dir aufgefallen?',
                hintText:
                    'z. B. "Karte X: Definition unvollständig, es fehlt ..."',
                controller: _message,
                maxLines: 6,
              ),
              if (_error != null) ...[
                const SizedBox(height: Spacing.md),
                SubsumoFeedbackBlock(
                    message: _error!, severity: FeedbackSeverity.negative),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Sende ...' : 'Senden'),
        ),
      ],
    );
  }
}

/// Feedback-Schaltflaeche fuer `AppBar.actions` von per Navigator gepushten
/// Screens (Fall, Deck, Konto ...). Rendert nur im Test-Zugang ([kBetaMode],
/// oder erzwungen ueber [force] in Tests) und sonst nichts. [screen] landet
/// als Bereichsangabe im Feedback, z. B. "Fall: Wohnungseinbruchdiebstahl".
class BetaFeedbackAction extends StatelessWidget {
  const BetaFeedbackAction({required this.screen, this.force = false, super.key});

  final String screen;

  /// Nur fuer Tests: `kBetaMode` ist eine Compile-Zeit-Konstante.
  @visibleForTesting
  final bool force;

  @override
  Widget build(BuildContext context) {
    if (!kBetaMode && !force) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Feedback geben',
      icon: const Icon(Icons.rate_review_outlined),
      onPressed: () => showBetaFeedbackDialog(context, screen: screen),
    );
  }
}
