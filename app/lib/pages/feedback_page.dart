import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../design/design.dart';
import '../state.dart';
import '../theme.dart';

/// Rueckmeldung an den Betreiber (docs/35-geschlossene-testphase.md).
///
/// Bewusst schlicht: Kategorie, Text, absenden. Die Stelle in der App
/// ([context]) wird vom Aufrufer mitgegeben, damit "der Button rechts oben"
/// zuordenbar bleibt, ohne dass die Testerin es beschreiben muss.
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({this.context = '', super.key});

  /// Stelle in der App, von der aus die Seite geoeffnet wurde (z. B. Tab).
  final String context;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

const kFeedbackKategorien = <String, String>{
  'fehler': 'Fehler',
  'idee': 'Idee',
  'inhalt': 'Inhalt',
  'sonstiges': 'Sonstiges',
};

String feedbackPlatform() {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform.name;
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _message = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _category = 'fehler';
  bool _sending = false;
  String? _error;
  String? _success;
  List<Map<String, dynamic>> _mine = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMine());
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    try {
      final mine = await AppScope.of(context).api.myFeedback();
      if (mounted) setState(() => _mine = mine);
    } on Exception {
      // Liste ist Beiwerk - ohne Server bleibt sie leer.
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
      _success = null;
    });
    try {
      await AppScope.of(context).api.sendFeedback(
            category: _category,
            message: _message.text.trim(),
            context: widget.context,
            platform: feedbackPlatform(),
            appVersion: kAppVersion,
          );
      _message.clear();
      if (mounted) setState(() => _success = 'Danke - deine Rückmeldung ist angekommen.');
      await _loadMine();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Senden fehlgeschlagen - bitte später noch einmal versuchen.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: ReadableWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SubsumoPageHeader(
                  eyebrow: 'Testphase',
                  title: 'Was ist dir aufgefallen?',
                  subtitle: 'Fehler, Ideen, fachliche Zweifel an einer Karte - alles hilft. '
                      'Die Rückmeldung geht direkt an den Betreiber, nicht an Dritte.',
                ),
                const SizedBox(height: Spacing.lg),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    for (final entry in kFeedbackKategorien.entries)
                      SubsumoChip.filter(
                        label: entry.value,
                        selected: _category == entry.key,
                        onSelected: (_) => setState(() => _category = entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                SubsumoTextField(
                  label: 'Deine Rückmeldung',
                  controller: _message,
                  maxLines: 6,
                  hintText: 'Was ist passiert, was hast du erwartet? Bei Inhalten: welche Karte?',
                  validator: (v) =>
                      (v == null || v.trim().length < 3) ? 'Bitte mindestens drei Zeichen' : null,
                ),
                if (widget.context.isNotEmpty) ...[
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Stelle in der App: ${widget.context}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: Spacing.md),
                  SubsumoFeedbackBlock(message: _error!, severity: FeedbackSeverity.negative),
                ],
                if (_success != null) ...[
                  const SizedBox(height: Spacing.md),
                  SubsumoFeedbackBlock(message: _success!, severity: FeedbackSeverity.positive),
                ],
                const SizedBox(height: Spacing.lg),
                SubsumoButton.primary(
                  label: _sending ? 'Wird gesendet ...' : 'Rückmeldung senden',
                  icon: Icons.send_outlined,
                  onPressed: _sending ? null : _send,
                ),
                if (_mine.isNotEmpty) ...[
                  const SizedBox(height: Spacing.xxl),
                  const SubsumoEyebrow('Deine bisherigen Rückmeldungen'),
                  const SizedBox(height: Spacing.sm),
                  for (final item in _mine) ...[
                    _FeedbackTile(item: item),
                    const SizedBox(height: Spacing.sm),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kategorie = kFeedbackKategorien[item['category']] ?? '${item['category']}';
    final erledigt = item['erledigt'] == true;
    final created = DateTime.tryParse('${item['created_at']}');
    final datum = created == null
        ? ''
        : '${created.day.toString().padLeft(2, '0')}.'
            '${created.month.toString().padLeft(2, '0')}.${created.year}';
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SubsumoChip(label: kategorie),
              const SizedBox(width: Spacing.sm),
              Text(datum, style: theme.textTheme.bodySmall),
              const Spacer(),
              if (erledigt) const SubsumoChip(label: 'erledigt', icon: Icons.check),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text('${item['message']}', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
