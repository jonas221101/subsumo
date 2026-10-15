import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter/services.dart';

import '../design/design.dart';
import '../state.dart';
import '../eingabe_art.dart';
import '../text_schutz.dart';
import '../util/touch_geraet.dart';
import '../theme.dart';
import 'fit_title.dart';
import 'norm_sheet.dart';
import 'screen_status.dart';

/// Karteikarten-Lernschleife (Challenge 2).
///
/// Vier Bewertungen wie in FSRS: Nochmal, Schwer, Gut, Leicht. Die Zeit bis
/// zum Aufdecken wird mitgemessen - sie ist ein guter Indikator dafuer, ob
/// eine Definition wirklich sitzt.
///
/// Die vier Bewertungen sind bewusst **nicht** farbcodiert (frueher rot/
/// gelb/gruen/blau): das war eine Ampel und damit ein Bruch mit docs/11
/// Abschnitt 1. Alle vier sind gleichwertige Konturen-Schaltflaechen - keine
/// wirkt vorausgewaehlt (Testwelle 4); ein Fokusrahmen erscheint nur bei
/// Tastaturbedienung.
///
/// Tastatur (Desktop/Web): Leertaste oder Enter deckt auf, 1-4 bewertet.
class ReviewPage extends StatefulWidget {
  const ReviewPage(
      {required this.focusMode, required this.onToggleFocusMode, super.key});

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

  final _scroll = ScrollController();
  bool _moreBelow = false;

