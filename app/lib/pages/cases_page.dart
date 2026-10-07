import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';
import 'gutachten_page.dart';
import 'screen_status.dart';

/// Fallsammlung: filterbar nach Fachgebiet, durchsuchbar nach Titel.
/// Schwierigkeit als neutrale Punktreihe (Eigenschaft des Falls, keine
/// Bewertung des Nutzers), Bearbeitungsdauer als Richtwert.
///
/// Begriffe ("Fälle"/"Aufgaben", "Gutachten-Training"/"Aufgaben-Training")
/// und Fachgebiete kommen aus der Fachrichtung des Cockpits (docs/34); ohne
/// geladenes Cockpit gelten die Jura-Fallbacks.
class CasesPage extends StatefulWidget {
  const CasesPage({super.key});

  @override
  State<CasesPage> createState() => _CasesPageState();
}

class _CasesPageState extends State<CasesPage> {
  List<Map<String, dynamic>> _cases = [];
  bool _loading = true;
  String? _area;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final app = AppScope.of(context);
      final data = await app.api.cases(fachrichtung: app.fachrichtungSlug);
      if (mounted) setState(() => _cases = data);
    } on Exception {
      // Offline: Faelle kommen ab M1 aus dem lokalen Speicher.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    return [
      for (final fall in _cases)
        if ((_area == null || fall['area'] == _area) &&
            (q.isEmpty || (fall['title'] as String).toLowerCase().contains(q)))
          fall,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const ScreenStatus.loading();
    if (_cases.isEmpty) {
      return ScreenStatus.empty(
        message: 'Keine Fälle verfügbar.',
        detail: 'Fälle werden ab M1 auch offline aus dem lokalen Speicher geladen.',
        onRetry: _load,
      );
    }

    final app = AppScope.of(context);
    final faelle = app.begriff('faelle', 'Fälle');
    final fall = app.begriff('fall', 'Fall');
    // Filter-Chips: die Fachgebiete der Fachrichtung, sonst die drei
    // juristischen Rechtsgebiete.
    final areaSlugs = app.areas.isEmpty
        ? AppState.legacyAreaLabels.keys.toList()
        : [for (final a in app.areas) a['slug'] as String];
    final visible = _visible;
    return ReadableWidth(
      maxWidth: 860,
      child: ListView(
        padding: const EdgeInsets.all(Spacing.xl),
        children: [
          SubsumoPageHeader(
            eyebrow: app.begriff('training', 'Gutachten-Training'),
            title: faelle,
            subtitle: '${_cases.length} geführte $faelle mit Erwartungshorizont.',
          ),
          const SizedBox(height: Spacing.xl),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: '$fall suchen',
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: [
              for (final slug in <String?>[null, ...areaSlugs])
                SubsumoChip.filter(
                  label: slug == null ? 'Alle' : app.areaLabel(slug),
                  selected: _area == slug,
                  onSelected: (_) => setState(() => _area = slug),
                ),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          if (visible.isEmpty)
            const ScreenStatus.empty(message: 'Kein Fall passt zu dieser Auswahl.')
          else
            for (final fall in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: _CaseTile(fall: fall),
              ),
        ],
      ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.fall});

  final Map<String, dynamic> fall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = theme.extension<SubsumoTypography>()!;
    final app = AppScope.of(context);
    final area = fall['area'] as String;
    final difficulty = ((fall['difficulty'] as num?)?.toInt() ?? 0).clamp(0, 5);

    return SubsumoPanel(
      padding: const EdgeInsets.all(Spacing.lg),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GutachtenPage(
            caseSlug: fall['slug'] as String,
            caseTitle: fall['title'] as String,
          ),
        ),
      ),
      child: Row(
        children: [
          // Icon-Form statt Farbe unterscheidet die Rechtsgebiete hier -
          // die kategorischen Akzenttoene aus SubsumoColors.legalArea*
          // sind laut Brief (docs/25 Abschnitt 3.6) ausdruecklich nur fuer
          // oeffentliche Flaechen vorgesehen, nicht fuer App-Screens.
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHigh,
            ),
            child: Icon(_areaIcon(area), color: theme.colorScheme.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fall['title'] as String, style: typography.headingSmall),
                const SizedBox(height: Spacing.xs),
                Text(
                  '${app.areaLabel(area)}  ·  ${fall['minutes']} min',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SubsumoDots(value: difficulty, label: 'Schwierigkeit'),
              const SizedBox(height: Spacing.xs),
              Text(
                'Schwierigkeit',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(width: Spacing.sm),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  static IconData _areaIcon(String area) => switch (area) {
        'zivilrecht' => Icons.balance_outlined,
        'strafrecht' => Icons.gavel_outlined,
        'oeffentliches-recht' => Icons.account_balance_outlined,
        _ => Icons.menu_book_outlined,
      };
}
