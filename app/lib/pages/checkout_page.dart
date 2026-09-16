import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../design/design.dart';
import '../state.dart';
import '../theme.dart';

/// Plaene aus docs/19-kosten-preis-budget.md Abschnitt 4, unveraendert
/// uebernommen (siehe docs/20-release-g2-bezahlstrecke.md Abschnitt 2).
enum _Plan { monthly, yearly }

extension on _Plan {
  String get apiValue => switch (this) {
        _Plan.monthly => 'monthly',
        _Plan.yearly => 'yearly',
      };

  String get label => switch (this) {
        _Plan.monthly => '3,99 EUR / Monat',
        _Plan.yearly => '39 EUR / Jahr',
      };

  String get detail => switch (this) {
        _Plan.monthly => 'Monatlich kuendbar.',
        _Plan.yearly => 'Entspricht 3,25 EUR / Monat.',
      };
}

/// F2 (docs/20-release-g2-bezahlstrecke.md Abschnitt 4): zeigt beide Plaene
/// und leitet nach Auswahl extern zum Stripe-Checkout weiter. Setzt selbst
/// kein Entitlement - das passiert asynchron ueber den Webhook (B4), sobald
/// der Nutzer mit `?checkout=success` zurueckkommt (siehe
/// [CheckoutReturnBanner]).
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  _Plan? _busyPlan;
  String? _error;

  Future<void> _upgrade(_Plan plan) async {
    setState(() {
      _busyPlan = plan;
      _error = null;
    });
    try {
      final api = AppScope.of(context).api;
      final checkoutUrl = await api.createCheckoutSession(plan.apiValue);
      final uri = Uri.parse(checkoutUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        setState(() => _error = 'Checkout konnte nicht geoeffnet werden.');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Server nicht erreichbar. Bitte spaeter erneut versuchen.');
      }
    } finally {
      if (mounted) setState(() => _busyPlan = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pro werden')),
      body: ReadableWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Unbegrenzt lernen in allen Rechtsgebieten.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Spacing.md),
              const SubsumoFeedbackBlock(
                message: 'Preisgarantie: dein Preis bleibt dauerhaft bestehen, '
                    'auch wenn der Listenpreis spaeter steigt.',
                severity: FeedbackSeverity.hint,
              ),
              const SizedBox(height: Spacing.xl),
              for (final plan in _Plan.values) ...[
                _PlanCard(
                  plan: plan,
                  busy: _busyPlan == plan,
                  disabled: _busyPlan != null,
                  onSelect: () => _upgrade(plan),
                ),
                const SizedBox(height: Spacing.md),
              ],
              if (_error != null) ...[
                const SizedBox(height: Spacing.sm),
                SubsumoFeedbackBlock(message: _error!, severity: FeedbackSeverity.negative),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.busy,
    required this.disabled,
    required this.onSelect,
  });

  final _Plan plan;
  final bool busy;
  final bool disabled;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.xs),
          Text(plan.detail, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: Spacing.md),
          SubsumoButton.primary(
            label: busy ? 'Bitte warten ...' : 'Auswaehlen',
            onPressed: disabled ? null : onSelect,
          ),
        ],
      ),
    );
  }
}

/// Zeigt den Rueckkehr-Zustand nach einem Stripe-Checkout an (F2): eine
/// Bestaetigung, sobald der Webhook (B4) das Entitlement asynchron
/// freigeschaltet hat, oder einen neutralen Abbruch-Hinweis. `status` kommt
/// bewusst als Parameter statt selbst `Uri.base` zu lesen, damit dieses
/// Widget unabhaengig von der tatsaechlichen Browser-URL testbar bleibt.
class CheckoutReturnBanner extends StatefulWidget {
  const CheckoutReturnBanner({required this.status, super.key});

  /// `success` oder `cancelled` - `main.dart` filtert den rohen
  /// `?checkout=...`-Query-Parameter der aktuellen Seite bereits auf diese
  /// beiden Werte, bevor dieses Widget ueberhaupt erzeugt wird.
  final String status;

  @override
  State<CheckoutReturnBanner> createState() => _CheckoutReturnBannerState();
}

enum _ReturnOutcome { confirming, confirmed, delayed, cancelled }

class _CheckoutReturnBannerState extends State<CheckoutReturnBanner> {
  late _ReturnOutcome _outcome;

  @override
  void initState() {
    super.initState();
    if (widget.status == 'success') {
      _outcome = _ReturnOutcome.confirming;
      WidgetsBinding.instance.addPostFrameCallback((_) => _confirm());
    } else {
      _outcome = _ReturnOutcome.cancelled;
    }
  }

  Future<void> _confirm() async {
    final confirmed = await AppScope.of(context).confirmProAfterCheckout();
    if (mounted) {
      setState(() => _outcome = confirmed ? _ReturnOutcome.confirmed : _ReturnOutcome.delayed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (message, severity) = switch (_outcome) {
      _ReturnOutcome.confirming => (
          'Zahlung wird bestaetigt ...',
          FeedbackSeverity.hint,
        ),
      _ReturnOutcome.confirmed => (
          'Zahlung bestaetigt - du bist jetzt Pro.',
          FeedbackSeverity.positive,
        ),
      _ReturnOutcome.delayed => (
          'Zahlung eingegangen, die Freischaltung kann noch einen Moment '
              'dauern. Bitte gleich noch einmal pruefen.',
          FeedbackSeverity.hint,
        ),
      _ReturnOutcome.cancelled => ('Zahlung abgebrochen.', FeedbackSeverity.neutral),
    };

    return SubsumoCard(
      child: Row(
        children: [
          if (_outcome == _ReturnOutcome.confirming) ...[
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: Spacing.md),
          ],
          Expanded(child: SubsumoFeedbackBlock(message: message, severity: severity)),
        ],
      ),
    );
  }
}
