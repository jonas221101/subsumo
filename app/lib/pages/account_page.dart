import 'package:flutter/material.dart';

import '../api.dart';
import '../design/design.dart';
import '../state.dart';
import '../theme.dart';
import 'checkout_page.dart';

/// F3 (docs/20-release-g2-bezahlstrecke.md Abschnitt 4): Konto-/Einstellungsseite.
/// Existierte vorher nicht - `HomeShell` (main.dart) verlinkt ueber die AppBar
/// hierher.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _busy = false;
  String? _error;
  String? _resultMessage;

  Future<void> _confirmAndCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abo kuendigen?'),
        content: const Text(
          'Dein Zugriff bleibt in der Regel bis zum Ende der aktuellen '
          'Abrechnungsperiode bestehen. Liegt der Kauf noch keine 14 Tage '
          'zurueck, greift stattdessen das Widerrufsrecht: sofortige '
          'Kuendigung mit voller Rueckerstattung.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kuendigen'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _cancel();
  }

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _error = null;
      _resultMessage = null;
    });
    final app = AppScope.of(context);
    try {
      final result = await app.api.cancelSubscription();
      await app.refreshUser();
      if (!mounted) return;
      final mode = result['mode'] as String?;
      setState(() {
        _resultMessage = mode == 'immediate_refund'
            ? 'Widerrufen: dein Abo wurde sofort beendet, die Zahlung wird '
                'vollstaendig erstattet.'
            : 'Gekuendigt: dein Zugriff bleibt bis zum Ende der aktuellen '
                'Abrechnungsperiode bestehen.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // 409 = kein aktives Abo (siehe B5) - eine verstaendliche Meldung
        // statt des technischen Fehlertexts vom Server.
        _error = e.statusCode == 409
            ? 'Es ist aktuell kein aktives Abo hinterlegt.'
            : e.message;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _error = 'Server nicht erreichbar. Bitte spaeter erneut versuchen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Konto')),
      body: ReadableWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SubsumoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Angemeldet als', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      app.user?['email'] as String? ?? '',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.lg),
              // Steht bewusst ausserhalb von [_SubscriptionCard]: nach einer
              // Widerrufs-Kuendigung (mode: immediate_refund) wird proActive
              // sofort false, wodurch die Karte auf die Free-Ansicht wechselt -
              // die Erfolgsmeldung muss diesen Zustandswechsel ueberleben.
              if (_resultMessage != null) ...[
                SubsumoFeedbackBlock(message: _resultMessage!, severity: FeedbackSeverity.positive),
                const SizedBox(height: Spacing.lg),
              ],
              _SubscriptionCard(
                app: app,
                busy: _busy,
                error: _error,
                onCancel: _confirmAndCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.app,
    required this.busy,
    required this.error,
    required this.onCancel,
  });

  final AppState app;
  final bool busy;
  final String? error;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!app.proActive) {
      return SubsumoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Abo', style: theme.textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            const SubsumoFeedbackBlock(
              message: 'Kein aktives Pro-Abo.',
              severity: FeedbackSeverity.neutral,
            ),
            const SizedBox(height: Spacing.md),
            SubsumoButton.primary(
              label: 'Pro werden',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CheckoutPage()),
              ),
            ),
          ],
        ),
      );
    }

    final until = app.proUntil;
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Abo', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          Text('Plan: Pro', style: theme.textTheme.bodyMedium),
          const SizedBox(height: Spacing.xs),
          Text(
            until != null ? 'Naechste Abrechnung/Zugriff bis: ${_formatDate(until)}' : 'Laeuft unbefristet',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: Spacing.md),
          if (app.cancelAtPeriodEnd) ...[
            SubsumoFeedbackBlock(
              message: 'Abo bereits gekuendigt, Zugriff bis '
                  '${until != null ? _formatDate(until) : 'Ende der Abrechnungsperiode'}.',
              severity: FeedbackSeverity.hint,
            ),
          ] else ...[
            SubsumoButton.secondary(
              label: busy ? 'Bitte warten ...' : 'Kuendigen',
              onPressed: busy ? null : onCancel,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: Spacing.sm),
            SubsumoFeedbackBlock(message: error!, severity: FeedbackSeverity.negative),
          ],
        ],
      ),
    );
  }
}

/// Wie in dashboard_page.dart: bewusst ohne [DateTime.toLocal], damit ein
/// Abrechnungsende um Mitternacht UTC nicht je nach Zeitzone des Geraets auf
/// den Vor- oder Folgetag rutscht.
String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
