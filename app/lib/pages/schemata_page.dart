import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';

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
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ReadableWidth(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final entry in const {
                null: 'Alle',
                'zivilrecht': 'Zivilrecht',
                'strafrecht': 'Strafrecht',
                'oeffentliches-recht': 'Oeffentliches Recht',
              }.entries)
                FilterChip(
                  label: Text(entry.value),
                  selected: _area == entry.key,
                  onSelected: (_) {
                    setState(() => _area = entry.key);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final schema in _schemata)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                shape: const Border(),
                title: Text(schema['title'] as String),
                subtitle: Text(
                  ((schema['norms'] as List?) ?? const []).join(', '),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
          padding: EdgeInsets.only(left: depth * 18.0, top: 6, bottom: 2),
          child: Text(
            step['label'] as String,
            style: depth == 0
                ? const TextStyle(fontWeight: FontWeight.w600)
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
      if (hinweis != null) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: depth * 18.0 + 12, bottom: 4),
            child: Text(hinweis, style: Theme.of(context).textTheme.bodySmall),
          ),
        );
      }
      final children = (step['children'] as List?)?.cast<Map<String, dynamic>>();
      if (children != null) widgets.addAll(_buildSteps(children, depth + 1));
    }
    return widgets;
  }
}
