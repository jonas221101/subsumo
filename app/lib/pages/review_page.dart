import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';
import 'screen_status.dart';

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
      return const ScreenStatus.loading();
    }
    if (app.dueCards.isEmpty) {
      return _EmptyState(onReload: app.loadDueCards);
    }

    final card = app.dueCards.first;
    final norms = (card['norms'] as List?)?.cast<String>() ?? const [];

    return ReadableWidth(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SubsumoChip(label: _typeLabel(card['type'] as String? ?? '')),
                const SizedBox(width: Spacing.sm),
                Text('${app.dueCards.length} offen'),
                const Spacer(),
                if (app.dueCardsFromCache)
                  const Tooltip(
                    message: 'Kein Netz erreichbar - zeigt den zuletzt '
                        'geladenen Kartenstapel.',
                    child: SubsumoChip(label: 'offline', icon: Icons.cloud_off),
                  ),
                if (card['content_changed'] == true)
                  const Tooltip(
                    message: 'Der Inhalt dieser Karte wurde fachlich aktualisiert.',
                    child: SubsumoChip(label: 'aktualisiert'),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            Expanded(
              child: SingleChildScrollView(
                child: SubsumoCard(
                  padding: const EdgeInsets.all(Spacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card['front'] as String? ?? '',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      AnimatedSwitcher(
                        duration: Motion.normal,
                        switchInCurve: Motion.curve,
                        switchOutCurve: Motion.curve,
                        child: _revealed
                            ? Column(
                                key: const ValueKey('answer'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(height: 40),
                                  Text(card['back'] as String? ?? ''),
                                  if (norms.isNotEmpty) ...[
                                    const SizedBox(height: Spacing.xl),
                                    Wrap(
                                      spacing: Spacing.sm,
                                      children: [
                                        for (final norm in norms)
                                          SubsumoChip.action(
                                            label: norm,
                                            // M2: oeffnet den Norm-Explorer.
                                            onPressed: () {},
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              )
                            : const SizedBox.shrink(key: ValueKey('hidden')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            if (!_revealed)
              SubsumoButton.primary(
                label: 'Antwort zeigen',
                onPressed: () => setState(() => _revealed = true),
              )
            else
              Row(
                children: [
                  _RateButton('Nochmal', 1, (t, c) => c.error, _rate),
                  _RateButton(
                    'Schwer',
                    2,
                    (t, c) => t.extension<SubsumoColors>()?.feedbackHint ?? c.primary,
                    _rate,
                  ),
                  _RateButton(
                    'Gut',
                    3,
                    (t, c) => t.extension<SubsumoColors>()?.feedbackPositive ?? c.primary,
                    _rate,
                  ),
                  _RateButton('Leicht', 4, (t, c) => c.primary, _rate),
                ],
              ),
            if (app.outbox.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.sm),
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
  const _RateButton(this.label, this.rating, this.colorOf, this.onRate);

  final String label;
  final int rating;
  final Color Function(ThemeData theme, ColorScheme scheme) colorOf;
  final Future<void> Function(int) onRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = colorOf(theme, theme.colorScheme);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: backgroundColor.computeLuminance() > 0.5
                ? theme.colorScheme.onSurface
                : Colors.white,
          ),
          onPressed: () => onRate(rating),
          child: Text(label),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReload});

  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) => ScreenStatus.empty(
        message: 'Nichts faellig. Gut gemacht.',
        severity: FeedbackSeverity.positive,
        onRetry: onReload,
      );
}
