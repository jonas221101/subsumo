import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import '../../state.dart';
import 'public_scaffold.dart';

/// Preisseite (`/preise`), oeffentlich ohne Login erreichbar (SUB-108).
///
/// Schaltet zwischen Variante A (mit Kauf, docs/21 Abschnitt 3.1) und
/// Variante B (Early Access, docs/21 Abschnitt 3.2) anhand von
/// `paywall_enabled` aus dem oeffentlichen Feature-Flag-Endpoint (SUB-107,
/// `GET /v1/public/config`). Die zusaetzliche Abnahme-Bedingung "UND G1
/// (Zahlungskonto/Rechtstraeger) steht" bildet sich bewusst nicht als eigene
/// Pruefung ab - dafuer gibt es keinen technischen Zustand, siehe die
/// Abnahme zu SUB-110: `paywall_enabled` wird operativ ohnehin erst nach G1
/// auf `true` gesetzt.
///
/// Ein Fehler beim Laden des Flags (z. B. kein Netz) faellt auf Variante B
/// zurueck - der gleiche Notausgang, den docs/21 Abschnitt 3 fuer eine noch
/// nicht startklare Paywall vorsieht, statt faelschlich Zahlung zu verlangen.
class PublicPricingPage extends StatefulWidget {
  const PublicPricingPage({super.key});

  @override
  State<PublicPricingPage> createState() => _PublicPricingPageState();
}

class _PublicPricingPageState extends State<PublicPricingPage> {
  Future<bool>? _paywallEnabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _paywallEnabled ??= _loadPaywallEnabled();
  }

  Future<bool> _loadPaywallEnabled() async {
    final api = AppScope.of(context).api;
    try {
      final config = await api.publicConfig();
      return config['paywall_enabled'] == true;
    } on Exception {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PublicScaffold(
      child: FutureBuilder<bool>(
        future: _paywallEnabled,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SubsumoSection(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data == true ? const _VarianteA() : const _VarianteB();
        },
      ),
    );
  }
}

/// Variante A - mit Kauf (docs/21 Abschnitt 3.1). Texte wortgleich
/// uebernommen. Zwei Baender statt einer Spalte (SUB-241, gleiche
/// `SubsumoSection`-Logik wie die Landingpage): Tabelle/CTA vorn, die
/// Gruenderpreis-Begruendung auf einer eigenen, abgesetzten Flaeche.
class _VarianteA extends StatelessWidget {
  const _VarianteA();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubsumoSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preise', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: Spacing.lg),
              const _FeatureTable(
                proHeader: 'Pro (Gründerpreis)',
                priceRow: (
                  free: '0 €',
                  pro: '3,99 €/Monat oder 39 €/Jahr (inkl. gesetzlicher USt., sofern diese anfällt)',
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: SubsumoButton.primary(
                  label: 'Pro werden',
                  onPressed: () => context.go('/app'),
                ),
              ),
            ],
          ),
        ),
        SubsumoSection(
          background: SubsumoSectionBackground.surface1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Warum Gründerpreis?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'Subsumo startet mit 180 Karten — deutlich weniger als etablierte '
                'Anbieter. Der Preis liegt deshalb bewusst niedrig, und wer jetzt '
                'einsteigt, behält ihn dauerhaft, auch wenn Umfang und Listenpreis '
                'wachsen.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                'Zahlung über Stripe. Jederzeit zum Ende der laufenden Laufzeit '
                'kündbar, Details in den AGB.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Variante B - Early Access (docs/21 Abschnitt 3.2). Texte wortgleich
/// uebernommen; Feature-Tabelle wie Variante A, nur die Pro-Spalte
/// umbenannt. Zwei Baender wie Variante A (SUB-241).
class _VarianteB extends StatelessWidget {
  const _VarianteB();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubsumoSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preise', style: Theme.of(context).textTheme.headlineMedium),
              Text(
                '(Early Access)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                'Subsumo ist gerade gestartet. Die Bezahlstrecke ist noch nicht '
                'live — bis dahin nutzt du Subsumo im vollen Pro-Umfang kostenlos: '
                'alle drei Rechtsgebiete, unbegrenzte Karten, Schemata, Fälle und '
                'Struktur-Checks.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Spacing.md),
              Text(
                'Sobald die Bezahlstrecke startet, wechseln wir auf Free/Pro. Der '
                'Pro-Tarif kostet dann ab 3,99 €/Monat (39 €/Jahr) — mit '
                'Gründerpreis-Garantie: Wer sich jetzt registriert, sichert sich '
                'diesen Preis dauerhaft, auch wenn er für später hinzukommende '
                'Nutzer:innen steigt.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Spacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: SubsumoButton.primary(
                  label: 'Kostenlos registrieren und Preis sichern',
                  onPressed: () => context.go('/app'),
                ),
              ),
            ],
          ),
        ),
        const SubsumoSection(
          background: SubsumoSectionBackground.surface1,
          child: _FeatureTable(
            proHeader: 'Pro (kommt bald, aktuell für alle inklusive)',
            priceRow: (
              free: '0 €',
              pro: '3,99 €/Monat oder 39 €/Jahr (inkl. gesetzlicher USt., sofern diese anfällt)',
            ),
          ),
        ),
      ],
    );
  }
}

/// Feature-Tabelle Free/Pro, identisch in Variante A und B (docs/21
/// Abschnitt 3.2: "Feature-Tabelle wie Variante A, Spalte 'Pro' umbenannt").
class _FeatureTable extends StatelessWidget {
  const _FeatureTable({required this.proHeader, required this.priceRow});

  final String proHeader;
  final ({String free, String pro}) priceRow;

  static const _rows = [
    ('Karteikarten', '20 fällige Karten/Tag, ein Rechtsgebiet', 'unbegrenzt, alle drei Rechtsgebiete'),
    ('Schemata', 'Lesen', 'Lesen + Reihenfolge-Drill'),
    ('Geführte Fälle', '2', 'alle'),
    ('Struktur-Check', '3/Woche', 'unbegrenzt'),
    (
      'Preisgarantie',
      '—',
      'Bestandspreis bleibt dauerhaft, auch wenn der Listenpreis für Neukund:innen steigt',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.titleSmall;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        TableRow(
          children: [
            const SizedBox(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: Text('Free', style: headerStyle),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: Text(proHeader, style: headerStyle),
            ),
          ],
        ),
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: Text('Preis', style: bodyStyle),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: Text(priceRow.free, style: bodyStyle),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: Text(priceRow.pro, style: bodyStyle),
            ),
          ],
        ),
        for (final (label, free, pro) in _rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: Text(label, style: bodyStyle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: Text(free, style: bodyStyle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: Text(pro, style: bodyStyle),
              ),
            ],
          ),
      ],
    );
  }
}
