import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';
import 'screen_status.dart';

/// Wissenslandkarte (Challenge 3).
///
/// Bewusst ehrlich: gezaehlt wird nur, was reif ist. "Schon mal gesehen"
/// zaehlt nicht - sonst waere die Zahl wertlos. Aus demselben Grund zeigt
/// diese Seite als Erstbeispiel fuer das Designsystem (docs/11-designsystem.md),
/// wie eine Fortschrittsanzeige *ohne* Ampelfarbe aussieht - siehe
/// [SubsumoProgressMeter].
const _areaLabels = {
  'zivilrecht': 'Zivilrecht',
  'strafrecht': 'Strafrecht',
  'oeffentliches-recht': 'Oeffentliches Recht',
};

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context).loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final coverage = app.coverage;

    if (coverage == null) {
      return app.loading
          ? const ScreenStatus.loading()
          : ScreenStatus.error(
              message: app.error ?? 'Keine Daten',
              onRetry: app.loadDashboard,
            );
    }

    final topics = (coverage['topics'] as List).cast<Map<String, dynamic>>();
    final byArea = (coverage['by_area'] as Map).cast<String, dynamic>();
    final gesamt = (coverage['weighted_coverage'] as num).toDouble();

    return ReadableWidth(
      child: RefreshIndicator(
        onRefresh: app.loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            if (app.cancelAtPeriodEnd || !app.proActive) ...[
              _ProStatusBanner(app: app),
              const SizedBox(height: Spacing.lg),
            ],
            SubsumoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Examensrelevanter Stoff, den du sicher kannst',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    '${(gesamt * 100).round()} %',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: Spacing.sm),
                  // Eine Farbe, unabhaengig vom Wert - ein Lernstand ist eine
                  // Tatsache, keine Ampel (Leitprinzip "Ehrlichkeit vor
                  // Motivation", docs/01-produktvision.md).
                  SubsumoProgressMeter(value: gesamt),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'Gewichtet nach Pruefungsrelevanz. Gezaehlt wird nur, was '
                    'du langfristig behaeltst - nicht, was du einmal gesehen hast.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
            for (final entry in byArea.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: SubsumoProgressMeter(
                  label: _areaLabels[entry.key] ?? entry.key,
                  value: (entry.value as num).toDouble(),
                ),
              ),
            const SizedBox(height: Spacing.xl),
            Text('Themen', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            for (final topic in topics) _TopicTile(topic: topic),
          ],
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic});

  final Map<String, dynamic> topic;

  @override
  Widget build(BuildContext context) {
    final mastery = (topic['mastery'] as num).toDouble();
    final total = topic['cards_total'] as int;
    final mature = topic['cards_mature'] as int;

    // Kein Ampel-Icon mehr: der Lernstand einer Karte ist eine Tatsache,
    // keine Warnung. Ein Thema mit 0 % sicher gelernten Karten sieht darum
    // genauso "neutral" aus wie eines mit 80 % - siehe docs/11-designsystem.md.
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.menu_book_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(topic['title'] as String),
      subtitle: Text('$mature von $total Karten reif  ·  Relevanz ${topic['relevance']}/5'),
      trailing: Text('${(mastery * 100).round()} %'),
    );
  }
}

/// Persistenter Pro-Status-Hinweis (F1, siehe docs/20-release-g2-bezahlstrecke.md
/// Abschnitt 4).
///
/// Zeigt genau einen von zwei Zustaenden: eine laufende Kuendigung hat
/// Vorrang vor der allgemeinen Pro-Werbung, auch solange [AppState.proActive]
/// durch [AppState.proUntil] noch `true` ist. Bei aktivem, nicht gekuendigtem
/// Pro-Zugriff (und wenn die Paywall serverseitig aus ist, siehe
/// [AppState.proActive]) zeigt der Aufrufer diesen Banner gar nicht erst.
class _ProStatusBanner extends StatelessWidget {
  const _ProStatusBanner({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    if (app.cancelAtPeriodEnd) {
      final until = app.proUntil;
      return SubsumoCard(
        child: SubsumoFeedbackBlock(
          message: 'Abo gekuendigt, Zugriff bis '
              '${until != null ? _formatDate(until) : 'Ende der Abrechnungsperiode'}.',
          severity: FeedbackSeverity.hint,
        ),
      );
    }
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SubsumoFeedbackBlock(
            message: 'Mit Pro lernst du unbegrenzt in allen Rechtsgebieten.',
            severity: FeedbackSeverity.hint,
          ),
          const SizedBox(height: Spacing.md),
          SubsumoButton.primary(
            label: 'Pro werden',
            // F2 (Checkout-Flow) existiert noch nicht (siehe docs/20 B3/F2).
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Upgrade folgt in Kuerze.')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formatiert das Kalenderdatum, wie es der Server meint - bewusst ohne
/// [DateTime.toLocal], damit ein Abrechnungsende um Mitternacht UTC nicht je
/// nach Zeitzone des Geraets auf den Vor- oder Folgetag rutscht.
String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
