import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../design/design.dart';
import '../state.dart';
import 'beta_feedback.dart';
import 'fit_title.dart';
import 'landesbezug.dart';
import '../theme.dart';

/// Gutachten-Trainer (Challenge 1 und 4).
///
/// Waehrend des Schreibens laeuft die deterministische Strukturanalyse -
/// entkoppelt, damit sie das Tippen nie blockiert. Die inhaltliche Bewertung
/// gegen den Erwartungshorizont gibt es erst bei der Abgabe.
class GutachtenPage extends StatefulWidget {
  const GutachtenPage({
    required this.caseSlug,
    required this.caseTitle,
    this.mode = 'uebung',
    this.area,
    super.key,
  });

  final String caseSlug;
  final String caseTitle;

  /// `uebung` (Standard) oder `klausur` - Klausuren unter Examensbedingungen
  /// aus dem Examen-Reiter (docs/32 Abschnitt 5) zaehlen serverseitig fuer die
  /// Klausurpraxis; der Editor selbst ist in beiden Modi derselbe.
  final String mode;

  /// Rechtsgebiet des Falls (`zivilrecht`, `strafrecht`, `oeffentliches-recht`),
  /// steuert den Platzhalter im Loesungsfeld. Fehlt es, kommt es aus dem
  /// geladenen Fall.
  final String? area;

  String get _titel => mode == 'klausur' ? '$caseTitle (Klausur)' : caseTitle;

  /// Schluessel des lokalen Entwurfs - je Fall, unabhaengig vom Modus.
  static String entwurfKey(String slug) => 'gutachten_entwurf_$slug';

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

  /// Text zum Zeitpunkt der letzten erfolgreichen Abgabe - weicht der aktuelle
  /// Text davon ab, ist das Ergebnis veraltet.
  String? _submittedText;
  Timer? _saveDebounce;
  Timer? _ticker;
  bool _restoring = false;
  SharedPreferences? _prefs;

