import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';
import 'screen_status.dart';

/// Pruefungsschemata als aufklappbarer Baum.
///
/// In M2 kommt der Rekonstruktions-Drill dazu: Die Schritte werden gemischt
/// und muessen in die richtige Reihenfolge gebracht werden - aktives Abrufen
/// statt Durchlesen.
class SchemataPage extends StatefulWidget {
  const SchemataPage({super.key});

  @override
  State<SchemataPage> createState() => _SchemataPageState();
}

class _SchemataPageState extends State<SchemataPage> {
  List<Map<String, dynamic>> _schemata = [];
  bool _loading = true;
  String? _area;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await AppScope.of(context).api.schemata(area: _area);
      if (mounted) setState(() => _schemata = data);
    } on Exception {
      // Inhalte liegen ab M1 lokal vor und werden dann aus dem Cache gelesen.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const ScreenStatus.loading();

    return ReadableWidth(
      child: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          Wrap(
            spacing: Spacing.sm,
            children: [
              for (final entry in const {
                null: 'Alle',
                'zivilrecht': 'Zivilrecht',
                'strafrecht': 'Strafrecht',
                'oeffentliches-recht': 'Oeffentliches Recht',
              }.entries)
                SubsumoChip.filter(
                  label: entry.value,
                  selected: _area == entry.key,
                  onSelected: (_) {
                    setState(() => _area = entry.key);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          if (_schemata.isEmpty)
            ScreenStatus.empty(
              message: 'Keine Schemata fuer diese Auswahl.',
              onRetry: _load,
            )
          else
            for (final schema in _schemata)
              Card(
                margin: const EdgeInsets.only(bottom: Spacing.md),
                child: ExpansionTile(
                  shape: const Border(),
                  // Icon-Form statt Farbe unterscheidet die Rechtsgebiete -
                  // wie in cases_page.dart bleiben die kategorischen
                  // Akzenttoene aus SubsumoColors.legalArea* oeffentlichen
                  // Flaechen vorbehalten (docs/25 Abschnitt 3.6).
                  leading: Icon(
                    _areaIcon(schema['area'] as String? ?? ''),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(schema['title'] as String),
                  subtitle: Text(
                    ((schema['norms'] as List?) ?? const []).join(', '),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.lg,
                        0,
                        Spacing.lg,
                        Spacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildSteps(
                          ((schema['steps'] as List?) ?? const [])
                              .cast<Map<String, dynamic>>(),
                          0,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.lg,
                        0,
                        Spacing.lg,
                        Spacing.md,
                      ),
                      child: Text(
                        'Stand: ${schema['stand']}  ·  '
                        'Quellen: ${((schema['sources'] as List?) ?? const []).join('; ')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  List<Widget> _buildSteps(List<Map<String, dynamic>> steps, int depth) {
    final widgets = <Widget>[];
    for (final step in steps) {
      final hinweis = step['hinweis'] as String?;
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: depth * Spacing.lg, top: Spacing.sm, bottom: 2),
          child: Text(
            step['label'] as String,
            style: depth == 0
                ? Theme.of(context).textTheme.titleSmall
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
      if (hinweis != null) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: depth * Spacing.lg + Spacing.md, bottom: Spacing.xs),
            child: Text(hinweis, style: Theme.of(context).textTheme.bodySmall),
          ),
        );
      }
      final children = (step['children'] as List?)?.cast<Map<String, dynamic>>();
      if (children != null) widgets.addAll(_buildSteps(children, depth + 1));
    }
    return widgets;
  }

  static IconData _areaIcon(String area) => switch (area) {
        'zivilrecht' => Icons.balance_outlined,
        'strafrecht' => Icons.gavel_outlined,
        'oeffentliches-recht' => Icons.account_balance_outlined,
        _ => Icons.account_tree_outlined,
      };
}
