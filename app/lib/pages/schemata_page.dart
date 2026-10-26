import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';
import 'screen_status.dart';

/// Pruefungsschemata als Gliederung mit juristischer Nummerierung
/// (I. / 1. / a) / aa) / (1)) - so, wie sie in Klausur und Kommentar
/// gesetzt wird. Aufklappbar pro Schema, filterbar nach Rechtsgebiet und
/// durchsuchbar nach Titel oder Norm.
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
  String _query = '';

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

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _schemata;
    return [
      for (final s in _schemata)
        if ((s['title'] as String).toLowerCase().contains(q) ||
            ((s['norms'] as List?) ?? const []).join(' ').toLowerCase().contains(q))
          s,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return ReadableWidth(
      maxWidth: 860,
      child: ListView(
        padding: const EdgeInsets.all(Spacing.xl),
        children: [
          SubsumoPageHeader(
            eyebrow: 'Prüfungsaufbau',
            title: 'Schemata',
            subtitle: _loading ? null : '${_schemata.length} Schemata${_area == null ? ' in drei Rechtsgebieten' : ''}.',
          ),
          const SizedBox(height: Spacing.xl),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Schema oder Norm suchen, z. B. § 823 oder Anfechtung',
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
                  onSelected: (_) {
                    setState(() => _area = entry.key);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Spacing.xxxl),
              child: ScreenStatus.loading(),
            )
          else if (visible.isEmpty)
            ScreenStatus.empty(
              message: _query.isEmpty
                  ? 'Keine Schemata für diese Auswahl.'
                  : 'Kein Schema passt zu „$_query".',
              onRetry: _load,
            )
          else
            for (final schema in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: _SchemaTile(schema: schema),
              ),
        ],
      ),
    );
  }
}

class _SchemaTile extends StatelessWidget {
  const _SchemaTile({required this.schema});

  final Map<String, dynamic> schema;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = theme.extension<SubsumoTypography>()!;
    final norms = ((schema['norms'] as List?) ?? const []).cast<String>();
    final steps = ((schema['steps'] as List?) ?? const []).cast<Map<String, dynamic>>();

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        childrenPadding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        // Icon-Form statt Farbe unterscheidet die Rechtsgebiete - die
        // kategorischen Akzenttoene aus SubsumoColors.legalArea* bleiben
        // oeffentlichen Flaechen vorbehalten (docs/25 Abschnitt 3.6).
        leading: Icon(_areaIcon(schema['area'] as String? ?? ''), color: theme.colorScheme.onSurfaceVariant),
        title: Text(schema['title'] as String, style: typography.headingSmall),
        subtitle: norms.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: Spacing.xs),
                child: Text(
                  norms.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
        children: [
          const Divider(),
          const SizedBox(height: Spacing.md),
          ..._buildSteps(context, steps, 0),
          const SizedBox(height: Spacing.lg),
          Text(
            'Stand: ${schema['stand']}  ·  '
            'Quellen: ${((schema['sources'] as List?) ?? const []).join('; ')}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSteps(BuildContext context, List<Map<String, dynamic>> steps, int depth) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final hinweis = step['hinweis'] as String?;
      final children = (step['children'] as List?)?.cast<Map<String, dynamic>>();
      final (numeral, label) = splitNumeral(step['label'] as String, depth: depth, index: i);
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: depth * Spacing.xl, top: depth == 0 && i > 0 ? Spacing.md : Spacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  numeral,
                  style: (depth == 0 ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: depth == 0 ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium,
                    ),
                    if (hinweis != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          hinweis,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      if (children != null) widgets.addAll(_buildSteps(context, children, depth + 1));
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

/// Gliederungszeichen, das die Redaktion bereits in den Schritt-Text
/// geschrieben hat ("I. Schutzbereich", "1. Persönlich", "a) Stufe 1",
/// "aa) ...", "(1) ..."). Wird erkannt und in die Nummern-Spalte gezogen,
/// damit nichts doppelt steht und die Spalte trotzdem buendig bleibt.
final _leadingNumeral = RegExp(r'^\s*((?:[IVXLC]+\.)|(?:\d+\.)|(?:[a-z]{1,2}\))|(?:\(\d+\)))\s+');

/// Zerlegt einen Schritt-Text in (Gliederungszeichen, Rest). Traegt der Text
/// schon ein Zeichen, gilt das der Redaktion; sonst wird eines nach
/// [outlineNumeral] aus Ebene und Position erzeugt.
(String, String) splitNumeral(String label, {required int depth, required int index}) {
  final match = _leadingNumeral.firstMatch(label);
  if (match != null) return (match.group(1)!, label.substring(match.end));
  return (outlineNumeral(depth, index), label);
}

/// Gliederungszeichen nach juristischer Konvention je Ebene: I. / 1. / a) /
/// aa) / (1). Tiefer verschachtelte Ebenen wiederholen (1), (2) ... - in den
/// Inhalten kommt das nicht vor, es soll nur nicht abstuerzen.
String outlineNumeral(int depth, int index) => switch (depth) {
      0 => '${_roman(index + 1)}.',
      1 => '${index + 1}.',
      2 => '${_letter(index)})',
      3 => '${_letter(index)}${_letter(index)})',
      _ => '(${index + 1})',
    };

String _letter(int index) => String.fromCharCode('a'.codeUnitAt(0) + (index % 26));

String _roman(int n) {
  const pairs = [
    (1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'), (100, 'C'), (90, 'XC'),
    (50, 'L'), (40, 'XL'), (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I'),
  ];
  final buffer = StringBuffer();
  var rest = n;
  for (final (value, symbol) in pairs) {
    while (rest >= value) {
      buffer.write(symbol);
      rest -= value;
    }
  }
  return buffer.toString();
}