  bool get _resultStale => _result != null && _controller.text != _submittedText;
  bool get _klausur => widget.mode == 'klausur';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
    _controller.addListener(_onTextChanged);
    if (_klausur) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onTextChanged() {
    if (_restoring) return;
    _scheduleAnalysis();
    _scheduleSave();
    // Veraltet-Status und Abgabe-Button haengen am Text.
    if (mounted) setState(() {});
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), _saveDraft);
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      final key = GutachtenPage.entwurfKey(widget.caseSlug);
      final text = _controller.text;
      if (text.trim().isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, text);
      }
    } on Exception {
      // Autosave ist eine Zugabe - nie das Schreiben stoeren.
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      final draft = prefs.getString(GutachtenPage.entwurfKey(widget.caseSlug));
      if (!mounted || draft == null || draft.isEmpty || _controller.text.isNotEmpty) return;
      _restoring = true;
      _controller.text = draft;
      _restoring = false;
      setState(() {});
      _scheduleAnalysis();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dein gespeicherter Entwurf wurde wiederhergestellt.')),
      );
    } on Exception {
      _restoring = false;
    }
  }

  /// Beim Verlassen (Zurueck-Pfeil): Entwurf sofort sichern und kurz melden.
  void _onPopped() {
    _saveDebounce?.cancel();
    final text = _controller.text;
    if (text.trim().isEmpty || (_result != null && text == _submittedText)) return;
    final prefs = _prefs;
    final key = GutachtenPage.entwurfKey(widget.caseSlug);
    if (prefs != null) {
      prefs.setString(key, text);
    } else {
      SharedPreferences.getInstance().then((p) => p.setString(key, text));
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Entwurf gespeichert')),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _saveDebounce?.cancel();
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
      final text = _controller.text;
      final result = await app.api.submitCase(
        widget.caseSlug,
        text,
        mode: widget.mode,
        durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _submittedText = text;
        });
      }
      // Abgegeben: der lokale Entwurf wird nicht mehr gebraucht.
      _saveDebounce?.cancel();
      try {
        final prefs = _prefs ??= await SharedPreferences.getInstance();
        await prefs.remove(GutachtenPage.entwurfKey(widget.caseSlug));
      } on Exception {
        // Entwurf bleibt hoechstens als harmloser Rest liegen.
      }
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
        appBar: AppBar(
          toolbarHeight: 88,
          title: FitTitle(
            widget._titel,
            style: Theme.of(context).textTheme.titleMedium!,
          ),
          actions: [BetaFeedbackAction(screen: 'Fall: ${widget.caseTitle}')],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: SubsumoCard(
              child: SubsumoFeedbackBlock(
                message: 'Dieser Fall ist mit Pro verfügbar.',
                detail: caseUpgradeMessage,
                severity: FeedbackSeverity.hint,
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _onPopped();
      },
      child: Scaffold(
      // Lesemodus (SUB-160) blendet nur den Titel aus, behaelt aber eine
      // schmale AppBar mit dem Umschalter - eine schwebende Schaltflaeche
      // ueber dem Inhalt (statt in der Chrome) wuerde bei kurzen Fenstern
      // den Falltext im Editor ueberdecken koennen.
      appBar: AppBar(
        toolbarHeight: _focusMode ? null : 88,
        title: _focusMode
            ? null
            : FitTitle(
                widget._titel,
                style: Theme.of(context).textTheme.titleMedium!,
              ),
        actions: [
          BetaFeedbackAction(screen: 'Fall: ${widget.caseTitle}'),
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
            final feedback = _buildFeedback();
            if (!zweispaltig) {
              // Die ganze Seite scrollt: Sachverhalt vollstaendig, darunter
              // Editor mit fester Hoehe, dann das Feedback.
              return Scrollbar(
                child: ListView(
                  padding: const EdgeInsets.all(Spacing.lg),
                  children: [
                    ..._buildFacts(),
                    SizedBox(
                      // Klausur: grosses Schreibfeld statt Uebungshoehe.
                      height: _klausur
                          ? max(560, MediaQuery.sizeOf(context).height * 0.75)
                          : 420,
                      child: _buildEditor(),
                    ),
                    const SizedBox(height: Spacing.lg),
                    feedback,
                  ],
                ),
              );
            }
            // Zweispaltig scrollen beide Spalten getrennt: links Sachverhalt
            // + Editor, rechts Feedback/Ergebnis.
            return Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ..._buildFacts(),
                            SizedBox(
                              height: max(420, constraints.maxHeight * 0.6),
                              child: _buildEditor(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.lg),
                  Expanded(
                    flex: 2,
                    child: Scrollbar(
                      child: SingleChildScrollView(child: feedback),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ));
  }

  /// Sachverhalt und Fallfrage vollstaendig, ohne eigene Hoehenbegrenzung -
  /// der umgebende Scrollbereich traegt die Hoehe (Nutzertest: ein
  /// abgeschnittener Sachverhalt macht die Fallfrage unlesbar).
  List<Widget> _buildFacts() => [
        if (_case != null) ...[
          SubsumoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (landesLabel(_case!['bundesland']) case final land?) ...[
                  SubsumoChip(label: land, icon: Icons.location_on_outlined),
                  const SizedBox(height: Spacing.sm),
                ],
                const SubsumoEyebrow('Sachverhalt'),
                const SizedBox(height: Spacing.sm),
                Text(
                  _case!['facts'] as String? ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Spacing.md),
                const SubsumoEyebrow('Fallfrage'),
                const SizedBox(height: Spacing.xs),
                Text(
                  _case!['question'] as String? ?? '',
                  style: Theme.of(context).extension<SubsumoTypography>()!.headingSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
        ],
      ];

  Widget _buildTimer() {
    final minutes = (_case?['minutes'] as num?)?.toInt() ?? 300;
    final rest = Duration(minutes: minutes) - DateTime.now().difference(_startedAt);
    final over = rest.isNegative;
    final abs = rest.abs();
    String two(int n) => n.toString().padLeft(2, '0');
    final text = '${over ? '-' : ''}${two(abs.inHours)}:${two(abs.inMinutes % 60)}:${two(abs.inSeconds % 60)}';
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 20, color: over ? theme.colorScheme.error : null),
          const SizedBox(width: Spacing.sm),
          Text(
            over ? 'Zeit überschritten: $text' : 'Verbleibende Zeit: $text',
            key: const ValueKey('klausur-timer'),
            style: theme.textTheme.titleSmall?.copyWith(
              color: over ? theme.colorScheme.error : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          Text('von $minutes min', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildEditor() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_klausur) _buildTimer(),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                hintText: gutachtenPlatzhalter(
                  area: widget.area ?? _case?['area'] as String?,
                  question: _case?['question'] as String?,
                  facts: _case?['facts'] as String?,
                ),
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
    final Widget child;
    final String key;
    if (_result != null && !_resultStale) {
      key = 'result';
      child = _ResultView(result: _result!, showEngine: _aiCorrectionEnabled);
    } else if (_analysisUpgradeMessage case final analysisUpgradeMessage?) {
      key = 'analysis-upgrade';
      child = SubsumoCard(
        child: SubsumoFeedbackBlock(
          message: 'Strukturfeedback ist diese Woche mit Free aufgebraucht.',
          detail: analysisUpgradeMessage,
          severity: FeedbackSeverity.hint,
        ),
      );
    } else if (_structure case final structure?) {
      key = 'structure';
      child = _StructureView(structure: structure);
    } else {
      key = 'hint';
      child = const SubsumoCard(
        child: SubsumoFeedbackBlock(
          message: 'Schreib los. Ab etwa 40 Wörtern bekommst du hier laufend '
              'Rückmeldung zu Aufbau und Gutachtenstil.',
          severity: FeedbackSeverity.hint,
        ),
      );
    }

    // Ruhiger Wechsel statt hartem Umschalten, wenn die Strukturanalyse
    // erscheint oder sich der Feedback-Stand aendert (docs/25 Abschnitt 6) -
    // bestehende Motion-Tokens, keine neue Duration/Curve.
    final switcher = AnimatedSwitcher(
      duration: Motion.normal,
      switchInCurve: Motion.curve,
      switchOutCurve: Motion.curve,
      child: KeyedSubtree(key: ValueKey(key), child: child),
    );
    if (!_resultStale) return switcher;
    // Text nach der Abgabe geaendert: altes Ergebnis ausgeblendet, Hinweis +
    // wieder laufende Strukturrueckmeldung.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SubsumoCard(
          key: ValueKey('ergebnis-veraltet'),
          child: SubsumoFeedbackBlock(
            message: 'Ergebnis veraltet',
            detail: 'Du hast den Text seit der letzten Abgabe geändert. Die '
                'bisherige Bewertung gehörte zur alten Fassung - gib erneut ab, '
                'um eine aktuelle Bewertung zu bekommen.',
            severity: FeedbackSeverity.hint,
          ),
        ),
        const SizedBox(height: Spacing.md),
        switcher,
      ],
    );
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
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      // Eigene Flaeche statt nur eines gefaerbten Icons auf surface0 - bei
      // mehreren Findings im langen Fliesstext sonst schwer auseinander-
      // zuhalten (docs/25-ui-relaunch-brief.md Abschnitt 6). Bewusst
      // dieselbe neutrale Flaeche fuer jede Schwere - nur das Icon zeigt sie
      // weiterhin an.
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
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
                        style:
                            theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
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
  /// "Oberfläche unverändert bei ausgeschaltetem Feature" (Abnahme SUB-134)
  /// nicht mehr haelt.
  final bool showEngine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subsumo = theme.extension<SubsumoColors>();
    final rawEvaluation = result['evaluation'];
    if (rawEvaluation is! Map ||
        rawEvaluation['points'] == null ||
        rawEvaluation['checkpoints'] is! List) {
      // Die Antwort enthaelt keine (vollstaendige) Bewertung: ehrlich sagen,
      // statt eine halbe Anzeige oder einen Fehlerbildschirm zu zeigen.
      return const SubsumoCard(
        child: SubsumoFeedbackBlock(
          message: 'Deine Abgabe ist gespeichert, aber es liegt keine Punktbewertung vor.',
          detail: 'Der Struktur-/Stil-Check zu deinem Text bleibt verfügbar; '
              'Punktzahl und Erwartungshorizont gibt es für diese Abgabe nicht. '
              'Bitte später erneut versuchen.',
          severity: FeedbackSeverity.hint,
        ),
      );
    }
    final evaluation = rawEvaluation.cast<String, dynamic>();
    final checkpoints =
        (evaluation['checkpoints'] as List).cast<Map<String, dynamic>>();
    final engine = evaluation['engine'] as String? ?? 'heuristik';

    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_punkteText(evaluation['points'])} Punkte · ${evaluation['note']}',
            style: theme.textTheme.headlineSmall,
          ),
          if (showEngine) ...[
            const SizedBox(height: Spacing.xs),
            SubsumoChip(
              label: engine.startsWith('llm:') ? 'KI-bewertet' : 'Heuristisch geprüft',
            ),
          ],
          const SizedBox(height: Spacing.sm),
          Text(evaluation['summary'] as String? ?? ''),
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
            evaluation['disclaimer'] as String? ?? '',
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
                'Anbieter Anthropic übertragen und dort in den USA '
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
        child: const Text('Datenschutzerklärung'),
      ),
    );
  }
}

