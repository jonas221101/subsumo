import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';

/// Wissenslandkarte (Challenge 3).
///
/// Bewusst ehrlich: gezaehlt wird nur, was reif ist. "Schon mal gesehen"
/// zaehlt nicht - sonst waere die Zahl wertlos.
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
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Examensrelevanter Stoff, den du sicher kannst',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(gesamt * 100).round()} %',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: gesamt, minHeight: 8),
                    const SizedBox(height: 12),
                    Text(
                      'Gewichtet nach Pruefungsrelevanz. Gezaehlt wird nur, was '
                      'du langfristig behaeltst - nicht, was du einmal gesehen hast.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final entry in byArea.entries)
              _AreaRow(area: entry.key, value: (entry.value as num).toDouble()),
            const SizedBox(height: 24),
            Text('Themen', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final topic in topics) _TopicTile(topic: topic),
          ],
        ),
      ),
    );
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({required this.area, required this.value});

  final String area;
  final double value;

  static const _labels = {
    'zivilrecht': 'Zivilrecht',
    'strafrecht': 'Strafrecht',
    'oeffentliches-recht': 'Oeffentliches Recht',
  };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 170, child: Text(_labels[area] ?? area)),
            Expanded(child: LinearProgressIndicator(value: value, minHeight: 6)),
            const SizedBox(width: 12),
            Text('${(value * 100).round()} %'),
          ],
        ),
      );
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic});

  final Map<String, dynamic> topic;

  @override
  Widget build(BuildContext context) {
    final mastery = (topic['mastery'] as num).toDouble();
    final total = topic['cards_total'] as int;
    final mature = topic['cards_mature'] as int;
    final started = topic['cards_started'] as int;

    // Ampel: rot = nie angefasst, gelb = angefangen, gruen = reif.
    final color = mastery >= 0.8
        ? Colors.green
        : (started > 0 ? Colors.amber.shade700 : Colors.red.shade400);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 6, backgroundColor: color),
      title: Text(topic['title'] as String),
      subtitle: Text('$mature von $total Karten reif  ·  Relevanz ${topic['relevance']}/5'),
      trailing: Text('${(mastery * 100).round()} %'),
    );
  }
}
