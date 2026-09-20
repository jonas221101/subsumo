import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../design/design.dart';
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

  /// Ob die KI-Korrektur ueberhaupt aktiv ist (`GET /v1/public/config`,
  /// SUB-133/SUB-134) - unabhaengig von der Einwilligung dieses Nutzers.
  /// Bleibt bei einem Ladefehler `false`: das serverseitige Gate greift
  /// ohnehin unabhaengig vom Client, ein fehlendes Flag darf die Abgabe nie
  /// blockieren. Bei ausgeschaltetem Feature bleibt die Seite dadurch exakt
  /// wie vor SUB-134 (kein Dialog, keine Engine-Kennzeichnung im Ergebnis).
  bool _aiCorrectionEnabled = false;

  /// Free-Limit auf den Fall selbst erreicht (`GET /cases/{slug}`, siehe
  /// docs/20 B2) - blockiert die ganze Seite, es gibt ohne Fall nichts zu
  /// bearbeiten.
  String? _caseUpgradeMessage;

  /// Wochenlimit fuer die Strukturanalyse erreicht (`POST /gutachten/analyze`,
  /// siehe docs/20 B2) - blockiert nur das Feedback, nicht das Schreiben oder
  /// die Abgabe.
  String? _analysisUpgradeMessage;

  /// Fokussierter Lesemodus (SUB-160): blendet nur die AppBar aus, der
  /// Editor-/Feedback-Inhalt bleibt unveraendert - Rueckkehr jederzeit ueber
  /// den eingeblendeten Button moeglich.
  bool _focusMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCase());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAiCorrectionEnabled());
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
    } on ApiException catch (e) {
      if (mounted && e.upgradeRequired) {
        setState(() => _caseUpgradeMessage = e.message);
      }
      // Sonst (kein Free-Limit): der Fall kann offline aus dem lokalen
      // Cache kommen (M1).
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
      if (mounted) {
        setState(() {
          _structure = report;
          _analysisUpgradeMessage = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && e.upgradeRequired) {
        setState(() {
          _structure = null;
          _analysisUpgradeMessage = e.message;
        });
      }
      // Sonst (kein Free-Limit): Strukturfeedback ist eine Zugabe - ein
      // Fehler darf das Schreiben niemals unterbrechen.
    } on Exception {
      // Strukturfeedback ist eine Zugabe - ein Fehler darf das Schreiben
      // niemals unterbrechen.
    }
  }

  Future<void> _loadAiCorrectionEnabled() async {
    try {
      final config = await AppScope.of(context).api.publicConfig();
      if (mounted) {
        setState(() => _aiCorrectionEnabled = config['ai_correction_enabled'] == true);
      }
    } on Exception {
      // Bleibt aus (false) - siehe Kommentar am Feld.
    }
  }

  /// Vor der ersten Abgabe eines Accounts, solange die KI-Korrektur aktiv
  /// ist und noch keine Entscheidung vorliegt: Zustimmungsdialog (SUB-134).
  /// Zustimmen und Ablehnen sind beides vollstaendige Pfade - Ablehnen fuehrt
  /// normal weiter zur heuristischen Abgabe, ohne den Dialog je erneut zu
  /// zeigen (siehe [AppState.declineAiConsent]).
  Future<void> _maybeAskForAiConsent(AppState app) async {
    if (!_aiCorrectionEnabled || app.aiConsentGiven) return;
    if (await app.hasDeclinedAiConsent()) return;
    if (!mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _AiConsentDialog(),
    );
    if (!mounted) return;

    if (accepted == true) {
      try {
        await app.api.grantAiConsent();
        await app.refreshUser();
      } on Exception {
        // Serverseitiges Gate haengt am Einwilligungsstand, nicht an dieser
        // Bestaetigung - ein Fehler hier darf die Abgabe selbst nicht stoppen.
      }
    } else {
      await app.declineAiConsent();
    }
  }

  Future<void> _submit() async {
    final app = AppScope.of(context);
    await _maybeAskForAiConsent(app);
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      final result = await app.api.submitCase(
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
    final caseUpgradeMessage = _caseUpgradeMessage;
    if (caseUpgradeMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.caseTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: SubsumoCard(
              child: SubsumoFeedbackBlock(
                message: 'Dieser Fall ist mit Pro verfuegbar.',
                detail: caseUpgradeMessage,
                severity: FeedbackSeverity.hint,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      // Lesemodus (SUB-160) blendet nur den Titel aus, behaelt aber eine
      // schmale AppBar mit dem Umschalter - eine schwebende Schaltflaeche
      // ueber dem Inhalt (statt in der Chrome) wuerde bei kurzen Fenstern
      // den Falltext im Editor ueberdecken koennen.
      appBar: AppBar(
        title: _focusMode ? null : Text(widget.caseTitle),
        actions: [
          IconButton(
            tooltip: _focusMode ? 'Lesemodus verlassen' : 'Lesemodus',
            icon: Icon(_focusMode ? Icons.fullscreen_exit_outlined : Icons.fullscreen_outlined),
            onPressed: () => setState(() => _focusMode = !_focusMode),
          ),
        ],
      ),
      body: ReadableWidth(
        maxWidth: 1100,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final zweispaltig = constraints.maxWidth > 900;
            final editor = _buildEditor();
            final feedback = _buildFeedback();
            if (!zweispaltig) {
              return ListView(
                padding: const EdgeInsets.all(Spacing.lg),
                children: [
                  SizedBox(height: 420, child: editor),
                  const SizedBox(height: Spacing.lg),
                  feedback,
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: editor),
                  const SizedBox(width: Spacing.lg),
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
            SubsumoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _case!['facts'] as String? ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    _case!['question'] as String? ?? '',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          const SizedBox(height: Spacing.md),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                hintText: 'A koennte gegen B einen Anspruch auf ... aus § ... haben.',
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          SubsumoButton.primary(
            label: 'Abgeben und bewerten lassen',
            onPressed: _busy || _controller.text.trim().length < 40 ? null : _submit,
          ),
        ],
      );

  Widget _buildFeedback() {
    if (_result != null) {
      return _ResultView(result: _result!, showEngine: _aiCorrectionEnabled);
    }
    final analysisUpgradeMessage = _analysisUpgradeMessage;
    if (analysisUpgradeMessage != null) {
      return SubsumoCard(
        child: SubsumoFeedbackBlock(
          message: 'Strukturfeedback ist diese Woche mit Free aufgebraucht.',
          detail: analysisUpgradeMessage,
          severity: FeedbackSeverity.hint,
        ),
      );
    }
    final structure = _structure;
    if (structure == null) {
      return const SubsumoCard(
        child: SubsumoFeedbackBlock(
          message: 'Schreib los. Ab etwa 40 Woertern bekommst du hier laufend '
              'Rueckmeldung zu Aufbau und Gutachtenstil.',
          severity: FeedbackSeverity.hint,
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

    return SubsumoCard(
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
          const SizedBox(height: Spacing.sm),
          SubsumoProgressMeter(value: score / 100, minHeight: 6),
          const SizedBox(height: Spacing.lg),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
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
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => SubsumoChip(label: '$label: $value');
}

class _FindingTile extends StatelessWidget {
  const _FindingTile({required this.finding});

  final Map<String, dynamic> finding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subsumo = theme.extension<SubsumoColors>();
    final severity = finding['severity'] as String;
    final (icon, color) = switch (severity) {
      'fehler' => (Icons.error_outline, theme.colorScheme.error),
      'hinweis' => (Icons.info_outline, subsumo?.feedbackHint ?? theme.colorScheme.primary),
      _ => (Icons.check_circle_outline, subsumo?.feedbackPositive ?? theme.colorScheme.primary),
    };
    final excerpt = finding['excerpt'] as String? ?? '';
    final hint = finding['hint'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(finding['message'] as String),
                if (excerpt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.xs),
                    child: Text(
                      '„$excerpt"',
                      style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                if (hint.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.xs),
                    child: Text(hint, style: theme.textTheme.bodySmall),
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
  const _ResultView({required this.result, required this.showEngine});

  final Map<String, dynamic> result;

  /// Nur bei aktiver KI-Korrektur gesetzt (siehe Feldkommentar in
  /// `_GutachtenPageState._aiCorrectionEnabled`) - sonst bliebe die Kennzeich-
  /// nung sichtbar, obwohl die Note immer heuristisch ist und sich damit
  /// "Oberflaeche unveraendert bei ausgeschaltetem Feature" (Abnahme SUB-134)
  /// nicht mehr haelt.
  final bool showEngine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subsumo = theme.extension<SubsumoColors>();
    final evaluation = (result['evaluation'] as Map).cast<String, dynamic>();
    final checkpoints =
        (evaluation['checkpoints'] as List).cast<Map<String, dynamic>>();
    final engine = evaluation['engine'] as String? ?? 'heuristik';

    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${evaluation['points']} Punkte · ${evaluation['note']}',
            style: theme.textTheme.headlineSmall,
          ),
          if (showEngine) ...[
            const SizedBox(height: Spacing.xs),
            SubsumoChip(
              label: engine.startsWith('llm:') ? 'KI-bewertet' : 'Heuristisch geprueft',
            ),
          ],
          const SizedBox(height: Spacing.sm),
          Text(evaluation['summary'] as String),
          const Divider(height: 32),
          Text('Erwartungshorizont', style: theme.textTheme.titleSmall),
          const SizedBox(height: Spacing.sm),
          // Jeder Punktabzug ist auf einen Pruefpunkt zurueckfuehrbar -
          // keine Blackbox-Note.
          for (final cp in checkpoints)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                cp['hit'] == true ? Icons.check_circle : Icons.cancel_outlined,
                color: cp['hit'] == true
                    ? (subsumo?.feedbackPositive ?? theme.colorScheme.primary)
                    : theme.colorScheme.error,
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
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Zustimmungsdialog vor der ersten KI-gestuetzten Bewertung (SUB-134,
/// docs/23-llm-provider-avv.md Abschnitt 4). Zustimmen und Ablehnen sind
/// bewusst gleich gestaltete Buttons ohne vorausgefuelltes Haekchen - kein
/// Dark Pattern, beide Wege sind vollstaendig nutzbar.
class _AiConsentDialog extends StatelessWidget {
  const _AiConsentDialog();

  static const _datenschutzUrl = 'https://app.subsumo.de/rechtliches/datenschutz';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('KI-Korrektur nutzen?'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dein Gutachtentext wird zur inhaltlichen Bewertung an den '
                'Anbieter Anthropic uebertragen und dort in den USA '
                'verarbeitet. Die Bewertung erfolgt maschinell, ist '
                'unverbindlich und ersetzt keine Korrektur durch einen '
                'Menschen.',
              ),
              SizedBox(height: Spacing.md),
              Text(
                'Ohne Zustimmung bekommst du weiterhin den heuristischen '
                'Struktur-/Stil-Check ohne Punkte - sofort, kostenlos und '
                'ohne dass dein Text an Dritte geht.',
              ),
              SizedBox(height: Spacing.md),
              Text(
                'Du kannst deine Zustimmung jederzeit in den '
                'Kontoeinstellungen widerrufen.',
              ),
              SizedBox(height: Spacing.sm),
              _DatenschutzLink(),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ablehnen'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Zustimmen'),
          ),
        ],
      ),
    );
  }
}

class _DatenschutzLink extends StatelessWidget {
  const _DatenschutzLink();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: () => launchUrl(
          Uri.parse(_AiConsentDialog._datenschutzUrl),
          mode: LaunchMode.externalApplication,
        ),
        child: const Text('Datenschutzerklaerung'),
      ),
    );
  }
}
