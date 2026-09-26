import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';
import 'checkout_page.dart';
import 'screen_status.dart';

/// Startseite "Heute": was jetzt ansteht (faellige Karten mit Direkteinstieg)
/// und die Wissenslandkarte (Challenge 3).
///
/// Bewusst ehrlich: gezaehlt wird nur, was reif ist. "Schon mal gesehen"
/// zaehlt nicht - sonst waere die Zahl wertlos. Aus demselben Grund zeigt
/// diese Seite als Erstbeispiel fuer das Designsystem (docs/11-designsystem.md),
/// wie eine Fortschrittsanzeige *ohne* Ampelfarbe aussieht - siehe
/// [SubsumoProgressMeter]. Keine Streaks, keine Tagesziele, keine
/// Belohnungsgrafik (Leitprinzip 5, docs/01-produktvision.md).
const _areaLabels = {
  'zivilrecht': 'Zivilrecht',
  'strafrecht': 'Strafrecht',
  'oeffentliches-recht': 'Öffentliches Recht',
};

class DashboardPage extends StatefulWidget {
  const DashboardPage({this.onStartReview, super.key});

  /// Wechselt in den Karteikarten-Tab - von [HomeShell] gereicht, damit die
  /// Startseite den Tab-Index nicht kennen muss.
  final VoidCallback? onStartReview;

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
      // Solange noch kein Fehler vorliegt, laden wir - auch wenn ein
      // paralleler Kartenabruf `loading` zwischenzeitlich zuruecksetzt.
      return (app.loading || app.error == null)
          ? const ScreenStatus.loading()
          : ScreenStatus.error(
              message: app.error ?? 'Keine Daten',
              onRetry: app.loadDashboard,
            );
    }

    final topics = (coverage['topics'] as List).cast<Map<String, dynamic>>();
    final byArea = (coverage['by_area'] as Map).cast<String, dynamic>();
    final gesamt = (coverage['weighted_coverage'] as num).toDouble();
    final breit = MediaQuery.sizeOf(context).width >= 800;

    final dueTile = _DueTile(
      count: app.dueCards.length,
      fromCache: app.dueCardsFromCache,
      onStart: widget.onStartReview,
    );
    final coverageTile = _CoverageTile(value: gesamt);

    return RefreshIndicator(
      onRefresh: app.loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(Spacing.xl),
        children: [
          ReadableWidth(
            maxWidth: 1040,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SubsumoPageHeader(
                  eyebrow: 'Heute · ${_formatToday(DateTime.now())}',
                  title: 'Dein Stand',
                  subtitle: 'Was jetzt ansteht und was schon sitzt.',
                ),
                const SizedBox(height: Spacing.xl),
                if (app.cancelAtPeriodEnd || !app.proActive) ...[
                  _ProStatusBanner(app: app),
                  const SizedBox(height: Spacing.lg),
                ],
                if (breit)
                  // IntrinsicHeight, damit beide Kacheln gleich hoch werden -
                  // in einer ListView haette `stretch` sonst keine Hoehe.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: dueTile),
                        const SizedBox(width: Spacing.lg),
                        Expanded(flex: 3, child: coverageTile),
                      ],
                    ),
                  )
                else ...[
                  dueTile,
                  const SizedBox(height: Spacing.lg),
                  coverageTile,
                ],
                const SizedBox(height: Spacing.xxl),
                const _SectionTitle('Rechtsgebiete'),
                const SizedBox(height: Spacing.md),
                _AreaMeters(byArea: byArea, breit: breit),
                const SizedBox(height: Spacing.xxl),
                _SectionTitle('Themen', detail: '${topics.length} im Register'),
                const SizedBox(height: Spacing.md),
                SubsumoPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < topics.length; i++) ...[
                        if (i > 0) const Divider(),
                        _TopicRow(topic: topics[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Faellige Karten mit Direkteinstieg. Die Zahl ist eine Tatsache ("12
/// warten"), kein Ziel und kein Rueckstand - deshalb ohne Vergleich zu
/// gestern und ohne Farbwechsel.
class _DueTile extends StatelessWidget {
  const _DueTile({required this.count, required this.fromCache, required this.onStart});

  final int count;
  final bool fromCache;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = theme.extension<SubsumoTypography>()!;
    return SubsumoPanel(
      tone: SubsumoPanelTone.brand,
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SubsumoEyebrow('Fällig', color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(height: Spacing.md),
          Text(
            '$count',
            style: typography.numeral.copyWith(color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            switch (count) {
              0 => 'Keine Karte wartet. Du bist auf Stand.',
              1 => 'Eine Karte wartet auf dich.',
              _ => 'Karten warten auf dich.',
            },
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
          ),
          if (fromCache) ...[
            const SizedBox(height: Spacing.xs),
            Text(
              'Stand vom letzten Serverkontakt.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
          ],
          const SizedBox(height: Spacing.lg),
          SizedBox(
            width: double.infinity,
            child: SubsumoButton.primary(
              label: count == 0 ? 'Karten ansehen' : 'Jetzt lernen',
              icon: Icons.arrow_forward,
              onPressed: onStart,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverageTile extends StatelessWidget {
  const _CoverageTile({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = theme.extension<SubsumoTypography>()!;
    return SubsumoCard(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SubsumoEyebrow('Sicher gekonnt'),
          const SizedBox(height: Spacing.md),
          Text('${(value * 100).round()} %', style: typography.numeral),
          const SizedBox(height: Spacing.sm),
          Text(
            'des examensrelevanten Stoffs',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.lg),
          // Eine Farbe, unabhaengig vom Wert - ein Lernstand ist eine
          // Tatsache, keine Ampel (Leitprinzip "Ehrlichkeit vor
          // Motivation", docs/01-produktvision.md).
          SubsumoProgressMeter(value: value),
          const SizedBox(height: Spacing.md),
          Text(
            'Gewichtet nach Prüfungsrelevanz. Gezählt wird nur, was du '
            'langfristig behältst - nicht, was du einmal gesehen hast.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = theme.extension<SubsumoTypography>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: typography.headingMedium),
        if (detail != null) ...[
          const SizedBox(width: Spacing.md),
          Text(
            detail!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _AreaMeters extends StatelessWidget {
  const _AreaMeters({required this.byArea, required this.breit});

  final Map<String, dynamic> byArea;
  final bool breit;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final entry in byArea.entries)
        SubsumoPanel(
          child: SubsumoProgressMeter(
            label: _areaLabels[entry.key] ?? entry.key,
            value: (entry.value as num).toDouble(),
          ),
        ),
    ];
    if (tiles.isEmpty) {
      return SubsumoPanel(
        child: Text(
          'Noch kein Rechtsgebiet begonnen.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    if (!breit) {
      return Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.sm),
            tiles[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: Spacing.md),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});

  final Map<String, dynamic> topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = theme.extension<SubsumoTypography>()!;
    final mastery = (topic['mastery'] as num).toDouble();
    final total = topic['cards_total'] as int;
    final mature = topic['cards_mature'] as int;
    final relevance = (topic['relevance'] as num?)?.toInt().clamp(0, 5) ?? 0;

    // Kein Ampel-Icon: der Lernstand einer Karte ist eine Tatsache, keine
    // Warnung. Ein Thema mit 0 % sicher gelernten Karten sieht darum
    // genauso "neutral" aus wie eines mit 80 % - siehe docs/11-designsystem.md.
    // Die Relevanz-Punkte sind eine feste Eigenschaft des Themas, kein
    // Lernstand.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      child: Row(
        children: [
          Icon(Icons.menu_book_outlined, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic['title'] as String, style: typography.headingSmall),
                const SizedBox(height: Spacing.xs),
                Row(
                  children: [
                    SubsumoDots(value: relevance, label: 'Relevanz'),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      '$mature von $total Karten reif',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          Text('${(mastery * 100).round()} %', style: theme.textTheme.titleMedium),
        ],
      ),
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
      child: Row(
        children: [
          const Expanded(
            child: SubsumoFeedbackBlock(
              message: 'Mit Pro lernst du unbegrenzt in allen Rechtsgebieten.',
              severity: FeedbackSeverity.hint,
            ),
          ),
          const SizedBox(width: Spacing.lg),
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
}

/// Formatiert das Kalenderdatum, wie es der Server meint - bewusst ohne
/// [DateTime.toLocal], damit ein Abrechnungsende um Mitternacht UTC nicht je
/// nach Zeitzone des Geraets auf den Vor- oder Folgetag rutscht.
String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

const _weekdays = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];
const _months = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// "Donnerstag, 25. September" - ohne intl-Paket, weil nur diese eine Form
/// gebraucht wird und die App durchgehend deutschsprachig ist.
String _formatToday(DateTime now) =>
    '${_weekdays[now.weekday - 1]}, ${now.day}. ${_months[now.month - 1]}';