  /// Wurde je ein Touch-Zeiger beobachtet (Tablet mit Desktop-Breite)?
  bool _touchSeen = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateMoreBelow);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = AppScope.of(context);
      // Nach "Fertig fuer heute" nicht still einen neuen Stapel nachladen -
      // sonst widerspricht der Tab der Startseite (dort steht 0 faellig).
      if (app.sessionDone && app.dueCards.isEmpty && app.activeDeck == null) {
        _sessionTotal = app.reviewedInSession;
        if (mounted) setState(() {});
        return;
      }
      // Im Deck gilt das Tageslimit neuer Karten nicht (wie in startDeck).
      await app.loadDueCards(extra: app.activeDeck != null);
      if (mounted) setState(() => _sessionTotal = app.dueCards.length);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Zeigt den "Mehr unten"-Hinweis, solange die Karte noch Inhalt unterhalb
  /// des sichtbaren Bereichs hat (lange Antworten).
  void _updateMoreBelow() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final more = pos.maxScrollExtent - pos.pixels > 8;
    if (more != _moreBelow && mounted) setState(() => _moreBelow = more);
  }

  Future<void> _learnMore() async {
    final app = AppScope.of(context);
    await app.learnMoreCards();
    if (mounted) {
      _resetScroll();
      setState(() {
        _sessionTotal = app.dueCards.length;
        _revealed = false;
        _shownAt = DateTime.now();
      });
    }
  }

  /// Touch-Geraete und schmale Screens haben keine Tastatur - die
  /// Tastaturhinweise ("Tasten 1 bis 4", "Leertaste") wuerden dort nur stoeren.
  bool _showKeyboardHints(BuildContext context) {
    final touch = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        _touchSeen ||
        touchErkannt.value ||
        istTouchGeraet() ||
        // Web auf Tablets meldet oft eine Desktop-Plattform: ohne je
        // angeschlossene Maus gibt es keine Tastaturbedienung zu bewerben.
        (kIsWeb && !RendererBinding.instance.mouseTracker.mouseIsConnected);
    return !touch && MediaQuery.sizeOf(context).width >= 600;
  }

  Future<void> _rate(int rating) async {
    if (!_revealed) return;
    final elapsed = DateTime.now().difference(_shownAt).inMilliseconds;
    await AppScope.of(context).rateTopCard(rating, elapsedMs: elapsed);
    if (!mounted) return;
    _resetScroll();
    setState(() {
      _revealed = false;
      _shownAt = DateTime.now();
    });
  }

  /// Chevron unten auf der Karte: eine Bildschirmhoehe weiterscrollen.
  void _scrollDown() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    _scroll.animateTo(
      (pos.pixels + pos.viewportDimension * 0.8)
          .clamp(0.0, pos.maxScrollExtent),
      duration: Motion.normal,
      curve: Motion.curve,
    );
  }

  /// Die naechste Karte beginnt oben, nicht mitten in der alten Antwort.
  void _resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
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
      body = app.sessionDone
          ? _DoneState(reviewed: app.reviewedInSession, onMore: _learnMore)
          : _EmptyState(onMore: _learnMore, imDeck: app.activeDeck != null);
    } else {
      body = _buildDueCard(context, app);
    }

    final done = (_sessionTotal - app.dueCards.length).clamp(0, _sessionTotal);
    final doneState = app.dueCards.isEmpty && app.sessionDone && !app.loading;

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
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            if (e.kind == PointerDeviceKind.touch && !_touchSeen) {
              touchErkannt.value = true;
              setState(() => _touchSeen = true);
            }
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
                        if (!(doneState && !widget.focusMode))
                          IconButton(
                            tooltip: widget.focusMode
                                ? 'Lesemodus verlassen'
                                : 'Lesemodus',
                            icon: Icon(
                              widget.focusMode
                                  ? Icons.fullscreen_exit_outlined
                                  : Icons.fullscreen_outlined,
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
        ));
  }

  Widget _buildDueCard(BuildContext context, AppState app) {
    final theme = Theme.of(context);
    final typography = theme.extension<SubsumoTypography>()!;
    final card = app.dueCards.first;
    final norms = (card['norms'] as List?)?.cast<String>() ?? const [];

    final hints = _showKeyboardHints(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMoreBelow());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Flexible statt Expanded: die Karte ist nur so hoch wie ihr Inhalt,
        // der Button folgt direkt darunter statt am unteren Fensterrand.
        Flexible(
          child: Stack(
            children: [
              Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.only(
                      right: Spacing.sm, bottom: Spacing.xl),
                  // Genug Luft unter den Norm-Chips, damit der Verlauf am
                  // unteren Rand sie am Scroll-Ende nie ueberdeckt.
                  child: SubsumoCard(
                    padding: const EdgeInsets.all(Spacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SubsumoChip(
                                label:
                                    _typeLabel(card['type'] as String? ?? '')),
                            const Spacer(),
                            // Der app-weite "offline"-Hinweis im AppBar (main.dart,
                            // SUB-161) deckt dasselbe Signal (app.dueCardsFromCache)
                            // ab - hier keine zweite Anzeige, um Dopplung zu vermeiden.
                            if (card['content_changed'] == true)
                              const Tooltip(
                                message:
                                    'Der Inhalt dieser Karte wurde fachlich aktualisiert.',
                                child: SubsumoChip(label: 'aktualisiert'),
                              ),
                          ],
                        ),
                        const SizedBox(height: Spacing.xl),
                        FitTitle(
                          _protectQuestionMark(card['front'] as String? ?? ''),
                          style: typography.reading,
                          maxLines: 1000,
                          minScale: 0.6,
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
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: Spacing.xl),
                                      child: Divider(),
                                    ),
                                    const SubsumoEyebrow('Antwort'),
                                    const SizedBox(height: Spacing.sm),
                                    CardAnswerText(
                                        card['back'] as String? ?? ''),
                                    if (norms.isNotEmpty) ...[
                                      const SizedBox(height: Spacing.xl),
                                      Wrap(
                                        spacing: Spacing.sm,
                                        runSpacing: Spacing.xs,
                                        children: [
                                          for (final norm in norms)
                                            SubsumoChip.action(
                                              label:
                                                  kurzeNormBeschriftung(norm),
                                              icon: Icons.menu_book_outlined,
                                              onPressed: () =>
                                                  showNormText(context, norm),
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
              if (_moreBelow)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.scaffoldBackgroundColor.withValues(alpha: 0),
                          theme.scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: IconButton(
                        tooltip: 'Weiter nach unten',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.keyboard_arrow_down,
                            color: theme.colorScheme.onSurfaceVariant),
                        onPressed: _scrollDown,
                      ),
                    ),
                  ),
                ),
            ],
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
              _RateButton(
                  label: 'Nochmal',
                  shortcut: '1',
                  rating: 1,
                  onRate: _rate,
                  showShortcut: hints),
              _RateButton(
                  label: 'Schwer',
                  shortcut: '2',
                  rating: 2,
                  onRate: _rate,
                  showShortcut: hints),
              _RateButton(
                label: 'Gut',
                shortcut: '3',
                rating: 3,
                onRate: _rate,
                showShortcut: hints,
              ),
              _RateButton(
                  label: 'Leicht',
                  shortcut: '4',
                  rating: 4,
                  onRate: _rate,
                  showShortcut: hints),
            ],
          ),
        if (app.outbox.isNotEmpty || hints) ...[
          const SizedBox(height: Spacing.sm),
          Text(
            app.outbox.isNotEmpty
                ? '${app.outbox.length} Bewertung(en) warten auf Synchronisierung'
                : (_revealed
                    ? 'Tasten 1 bis 4 bewerten.'
                    : 'Leertaste deckt auf.'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
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
    this.showShortcut = true,
  });

  final bool showShortcut;
  final String label;
  final String shortcut;
  final int rating;
  final Future<void> Function(int) onRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // FittedBox: auf schmalen Geraeten (4 Buttons auf ~350px) skaliert das
    // Label leicht herunter statt mitten im Wort umzubrechen.
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, softWrap: false)),
        if (showShortcut)
          Text(
            shortcut,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, 60)),
      padding:
          WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Spacing.xs)),
    );
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        child: OutlinedButton(
            style: style, onPressed: () => onRate(rating), child: child),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onMore, required this.imDeck});

  final Future<void> Function() onMore;
  final bool imDeck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: Spacing.md),
            Text('Gerade ist nichts fällig.',
                style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: Spacing.sm),
            Text(
              imDeck
                  ? 'Alle Karten hier sind für heute gelernt. Die nächste Wiederholung '
                      'plant die App automatisch ein.'
                  : 'Alle fälligen Wiederholungen sind erledigt und dein Tageslimit '
                      'für neue Karten ist erreicht (änderbar im Lernprofil).',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            // Im Deck laedt "Weitere" ohnehin schon ueber das Tageslimit hinaus -
            // ein zweiter Tipp braechte nichts (Nutzertest W11: Schleife).
            if (!imDeck) ...[
              const SizedBox(height: Spacing.lg),
              OutlinedButton(
                key: const ValueKey('weitere-karten'),
                onPressed: onMore,
                child: const Text('Weitere Karten lernen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fertig fuer heute: der Stapel ist abgearbeitet; weitere Karten gibt es nur
/// auf ausdruecklichen Wunsch.
class _DoneState extends StatelessWidget {
  const _DoneState({required this.reviewed, required this.onMore});

  final int reviewed;
  final Future<void> Function() onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<SubsumoColors>();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline,
            size: 40,
            color: colors?.feedbackPositive ?? theme.colorScheme.primary),
        const SizedBox(height: Spacing.md),
        Text('Fertig für heute.',
            textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: Spacing.xs),
        Text(
          reviewed > 0
              ? '$reviewed Karten abgearbeitet. Gut gemacht.'
              : 'Alle fälligen Karten sind abgearbeitet. Gut gemacht.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: Spacing.lg),
        OutlinedButton(
          onPressed: onMore,
          child: const Text('Weitere Karten lernen'),
        ),
      ],
    );
  }
}

/// Einzelne Zeilenumbrueche mitten im Satz (YAML-Literalbloecke mit fester
/// Zeilenbreite) werden zu Leerzeichen; Absaetze (Leerzeile) und
/// Aufzaehlungen bleiben erhalten.
String reflowCardText(String text) => text.replaceAllMapped(
      RegExp(r'([^\n])\n(?!\n|\s*(?:[-*•]|\d+[.)]|[a-z]\)))'),
      (m) => '${m.group(1)} ',
    );

/// Geschuetztes Leerzeichen vor "?" und "!" - das Satzzeichen steht nie allein
/// in einer Zeile.
String _protectQuestionMark(String text) =>
    normUmbruchschutz(text).replaceAllMapped(RegExp(r'\s+([?!])'), (m) => '\u00A0${m.group(1)}');

final _bulletRe = RegExp(r'^\s*(?:[-*•]|\d+[.)]|[a-z]\))\s+');

/// Lesefreundliche Antwort: Absaetze mit Abstand, Aufzaehlungen mit haengendem
/// Einzug, grosszuegiger Zeilenabstand. Der Text selbst bleibt unveraendert.
class CardAnswerText extends StatelessWidget {
  const CardAnswerText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6);
    final children = <Widget>[];
    for (final para in normUmbruchschutz(text).trim().split(RegExp(r'\n\s*\n'))) {
      final lines = para.split('\n');
      // Zeilen ohne Aufzaehlungszeichen gehoeren zum Satz davor (Umbruch im Quelltext).
      final blocks = <(String?, StringBuffer)>[];
      for (final line in lines) {
        final m = _bulletRe.firstMatch(line);
        if (m != null) {
          blocks.add((
            line.substring(0, m.end).trim(),
            StringBuffer(line.substring(m.end))
          ));
        } else if (blocks.isEmpty) {
          blocks.add((null, StringBuffer(line.trim())));
        } else {
          blocks.last.$2.write(' ${line.trim()}');
        }
      }
      for (final (marker, body) in blocks) {
        if (body.isEmpty) continue;
        children.add(Padding(
          padding:
              EdgeInsets.only(bottom: marker == null ? Spacing.md : Spacing.sm),
          child: marker == null
              ? Text(body.toString(), style: style)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                          RegExp(r'^[-*•]$').hasMatch(marker) ? '•' : marker,
                          style: style),
                    ),
                    Expanded(child: Text(body.toString(), style: style)),
                  ],
                ),
        ));
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
