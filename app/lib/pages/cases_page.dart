import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';
import 'gutachten_page.dart';
import 'screen_status.dart';

class CasesPage extends StatefulWidget {
  const CasesPage({super.key});

  @override
  State<CasesPage> createState() => _CasesPageState();
}

class _CasesPageState extends State<CasesPage> {
  List<Map<String, dynamic>> _cases = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final data = await AppScope.of(context).api.cases();
      if (mounted) setState(() => _cases = data);
    } on Exception {
      // Offline: Faelle kommen ab M1 aus dem lokalen Speicher.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

    return ReadableWidth(
      child: ListView.separated(
        padding: const EdgeInsets.all(Spacing.lg),
        itemCount: _cases.length,
        separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
        itemBuilder: (context, index) {
          final fall = _cases[index];
          return Card(
            child: ListTile(
              // Icon-Form statt Farbe unterscheidet die Rechtsgebiete hier -
              // die kategorischen Akzenttoene aus SubsumoColors.legalArea*
              // sind laut Brief (docs/25 Abschnitt 3.6) ausdruecklich nur fuer
              // oeffentliche Flaechen vorgesehen, nicht fuer App-Screens.
              leading: Icon(
                _areaIcon(fall['area'] as String),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(fall['title'] as String),
              subtitle: Text(
                '${_areaLabel(fall['area'] as String)}  ·  '
                'Schwierigkeit ${fall['difficulty']}/5  ·  '
                '${fall['minutes']} min',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GutachtenPage(
                    caseSlug: fall['slug'] as String,
                    caseTitle: fall['title'] as String,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _areaLabel(String area) => switch (area) {
        'zivilrecht' => 'Zivilrecht',
        'strafrecht' => 'Strafrecht',
        'oeffentliches-recht' => 'Oeffentliches Recht',
        _ => area,
      };

  static IconData _areaIcon(String area) => switch (area) {
        'zivilrecht' => Icons.balance_outlined,
        'strafrecht' => Icons.gavel_outlined,
        'oeffentliches-recht' => Icons.account_balance_outlined,
        _ => Icons.menu_book_outlined,
      };
}
