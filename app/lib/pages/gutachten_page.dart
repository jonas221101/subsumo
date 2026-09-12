import 'dart:async';

import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';

/// Gutachten-Trainer (Challenge 1 und 4).
///
/// Waehrend des Schreibens laeuft die deterministische Strukturanalyse -
/// entkoppelt, damit sie das Tippen nie blockiert. Die inhaltliche Bewertung
/// gegen den Erwartungshorizont gibt es erst bei der Abgabe.
class GutachtenPage extends StatefulWidget {
  const GutachtenPage({required this.caseSlug, required this.caseTitle, super.key});

  final String caseSlug;
  final String caseTitle;

  @override
  State<GutachtenPage> createState() => _GutachtenPageState();
}

class _GutachtenPageState extends State<GutachtenPage> {
  final _controller = TextEditingController();
  final _startedAt = DateTime.now();
  Timer? _debounce;

  Map<String, dynamic>? _case;
  Map<String, dynamic>? _structure;
  Map<String, dynamic>? _result;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCase());
    _controller.addListener(_scheduleAnalysis);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCase() async {
    final api = AppScope.of(context).api;
    try {
      final data = await api.caseDetail(widget.caseSlug);
      if (mounted) setState(() => _case = data);
    } on Exception {
      // Der Fall kann offline aus dem lokalen Cache kommen (M1).
    }
  }

  /// Analyse erst 700 ms nach der letzten Eingabe - sonst feuert bei jedem
  /// Tastendruck ein Request.
  void _scheduleAnalysis() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _analyze);
  }

  Future<void> _analyze() async {
    final text = _controller.text;
    if (text.trim().length < 40) {
      if (mounted) setState(() => _structure = null);
      return;
    }
    try {
      final report =
          await AppScope.of(context).api.analyze(text, caseSlug: widget.caseSlug);
      if (mounted) setState(() => _structure = report);
    } on Exception {
      // Strukturfeedback ist eine Zugabe - ein Fehler darf das Schreiben
      // niemals unterbrechen.
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final result = await AppScope.of(context).api.submitCase(
            widget.caseSlug,
            _controller.text,
            durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
          );
      if (mounted) setState(() => _result = result);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Abgabe fehlgeschlagen: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.caseTitle)),
      body: ReadableWidth(
        maxWidth: 1100,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final zweispaltig = constraints.maxWidth > 900;
            final editor = _buildEditor();
            final feedback = _buildFeedback();
            if (!zweispaltig) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SizedBox(height: 420, child: editor),
                  const SizedBox(height: 16),
                  feedback,
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: editor),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(child: feedback),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEditor() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_case != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _case!['facts'] as String? ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _case!['question'] as String? ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                hintText: 'A koennte gegen B einen Anspruch auf ... aus § ... haben.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy || _controller.text.trim().length < 40 ? null : _submit,
            child: const Text('Abgeben und bewerten lassen'),
          ),
        ],
      );

  Widget _buildFeedback() {
    if (_result != null) return _ResultView(result: _result!);
    final structure = _structure;
    if (structure == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Schreib los. Ab etwa 40 Woertern bekommst du hier laufend '
            'Rueckmeldung zu Aufbau und Gutachtenstil.',
          ),
        ),
      );
    }
    return _StructureView(structure: structure);
  }
}

class _StructureView extends StatelessWidget {
  const _StructureView({required this.structure});

  final Map<String, dynamic> structure;

  @override
  Widget build(BuildContext context) {
    final score = structure['score'] as int;
    final findings = (structure['findings'] as List).cast<Map<String, dynamic>>();
    final counts = (structure['counts'] as Map).cast<String, dynamic>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Struktur', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('$score/100', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: score / 100, minHeight: 6),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _Count('Obersatz', counts['obersatz'] as int? ?? 0),
                _Count('Definition', counts['definition'] as int? ?? 0),
                _Count('Subsumtion', counts['subsumtion'] as int? ?? 0),
                _Count('Ergebnis', counts['ergebnis'] as int? ?? 0),
              ],
            ),
            const Divider(height: 32),
            for (final finding in findings) _FindingTile(finding: finding),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Chip(label: Text('$label: $value'));
}

class _FindingTile extends StatelessWidget {
  const _FindingTile({required this.finding});

  final Map<String, dynamic> finding;

  @override
  Widget build(BuildContext context) {
    final severity = finding['severity'] as String;
    final (icon, color) = switch (severity) {
      'fehler' => (Icons.error_outline, Colors.red.shade700),
      'hinweis' => (Icons.info_outline, Colors.amber.shade800),
      _ => (Icons.check_circle_outline, Colors.green.shade700),
    };
    final excerpt = finding['excerpt'] as String? ?? '';
    final hint = finding['hint'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(finding['message'] as String),
                if (excerpt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '„$excerpt"',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                if (hint.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(hint, style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final evaluation = (result['evaluation'] as Map).cast<String, dynamic>();
    final checkpoints =
        (evaluation['checkpoints'] as List).cast<Map<String, dynamic>>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${evaluation['points']} Punkte · ${evaluation['note']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(evaluation['summary'] as String),
            const Divider(height: 32),
            Text('Erwartungshorizont', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            // Jeder Punktabzug ist auf einen Pruefpunkt zurueckfuehrbar -
            // keine Blackbox-Note.
            for (final cp in checkpoints)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  cp['hit'] == true ? Icons.check_circle : Icons.cancel_outlined,
                  color: cp['hit'] == true ? Colors.green.shade700 : Colors.red.shade400,
                ),
                title: Text(cp['label'] as String),
                subtitle: Text(
                  cp['hit'] == true
                      ? 'Beleg: „${cp['evidence']}"'
                      : cp['comment'] as String? ?? '',
                ),
              ),
            const Divider(height: 32),
            Text(
              evaluation['disclaimer'] as String,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