/// Beteiligte aus dem Fall: einzelne Grossbuchstaben bzw. Kuerzel wie "V",
/// "K", "T1" (in Reihenfolge des ersten Auftretens). Typische Abkuerzungen und
/// Rechtsbegriffe sind ausgenommen.
List<String> parteikuerzel(String? text) {
  if (text == null) return const [];
  const ignorieren = {'BGB', 'StGB', 'GG', 'ZPO', 'StPO', 'VwGO', 'VwVfG', 'HGB', 'EU', 'II', 'III', 'IV'};
  final seen = <String>[];
  for (final m in RegExp(r'(?<![\wÄÖÜäöüß-])([A-Z]\d?|[A-Z]{2})(?![\wÄÖÜäöüß])').allMatches(text)) {
    final k = m.group(1)!;
    if (!ignorieren.contains(k) && !seen.contains(k)) seen.add(k);
  }
  return seen;
}

/// Platzhalter im Loesungsfeld je Rechtsgebiet des Falls (Zivilrecht:
/// Anspruchsaufbau, Strafrecht: Strafbarkeitspruefung, Oeffentliches Recht:
/// Erfolgsaussichten). Parteikuerzel kommen, wenn erkennbar, aus dem Fall.
String gutachtenPlatzhalter({String? area, String? question, String? facts}) {
  final parteien = parteikuerzel(question);
  final alle = parteien.length >= 2 ? parteien : parteikuerzel('${question ?? ''} ${facts ?? ''}');
  switch (area) {
    case 'zivilrecht':
      final frage = _frageSatz(question);
      if (frage != null && !frage.toLowerCase().contains('anspruch')) {
        return frage;
      }
      if (alle.length >= 2) {
        return '${alle[0]} könnte gegen ${alle[1]} einen Anspruch auf ... aus § ... haben.';
      }
      return 'Ein Anspruch auf ... aus § ... könnte bestehen.';
    case 'strafrecht':
      final tater = alle.contains('T') ? 'T' : (alle.isNotEmpty ? alle.first : null);
      if (tater != null) {
        return '$tater könnte sich wegen ... gemäß § ... strafbar gemacht haben.';
      }
      return 'Die handelnde Person könnte sich wegen ... gemäß § ... strafbar gemacht haben.';
    case 'oeffentliches-recht':
      return _oerPlatzhalter(question, facts);
    default:
      return 'Beginne mit dem Obersatz im Gutachtenstil: ... könnte ... , wenn ...';
  }
}

