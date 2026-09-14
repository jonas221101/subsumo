import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';

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
      return Center(
        child: app.loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(app.error ?? 'Keine Daten'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: app.loadDashboard,
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
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
