import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';

/// Karteikarten-Lernschleife (Challenge 2).
///
/// Vier Bewertungen wie in FSRS: Nochmal, Schwer, Gut, Leicht. Die Zeit bis
/// zum Aufdecken wird mitgemessen - sie ist ein guter Indikator dafuer, ob
/// eine Definition wirklich sitzt.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool _revealed = false;
  DateTime _shownAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context).loadDueCards();
    });
  }

  Future<void> _rate(int rating) async {
    final elapsed = DateTime.now().difference(_shownAt).inMilliseconds;
    await AppScope.of(context).rateTopCard(rating, elapsedMs: elapsed);
    if (!mounted) return;
    setState(() {
      _revealed = false;
      _shownAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    if (app.loading && app.dueCards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (app.dueCards.isEmpty) {
      return _EmptyState(onReload: app.loadDueCards);
    }

    final card = app.dueCards.first;
    final norms = (card['norms'] as List?)?.cast<String>() ?? const [];

    return ReadableWidth(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Chip(label: Text(_typeLabel(card['type'] as String? ?? ''))),
                const SizedBox(width: 8),
                Text('${app.dueCards.length} offen'),
                const Spacer(),
                if (app.dueCardsFromCache)
                  const Tooltip(
                    message: 'Kein Netz erreichbar - zeigt den zuletzt '
                        'geladenen Kartenstapel.',
                    child: Chip(
                      avatar: Icon(Icons.cloud_off, size: 16),
                      label: Text('offline'),
                    ),
                  ),
                if (card['content_changed'] == true)
                  const Tooltip(
                    message: 'Der Inhalt dieser Karte wurde fachlich aktualisiert.',
                    child: Chip(label: Text('aktualisiert')),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card['front'] as String? ?? '',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (_revealed) ...[
                          const Divider(height: 40),
                          Text(card['back'] as String? ?? ''),
                          if (norms.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final norm in norms)
                                  ActionChip(
                                    label: Text(norm),
                                    // M2: oeffnet den Norm-Explorer.
                                    onPressed: () {},
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_revealed)
              FilledButton(
                onPressed: () => setState(() => _revealed = true),
                child: const Text('Antwort zeigen'),
              )
            else
              Row(
                children: [
                  _RateButton('Nochmal', 1, Colors.red.shade700, _rate),
                  _RateButton('Schwer', 2, Colors.orange.shade800, _rate),
                  _RateButton('Gut', 3, Colors.green.shade700, _rate),
                  _RateButton('Leicht', 4, Colors.blue.shade700, _rate),
                ],
              ),
            if (app.outbox.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${app.outbox.length} Bewertung(en) warten auf Synchronisierung',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _typeLabel(String type) => switch (type) {
        'definition' => 'Definition',
        'schema_step' => 'Schema',
        'streitstand' => 'Streitstand',
        'norm' => 'Norm',
        'rechtsprechung' => 'Rechtsprechung',
        _ => 'Karte',
      };
}

class _RateButton extends StatelessWidget {
  const _RateButton(this.label, this.rating, this.color, this.onRate);

  final String label;
  final int rating;
  final Color color;
  final Future<void> Function(int) onRate;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => onRate(rating),
            child: Text(label),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReload});

  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nichts faellig. Gut gemacht.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onReload, child: const Text('Neu laden')),
          ],
        ),
      );
}