/// Gutachtensatz fuer Fragen ohne Anspruch ("Hat K Eigentum erworben?" ->
/// "K könnte Eigentum ... erworben haben."); sonst `null`.
String? _frageSatz(String? question) {
  final q = (question ?? '').trim();
  if (q.isEmpty || !q.endsWith('?')) return null;
  final m = RegExp(r'^(?:Hat|Haben)\s+([A-Z]\d?)\s+(.+?)\s+(\w+)\?$').firstMatch(q);
  if (m != null) {
    return '${m.group(1)} könnte ${m.group(2)} ... ${m.group(3)} haben.';
  }
  if (RegExp(r'^(?:Ist|Sind|Wurde|Wurden|War|Waren|Liegt|Hat|Haben)\b').hasMatch(q)) {
    return 'Fraglich ist, ob ...';
  }
  return null;
}

/// Platzhalter fuer oeffentlich-rechtliche Fragen, abgeleitet aus der Fallfrage.
String _oerPlatzhalter(String? question, String? facts) {
  final q = (question ?? '').trim();
  final lower = q.toLowerCase();
  if (lower.contains('verfassungsgemäß') ||
      lower.contains('verfassungsgemaess') ||
      lower.contains('verfassungsmäßig') ||
      lower.contains('verfassungswidrig') ||
      (lower.contains('gesetz') && lower.contains('verfassung'))) {
    return 'Das Gesetz ist verfassungsgemäß, wenn es formell und materiell mit dem Grundgesetz vereinbar ist.';
  }
  if (lower.contains('rechtmäßig') ||
      lower.contains('rechtmaessig') ||
      lower.contains('rechtswidrig')) {
    final subjekt = RegExp(
      r'\b(?:Ist|Sind|War|Waren)\s+((?:der|die|das|den|dem)\s+[^?]+?)\s+(?:rechtmäßig|rechtmaessig|rechtswidrig)',
      caseSensitive: false,
    ).firstMatch(q)?.group(1);
    final text = subjekt == null
        ? 'Die Maßnahme'
        : '${subjekt[0].toUpperCase()}${subjekt.substring(1)}';
    return '$text ist rechtmäßig, wenn ...';
  }
  return 'Die Klage hat Erfolg, wenn sie zulässig und begründet ist.';
}


/// "3.5" -> "3,5", "11.0" -> "11" (deutsche Schreibweise der Punktzahl).
String _punkteText(Object? points) {
  final n = points is num ? points : num.tryParse('$points');
  if (n == null) return '$points';
  if (n == n.roundToDouble()) return n.round().toString();
  return n.toString().replaceAll('.', ',');
}
