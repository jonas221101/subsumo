import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';
import 'gutachten_page.dart';
import 'screen_status.dart';

/// Fallsammlung: filterbar nach Rechtsgebiet, durchsuchbar nach Titel.
/// Schwierigkeit als neutrale Punktreihe (Eigenschaft des Falls, keine
/// Bewertung des Nutzers), Bearbeitungsdauer als Richtwert.
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
      final data = await AppScope.of(context).api.cases();
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
        message: 'Keine Faelle verfuegbar.',
        detail: 'Faelle werden ab M1 auch offline aus dem lokalen Speicher geladen.',
        onRetry: _load,
      );
    }

    final visible = _visible;
    return ReadableWidth(
      maxWidth: 860,
      child: ListView(
        padding: const EdgeInsets.all(Spacing.xl),
        children: [
          SubsumoPageHeader(
            eyebrow: 'Gutachten-Training',
            title: 'Fälle',
            subtitle: '${_cases.length} geführte Fälle mit Erwartungshorizont.',
          ),
          const SizedBox(height: Spacing.xl),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Fall suchen',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: [
              for (final entry in const {
                null: 'Alle',
                'zivilrecht': 'Zivilrecht',
                'strafrecht': 'Strafrecht',
                'oeffentliches-recht': 'Öffentliches Recht',
              }.entries)
                SubsumoChip.filter(
                  label: entry.value,
                  selected: _area == entry.key,
                  onSelected: (_) => setState(() => _area = entry.key),
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
                  '${_areaLabel(area)}  ·  ${fall['minutes']} min',
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

  static String _areaLabel(String area) => switch (area) {
        'zivilrecht' => 'Zivilrecht',
        'strafrecht' => 'Strafrecht',
        'oeffentliches-recht' => 'Öffentliches Recht',
        _ => area,
      };

  static IconData _areaIcon(String area) => switch (area) {
        'zivilrecht' => Icons.balance_outlined,
        'strafrecht' => Icons.gavel_outlined,
        'oeffentliches-recht' => Icons.account_balance_outlined,
        _ => Icons.menu_book_outlined,
      };
}
