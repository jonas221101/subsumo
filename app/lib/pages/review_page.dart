import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';
import 'screen_status.dart';

/// Karteikarten-Lernschleife (Challenge 2).
///
/// Vier Bewertungen wie in FSRS: Nochmal, Schwer, Gut, Leicht. Die Zeit bis
/// zum Aufdecken wird mitgemessen - sie ist ein guter Indikator dafuer, ob
/// eine Definition wirklich sitzt.
///
/// Die vier Bewertungen sind bewusst **nicht** farbcodiert (frueher rot/
/// gelb/gruen/blau): das war eine Ampel und damit ein Bruch mit docs/11
/// Abschnitt 1. "Gut" ist als haeufigste Antwort die gefuellte Schaltflaeche,
/// die anderen drei sind Konturen - Gewicht statt Farbe.
///
/// Tastatur (Desktop/Web): Leertaste oder Enter deckt auf, 1-4 bewertet.
class ReviewPage extends StatefulWidget {
  const ReviewPage({required this.focusMode, required this.onToggleFocusMode, super.key});

  /// Von [HomeShell] verwaltet, weil der Lesemodus dort auch Navigation/AppBar
  /// ausblendet (SUB-160) - diese Seite kennt nur den aktuellen Zustand und
  /// den Umschalter, nicht die umgebende Chrome.
  final bool focusMode;
  final VoidCallback onToggleFocusMode;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool _revealed = false;
  DateTime _shownAt = DateTime.now();

  /// Groesse des Stapels beim Laden - fuer "3 von 12", ohne dass der Wert
  /// mit jeder Bewertung springt.
  int _sessionTotal = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = AppScope.of(context);
      await app.loadDueCards();
      if (mounted) setState(() => _sessionTotal = app.dueCards.length);
    });
  }

  Future<void> _rate(int rating) async {
    if (!_revealed) return;
    final elapsed = DateTime.now().difference(_shownAt).inMilliseconds;
    await AppScope.of(context).rateTopCard(rating, elapsedMs: elapsed);
    if (!mounted) return;
    setState(() {
      _revealed = false;
      _shownAt = DateTime.now();
    });
  }

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    final Widget body;
    if (app.loading && app.dueCards.isEmpty) {
      body = const ScreenStatus.loading();
    } else if (app.dueCards.isEmpty) {
      body = _EmptyState(onReload: app.loadDueCards);
    } else {
      body = _buildDueCard(context, app);
    }

    final done = (_sessionTotal - app.dueCards.length).clamp(0, _sessionTotal);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _reveal,
        const SingleActivator(LogicalKeyboardKey.enter): _reveal,
        const SingleActivator(LogicalKeyboardKey.digit1): () => _rate(1),
        const SingleActivator(LogicalKeyboardKey.digit2): () => _rate(2),
        const SingleActivator(LogicalKeyboardKey.digit3): () => _rate(3),
        const SingleActivator(LogicalKeyboardKey.digit4): () => _rate(4),
        const SingleActivator(LogicalKeyboardKey.numpad1): () => _rate(1),
        const SingleActivator(LogicalKeyboardKey.numpad2): () => _rate(2),
        const SingleActivator(LogicalKeyboardKey.numpad3): () => _rate(3),
        const SingleActivator(LogicalKeyboardKey.numpad4): () => _rate(4),
      },
      child: Focus(
        autofocus: true,
        child: ReadableWidth(
          maxWidth: 720,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Immer sichtbar, unabhaengig vom Lade-/Leerzustand (SUB-160):
                // sonst waere die Rueckkehr aus dem Lesemodus blockiert, sobald
                // z. B. die letzte faellige Karte bewertet wurde.
                Row(
                  children: [
                    Expanded(
                      child: SubsumoEyebrow(
                        _sessionTotal > 0 && app.dueCards.isNotEmpty
                            ? 'Karteikarten · ${done + 1} von $_sessionTotal'
                            : 'Karteikarten',
                      ),
                    ),
                    IconButton(
                      tooltip: widget.focusMode ? 'Lesemodus verlassen' : 'Lesemodus',
                      icon: Icon(
                        widget.focusMode ? Icons.fullscreen_exit_outlined : Icons.fullscreen_outlined,
                      ),
                      onPressed: widget.onToggleFocusMode,
                    ),
                  ],
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDueCard(BuildContext context, AppState app) {
    final theme = Theme.of(context);
    final typography = theme.extension<SubsumoTypography>()!;
    final card = app.dueCards.first;
    final norms = (card['norms'] as List?)?.cast<String>() ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: SubsumoCard(
              padding: const EdgeInsets.all(Spacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SubsumoChip(label: _typeLabel(card['type'] as String? ?? '')),
                      const Spacer(),
                      // Der app-weite "offline"-Hinweis im AppBar (main.dart,
                      // SUB-161) deckt dasselbe Signal (app.dueCardsFromCache)
                      // ab - hier keine zweite Anzeige, um Dopplung zu vermeiden.
                      if (card['content_changed'] == true)
                        const Tooltip(
                          message: 'Der Inhalt dieser Karte wurde fachlich aktualisiert.',
                          child: SubsumoChip(label: 'aktualisiert'),
                        ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xl),
                  Text(card['front'] as String? ?? '', style: typography.reading),
                  AnimatedSwitcher(
                    duration: Motion.normal,
                    switchInCurve: Motion.curve,
                    switchOutCurve: Motion.curve,
                    child: _revealed
                        ? Column(
                            key: const ValueKey('answer'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: Spacing.xl),
                                child: Divider(),
                              ),
                              const SubsumoEyebrow('Antwort'),
                              const SizedBox(height: Spacing.sm),
                              Text(card['back'] as String? ?? '', style: theme.textTheme.bodyLarge),
                              if (norms.isNotEmpty) ...[
                                const SizedBox(height: Spacing.xl),
                                Wrap(
                                  spacing: Spacing.sm,
                                  runSpacing: Spacing.xs,
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
            onPressed: _reveal,
          )
        else
          Row(
            children: [
              _RateButton(label: 'Nochmal', shortcut: '1', rating: 1, onRate: _rate),
              _RateButton(label: 'Schwer', shortcut: '2', rating: 2, onRate: _rate),
              _RateButton(label: 'Gut', shortcut: '3', rating: 3, onRate: _rate, emphasized: true),
              _RateButton(label: 'Leicht', shortcut: '4', rating: 4, onRate: _rate),
            ],
          ),
        const SizedBox(height: Spacing.sm),
        Text(
          app.outbox.isNotEmpty
              ? '${app.outbox.length} Bewertung(en) warten auf Synchronisierung'
              : (_revealed ? 'Tasten 1 bis 4 bewerten.' : 'Leertaste deckt auf.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
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
  const _RateButton({
    required this.label,
    required this.shortcut,
    required this.rating,
    required this.onRate,
    this.emphasized = false,
  });

  final String label;
  final String shortcut;
  final int rating;
  final Future<void> Function(int) onRate;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // FittedBox: auf schmalen Geraeten (4 Buttons auf ~350px) skaliert das
    // Label leicht herunter statt mitten im Wort umzubrechen.
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, softWrap: false)),
        Text(
          shortcut,
          style: theme.textTheme.bodySmall?.copyWith(
            color: emphasized ? theme.colorScheme.onPrimary.withValues(alpha: 0.7) : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, 60)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Spacing.xs)),
    );
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        child: emphasized
            ? FilledButton(style: style, onPressed: () => onRate(rating), child: child)
            : OutlinedButton(style: style, onPressed: () => onRate(rating), child: child),
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
