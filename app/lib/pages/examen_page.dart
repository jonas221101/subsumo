import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';
import 'gutachten_page.dart';
import 'review_page.dart';
import 'screen_status.dart';

/// Examen-Reiter (docs/32-examensvorbereitung.md).
///
/// Ein Screen, der die Vorbereitung als Ganzes zeigt: Profil (Bundesland,
/// Universitaet, Termin), Countdown und Phase, Examensreife in benannten
/// Komponenten, das Pruefungsprofil des Landes, die Kurs-Decks der
/// Universitaet, das Landesrecht-Deck, Schwachstellen aus den Abgaben, der
/// naechste Klausurtag und die Checkliste. Alle Daten kommen aus einem
/// Aufruf (`GET /v1/examen/cockpit`), damit die Seite auch bei schlechtem
/// Netz in einem Stueck erscheint statt in Etappen.
///
/// Gestaltung nach docs/25 Abschnitt 6: Flaeche statt Schatten, eine
/// Fortschrittsfarbe unabhaengig vom Wert, Outline-Icons, keine Ampel.
const _areaLabels = {
  'zivilrecht': 'Zivilrecht',
  'strafrecht': 'Strafrecht',
  'oeffentliches-recht': 'Oeffentliches Recht',
};

const _phaseLabels = {
  'grundlagen': 'Grundlagen',
  'vertiefung': 'Vertiefung',
  'endspurt': 'Endspurt',
};

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

class ExamenPage extends StatefulWidget {
  const ExamenPage({super.key});

  @override
  State<ExamenPage> createState() => _ExamenPageState();
}

class _ExamenPageState extends State<ExamenPage> {
  bool _editingProfile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context).loadExamen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cockpit = app.examenCockpit;

    if (cockpit == null) {
      return app.loading
          ? const ScreenStatus.loading()
          : ScreenStatus.error(
              message: app.error ?? 'Keine Daten',
              onRetry: app.loadExamen,
            );
    }

    final profil = _map(cockpit['profil']);
    final vollstaendig = profil['vollstaendig'] == true;
    final phase = cockpit['phase'] == null ? null : _map(cockpit['phase']);
    final reife = _map(cockpit['examensreife']);
    final bundesland = cockpit['bundesland'] == null ? null : _map(cockpit['bundesland']);
    final decks = _maps(cockpit['kurs_decks']);
    final landesrecht = _map(cockpit['landesrecht_deck']);
    final schwachstellen = _map(cockpit['schwachstellen']);
    final klausur = _map(cockpit['naechste_klausur']);
    final checkliste = _maps(cockpit['checkliste']);
    final plan = _maps(cockpit['plan']);

    return ReadableWidth(
      child: RefreshIndicator(
        onRefresh: app.loadExamen,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            if (!vollstaendig || _editingProfile)
              _ProfilEditor(
                profil: profil,
                onSaved: () => setState(() => _editingProfile = false),
                onCancel: vollstaendig ? () => setState(() => _editingProfile = false) : null,
              )
            else
              _ProfilSummary(
                profil: profil,
                onEdit: () => setState(() => _editingProfile = true),
              ),
            const SizedBox(height: Spacing.lg),
            if (phase != null) ...[
              _PhaseCard(phase: phase),
              const SizedBox(height: Spacing.lg),
            ],
            _ReifeCard(reife: reife),
            const SizedBox(height: Spacing.lg),
            if (plan.isNotEmpty) ...[
              _HeuteCard(plan: plan),
              const SizedBox(height: Spacing.lg),
            ],
            _KlausurCard(klausur: klausur),
            const SizedBox(height: Spacing.lg),
            if (_maps(landesrecht['topics']).isNotEmpty) ...[
              _LandesrechtCard(
                deck: landesrecht,
                pruefstatus: bundesland?['pruefstatus'] as String?,
              ),
              const SizedBox(height: Spacing.lg),
            ],
            _DecksCard(decks: decks, hatUniversitaet: profil['universitaet'] != null),
            const SizedBox(height: Spacing.lg),
            if ((schwachstellen['abgaben'] as int? ?? 0) > 0) ...[
              _SchwachstellenCard(schwachstellen: schwachstellen),
              const SizedBox(height: Spacing.lg),
            ],
            if (checkliste.isNotEmpty) ...[
              _ChecklisteCard(checkliste: checkliste),
              const SizedBox(height: Spacing.lg),
            ],
            if (bundesland != null) _BundeslandCard(bundesland: bundesland),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Profil
// --------------------------------------------------------------------------- //

class _ProfilSummary extends StatelessWidget {
  const _ProfilSummary({required this.profil, required this.onEdit});

  final Map<String, dynamic> profil;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final land = profil['bundesland'] == null ? null : _map(profil['bundesland']);
    final uni = profil['universitaet'] == null ? null : _map(profil['universitaet']);
    final examDate = profil['exam_date'] as String?;
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Examensprofil', style: theme.textTheme.titleMedium)),
              IconButton(
                tooltip: 'Profil bearbeiten',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            [
              if (land != null) land['name'] as String,
              if (uni != null) uni['kurzname'] as String,
              if (examDate != null) 'Examen am ${_formatIsoDate(examDate)}',
              '${profil['daily_minutes']} min/Tag',
            ].join('  ·  '),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Onboarding und Bearbeitung in einem: Bundesland, Universitaet (aus dem
/// Bundesland gefiltert), Examensdatum, Tagesbudget. Die Universitaet legt
/// serverseitig das Bundesland fest, deshalb setzt die Auswahl einer
/// Universitaet hier auch das Bundesland-Feld.
class _ProfilEditor extends StatefulWidget {
  const _ProfilEditor({required this.profil, required this.onSaved, this.onCancel});

  final Map<String, dynamic> profil;
  final VoidCallback onSaved;
  final VoidCallback? onCancel;

  @override
  State<_ProfilEditor> createState() => _ProfilEditorState();
}

class _ProfilEditorState extends State<_ProfilEditor> {
  List<Map<String, dynamic>> _laender = [];
  List<Map<String, dynamic>> _unis = [];
  bool _listenLoading = true;
  bool _busy = false;
  String? _error;

  String? _bundesland;
  String? _universitaet;
  DateTime? _examDate;
  late final TextEditingController _minuten;

  @override
  void initState() {
    super.initState();
    final land = widget.profil['bundesland'];
    final uni = widget.profil['universitaet'];
    _bundesland = land is Map ? land['code'] as String? : null;
    _universitaet = uni is Map ? uni['slug'] as String? : null;
    final examDate = widget.profil['exam_date'] as String?;
    _examDate = examDate == null ? null : DateTime.tryParse(examDate);
    _minuten = TextEditingController(text: '${widget.profil['daily_minutes'] ?? 90}');
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadListen());
  }

  @override
  void dispose() {
    _minuten.dispose();
    super.dispose();
  }

  Future<void> _loadListen() async {
    final api = AppScope.of(context).api;
    try {
      final laender = await api.examenBundeslaender();
      final unis = await api.examenUniversitaeten();
      if (!mounted) return;
      setState(() {
        _laender = laender;
        _unis = unis;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _error = 'Auswahllisten konnten nicht geladen werden.');
    } finally {
      if (mounted) setState(() => _listenLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? now.add(const Duration(days: 180)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 6),
      helpText: 'Erster Klausurtag des Examens',
    );
    if (picked != null && mounted) setState(() => _examDate = picked);
  }

  Future<void> _save() async {
    final minuten = int.tryParse(_minuten.text.trim());
    if (minuten == null || minuten < 15 || minuten > 600) {
      setState(() => _error = 'Tagesbudget zwischen 15 und 600 Minuten angeben.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final app = AppScope.of(context);
    final ok = await app.saveProfile({
      'bundesland': _bundesland ?? '',
      'universitaet_slug': _universitaet ?? '',
      if (_examDate != null) 'exam_date': _isoDate(_examDate!),
      'daily_minutes': minuten,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      widget.onSaved();
    } else {
      setState(() => _error = app.error ?? 'Speichern fehlgeschlagen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unisImLand = _unis.where((u) => _bundesland == null || u['bundesland'] == _bundesland);
    final uniWerte = unisImLand.map((u) => u['slug'] as String).toSet();
    final uniValue = uniWerte.contains(_universitaet) ? _universitaet : null;

    return SubsumoCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Examensprofil einrichten', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.xs),
          Text(
            'Bundesland und Universitaet bestimmen, welches Landesrecht du lernst, '
            'wie die Klausuren gewichtet werden und welche Kurs-Decks du siehst. '
            'Der Examenstermin steuert Phase und Tagesplan.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Spacing.lg),
          if (_listenLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Spacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Bundesland (Pruefungsort)'),
              child: DropdownButton<String?>(
                key: const ValueKey('bundesland'),
                isExpanded: true,
                underline: const SizedBox.shrink(),
                value: _bundesland,
                hint: const Text('Bitte waehlen'),
                items: [
                  for (final land in _laender)
                    DropdownMenuItem<String?>(
                      value: land['code'] as String,
                      child: Text(land['name'] as String),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _bundesland = value;
                  if (value != null && _universitaet != null) {
                    final uni = _unis.where((u) => u['slug'] == _universitaet);
                    if (uni.isNotEmpty && uni.first['bundesland'] != value) _universitaet = null;
                  }
                }),
              ),
            ),
            const SizedBox(height: Spacing.md),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Universitaet'),
              child: DropdownButton<String?>(
                key: const ValueKey('universitaet'),
                isExpanded: true,
                underline: const SizedBox.shrink(),
                value: uniValue,
                hint: const Text('Keine Angabe'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Keine Angabe')),
                  for (final uni in unisImLand)
                    DropdownMenuItem<String?>(
                      value: uni['slug'] as String,
                      child: Text(uni['kurzname'] as String? ?? uni['name'] as String),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _universitaet = value;
                  if (value != null) {
                    final uni = _unis.firstWhere((u) => u['slug'] == value);
                    _bundesland = uni['bundesland'] as String?;
                  }
                }),
              ),
            ),
          ],
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  _examDate == null
                      ? 'Kein Examenstermin gesetzt'
                      : 'Examen ab ${_formatDate(_examDate!)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              SubsumoButton.secondary(
                label: _examDate == null ? 'Termin waehlen' : 'Termin aendern',
                icon: Icons.calendar_today_outlined,
                onPressed: _pickDate,
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          SubsumoTextField(
            label: 'Tagesbudget in Minuten',
            controller: _minuten,
            keyboardType: TextInputType.number,
          ),
          if (_error != null) ...[
            const SizedBox(height: Spacing.sm),
            SubsumoFeedbackBlock(message: _error!, severity: FeedbackSeverity.negative),
          ],
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              if (widget.onCancel != null) ...[
                SubsumoButton.tertiary(label: 'Abbrechen', onPressed: _busy ? null : widget.onCancel),
                const SizedBox(width: Spacing.sm),
              ],
              Expanded(
                child: SubsumoButton.primary(
                  label: _busy ? 'Bitte warten ...' : 'Profil speichern',
                  onPressed: _busy ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Phase und Examensreife
// --------------------------------------------------------------------------- //

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.phase});

  final Map<String, dynamic> phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tage = phase['tage_bis_examen'] as int;
    final name = _phaseLabels[phase['phase']] ?? '${phase['phase']}';
    final phasen = _maps(phase['phasen']);
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tage > 0 ? '$tage Tage bis zum Examen' : 'Examen laeuft',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.xs),
          Text('Phase: $name', style: theme.textTheme.bodyMedium),
          const SizedBox(height: Spacing.sm),
          SubsumoProgressMeter(value: (phase['fortschritt'] as num).toDouble()),
          const SizedBox(height: Spacing.sm),
          Text(
            [
              for (final p in phasen)
                '${_phaseLabels[p['name']] ?? p['name']}: bis ${_formatIsoDate(p['bis'] as String)}',
            ].join('  ·  '),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Vorbereitungsbeginn ${_formatIsoDate(phase['vorbereitungsbeginn'] as String)} - '
            'die Phase haengt an diesem Datum, nicht am heutigen Aufruf.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ReifeCard extends StatelessWidget {
  const _ReifeCard({required this.reife});

  final Map<String, dynamic> reife;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gesamt = (reife['gesamt'] as num).toDouble();
    final komponenten = _map(reife['komponenten']);
    final byArea = _map(reife['by_area']);
    return SubsumoCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Examensreife', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.md),
          Text('${(gesamt * 100).round()} %', style: theme.textTheme.displaySmall),
          const SizedBox(height: Spacing.sm),
          SubsumoProgressMeter(value: gesamt),
          const SizedBox(height: Spacing.md),
          Text(
            'Kein Notenersatz: gewichteter Mittelwert der messbaren Komponenten. '
            'Formel: ${reife['formel']}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Spacing.lg),
          for (final entry in komponenten.entries) ...[
            _Komponente(key: ValueKey('komponente-${entry.key}'), daten: _map(entry.value)),
            const SizedBox(height: Spacing.sm),
          ],
          const SizedBox(height: Spacing.sm),
          Text('Nach Rechtsgebiet', style: theme.textTheme.titleSmall),
          const SizedBox(height: Spacing.sm),
          for (final area in byArea.entries) ...[
            SubsumoProgressMeter(
              label: _areaSubtitle(area.key, _map(area.value)),
              value: (_map(area.value)['coverage'] as num).toDouble(),
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ],
      ),
    );
  }

  static String _areaSubtitle(String area, Map<String, dynamic> daten) {
    final label = _areaLabels[area] ?? area;
    final klausuren = daten['klausuren'];
    final gewicht = ((daten['gewicht'] as num) * 100).round();
    return klausuren == null
        ? '$label  ·  Gewicht $gewicht %'
        : '$label  ·  $klausuren Klausur(en)  ·  Gewicht $gewicht %';
  }
}

class _Komponente extends StatelessWidget {
  const _Komponente({required this.daten, super.key});

  final Map<String, dynamic> daten;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = daten['value'];
    final label = daten['label'] as String;
    final detail = daten['detail'] as String? ?? '';
    if (value == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: noch nicht messbar', style: theme.textTheme.bodyMedium),
          Text(detail, style: theme.textTheme.bodySmall),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubsumoProgressMeter(label: label, value: (value as num).toDouble()),
        const SizedBox(height: 2),
        Text(detail, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

// --------------------------------------------------------------------------- //
// Heute, Klausur, Landesrecht, Decks
// --------------------------------------------------------------------------- //

class _HeuteCard extends StatelessWidget {
  const _HeuteCard({required this.plan});

  final List<Map<String, dynamic>> plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heute = plan.first;
    final blocks = _maps(heute['blocks']);
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Heute  ·  ${heute['total_minutes']} min  ·  '
            '${_phaseLabels[heute['phase']] ?? heute['phase']}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.sm),
          for (final block in blocks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(_blockIcon(block['kind'] as String? ?? ''),
                  color: theme.colorScheme.onSurfaceVariant),
              title: Text(block['title'] as String),
              trailing: Text('${block['minutes']} min'),
            ),
          if ((heute['review_backlog'] as int? ?? 0) > 0)
            Text(
              'Rueckstand: ${heute['review_backlog']} Karten werden auf die Folgetage verteilt.',
              style: theme.textTheme.bodySmall,
            ),
          if (plan.length > 1) ...[
            const Divider(height: Spacing.xl),
            Text('Naechste Tage', style: theme.textTheme.titleSmall),
            const SizedBox(height: Spacing.xs),
            for (final tag in plan.skip(1))
              Text(
                '${_weekdayOf(tag['date'] as String)} ${_formatIsoDate(tag['date'] as String)}: '
                '${tag['total_minutes']} min, ${_maps(tag['blocks']).length} Bloecke',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ],
      ),
    );
  }

  static IconData _blockIcon(String kind) => switch (kind) {
        'wiederholung' => Icons.replay_outlined,
        'neu' => Icons.menu_book_outlined,
        'fall' => Icons.gavel_outlined,
        'klausur' => Icons.timer_outlined,
        _ => Icons.hourglass_empty_outlined,
      };
}

class _KlausurCard extends StatelessWidget {
  const _KlausurCard({required this.klausur});

  final Map<String, dynamic> klausur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vorschlag = klausur['vorschlag'] == null ? null : _map(klausur['vorschlag']);
    final datum = klausur['datum'] as String;
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Naechste Klausur unter Examensbedingungen', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.xs),
          Text(
            '${_weekdayOf(datum)}, ${_formatIsoDate(datum)}  ·  fuenf Stunden, nur zugelassene '
            'Hilfsmittel, ohne Unterbrechung.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Spacing.md),
          if (vorschlag == null)
            const SubsumoFeedbackBlock(
              message: 'Noch kein Fall verfuegbar.',
              severity: FeedbackSeverity.neutral,
            )
          else ...[
            Text(vorschlag['title'] as String, style: theme.textTheme.titleSmall),
            const SizedBox(height: Spacing.xs),
            Text(
              '${_areaLabels[vorschlag['area']] ?? vorschlag['area']}  ·  '
              'Schwierigkeit ${vorschlag['difficulty']}/5  ·  ${vorschlag['minutes']} min',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.xs),
            Text(vorschlag['begruendung'] as String? ?? '', style: theme.textTheme.bodySmall),
            const SizedBox(height: Spacing.md),
            SubsumoButton.primary(
              label: 'Klausur schreiben',
              icon: Icons.timer_outlined,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GutachtenPage(
                    caseSlug: vorschlag['slug'] as String,
                    caseTitle: vorschlag['title'] as String,
                    mode: 'klausur',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LandesrechtCard extends StatelessWidget {
  const _LandesrechtCard({required this.deck, required this.pruefstatus});

  final Map<String, dynamic> deck;
  final String? pruefstatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topics = _maps(deck['topics']);
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Landesrecht-Deck', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.xs),
          Text(
            '${deck['cards_mature']} von ${deck['cards_total']} Karten reif  ·  '
            '${deck['cards_due']} faellig',
            style: theme.textTheme.bodySmall,
          ),
          if (pruefstatus == 'in-pruefung') ...[
            const SizedBox(height: Spacing.sm),
            const SubsumoFeedbackBlock(
              message: 'Redaktionsstatus: in Pruefung.',
              detail: 'Normzitate gegen die aktuelle Gesetzesfassung deines Landes pruefen.',
              severity: FeedbackSeverity.hint,
            ),
          ],
          const SizedBox(height: Spacing.md),
          for (final topic in topics) ...[
            _TopicRow(
              topic: topic,
              onLearn: () => _openDeck(
                context,
                DeckFilter(title: topic['title'] as String, topic: topic['slug'] as String),
              ),
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, this.onLearn});

  final Map<String, dynamic> topic;
  final VoidCallback? onLearn;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: SubsumoProgressMeter(
            label: '${topic['title']}  ·  ${topic['cards_mature']}/${topic['cards_total']} reif',
            value: (topic['mastery'] as num).toDouble(),
          ),
        ),
        if (onLearn != null) ...[
          const SizedBox(width: Spacing.sm),
          IconButton(
            tooltip: 'Lernen',
            icon: const Icon(Icons.play_arrow_outlined),
            onPressed: onLearn,
          ),
        ],
      ],
    );
  }
}

class _DecksCard extends StatelessWidget {
  const _DecksCard({required this.decks, required this.hatUniversitaet});

  final List<Map<String, dynamic>> decks;
  final bool hatUniversitaet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kurs-Decks', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.xs),
          Text(
            hatUniversitaet
                ? 'In der Reihenfolge des Studienverlaufsplans deiner Universitaet. '
                    'Jedes Deck enthaelt die Karten, Schemata und Faelle seiner Themen - '
                    'plus das Landesrecht deines Bundeslands, wo es hingehoert.'
                : 'Der komplette Kurskatalog. Mit einer Universitaet im Profil erscheint '
                    'hier der Studienverlaufsplan in Semesterreihenfolge.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Spacing.sm),
          for (final deck in decks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                deck['examenskurs'] == true ? Icons.school_outlined : Icons.menu_book_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(deck['title'] as String),
              subtitle: Text(
                'Semester ${deck['semester_default']}  ·  '
                '${deck['cards_mature']} von ${deck['cards_total']} Karten reif  ·  '
                '${deck['cards_due']} faellig',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => DeckDetailPage(deck: deck)),
              ),
            ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Schwachstellen, Checkliste, Bundesland
// --------------------------------------------------------------------------- //

class _SchwachstellenCard extends StatelessWidget {
  const _SchwachstellenCard({required this.schwachstellen});

  final Map<String, dynamic> schwachstellen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themen = _maps(schwachstellen['themen']);
    final fehler = _maps(schwachstellen['strukturfehler']);
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Schwachstellen aus ${schwachstellen['abgaben']} Abgaben',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          if (themen.isEmpty && fehler.isEmpty)
            const SubsumoFeedbackBlock(
              message: 'Keine verfehlten Pruefpunkte und keine Strukturfehler.',
              severity: FeedbackSeverity.positive,
            ),
          for (final thema in themen)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.flag_outlined, color: theme.colorScheme.onSurfaceVariant),
              title: Text(thema['title'] as String),
              subtitle: Text(
                '${thema['verfehlte_pruefpunkte']} verfehlte Pruefpunkte'
                '${_strings(thema['beispiele']).isEmpty ? '' : ': ${_strings(thema['beispiele']).join('; ')}'}',
              ),
            ),
          if (fehler.isNotEmpty) ...[
            const SizedBox(height: Spacing.sm),
            Text('Haeufigste Strukturfehler', style: theme.textTheme.titleSmall),
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.xs,
              children: [
                for (final f in fehler) SubsumoChip(label: '${f['code']} (${f['anzahl']})'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChecklisteCard extends StatelessWidget {
  const _ChecklisteCard({required this.checkliste});

  final List<Map<String, dynamic>> checkliste;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortiert = [...checkliste]
      ..sort((a, b) {
        final aDran = a['jetzt_dran'] == true ? 0 : 1;
        final bDran = b['jetzt_dran'] == true ? 0 : 1;
        if (aDran != bDran) return aDran - bDran;
        return ((b['monate_vor_examen'] as num?) ?? 0).compareTo((a['monate_vor_examen'] as num?) ?? 0);
      });
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Checkliste bis zum Examen', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          for (final item in sortiert)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item['jetzt_dran'] == true ? Icons.flag_outlined : Icons.check_box_outline_blank,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(item['titel'] as String),
              subtitle: Text(
                '${item['jetzt_dran'] == true ? 'Jetzt dran  ·  ' : ''}'
                '${item['monate_vor_examen']} Monate vor dem Examen\n${item['detail']}',
              ),
              isThreeLine: true,
            ),
        ],
      ),
    );
  }
}

class _BundeslandCard extends StatelessWidget {
  const _BundeslandCard({required this.bundesland});

  final Map<String, dynamic> bundesland;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final klausuren = _map(bundesland['klausuren']);
    final verteilung = _map(klausuren['verteilung']);
    final landesrecht = _map(bundesland['landesrecht']);
    final normen = _map(landesrecht['normenspiegel']);
    final amt = _map(bundesland['pruefungsamt']);
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pruefung in ${bundesland['name']}', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.xs),
          Text(
            '${klausuren['anzahl']} Klausuren a ${klausuren['dauer_minuten']} min: '
            '${verteilung.entries.map((e) => '${_areaLabels[e.key] ?? e.key} ${e.value}').join(', ')}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            '${amt['name']} (${amt['sitz']})  ·  ${bundesland['pruefungsordnung']}  ·  '
            'Stand ${bundesland['stand']}',
            style: theme.textTheme.bodySmall,
          ),
          if (bundesland['pruefstatus'] == 'in-pruefung') ...[
            const SizedBox(height: Spacing.sm),
            const SubsumoFeedbackBlock(
              message: 'Angaben ohne Gewaehr - Redaktionsstatus: in Pruefung.',
              detail: 'Massgeblich sind JAG/JAPO und die Bekanntmachungen des Pruefungsamts.',
              severity: FeedbackSeverity.hint,
            ),
          ],
          _Abschnitt(
            titel: 'Termine, Freiversuch, Abschichtung',
            zeilen: [
              'Termine: ${_strings(bundesland['termine']).join('; ')}',
              'Freiversuch: ${_map(bundesland['freiversuch'])['beschreibung']}',
              'Abschichtung: ${_map(bundesland['abschichtung'])['beschreibung']}',
              'Notenverbesserung: ${_map(bundesland['notenverbesserung'])['beschreibung']}',
              'Muendliche Pruefung: ${_map(bundesland['muendliche_pruefung'])['beschreibung']}',
            ],
          ),
          _Abschnitt(
            titel: 'Zugelassene Hilfsmittel',
            zeilen: _strings(bundesland['hilfsmittel']),
          ),
          _Abschnitt(
            titel: 'Landesrecht im Pflichtstoff',
            zeilen: [
              ..._strings(landesrecht['schwerpunkte']),
              for (final e in normen.entries) '${_normLabel(e.key)}: ${e.value}',
            ],
          ),
          if (_strings(landesrecht['besonderheiten']).isNotEmpty)
            _Abschnitt(
              titel: 'Besonderheiten',
              zeilen: _strings(landesrecht['besonderheiten']),
            ),
        ],
      ),
    );
  }

  static String _normLabel(String key) => switch (key) {
        'polizeigesetz' => 'Polizeigesetz',
        'polizei_generalklausel' => 'Generalklausel',
        'standardmassnahmen' => 'Standardmassnahmen',
        'stoerer' => 'Stoerer',
        'ordnungsbehoerden' => 'Zustaendigkeit',
        'verwaltungsverfahrensgesetz' => 'VwVfG',
        'vollstreckung' => 'Vollstreckung',
        'kommunalverfassung' => 'Kommunalverfassung',
        'bauordnung' => 'Bauordnung',
        'landesverfassung' => 'Landesverfassung',
        'verfassungsgericht' => 'Verfassungsgericht',
        'individualverfassungsbeschwerde' => 'Verfassungsbeschwerde',
        _ => key,
      };
}

class _Abschnitt extends StatelessWidget {
  const _Abschnitt({required this.titel, required this.zeilen});

  final String titel;
  final List<String> zeilen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: Spacing.md),
      shape: const Border(),
      title: Text(titel, style: theme.textTheme.titleSmall),
      children: [
        for (final zeile in zeilen)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(zeile, style: theme.textTheme.bodySmall),
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------------- //
// Deck-Detail und Deck-Lernschleife
// --------------------------------------------------------------------------- //

/// Ein Kurs-Deck im Detail: Lernziele, Themen mit Reife, Schemata, Faelle
/// und der Einstieg in die Lernschleife nur fuer dieses Deck.
class DeckDetailPage extends StatelessWidget {
  const DeckDetailPage({required this.deck, super.key});

  final Map<String, dynamic> deck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topics = _maps(deck['topics']);
    final schemata = _maps(deck['schemata']);
    final cases = _maps(deck['cases']);
    final lernziele = _strings(deck['lernziele']);
    final fehlend = _strings(deck['fehlende_themen']);
    final landesrechtFehlt = _strings(deck['landesrecht_fehlt']);
    final klausur = _map(deck['klausurformat']);
    final mastery = (deck['mastery'] as num? ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(title: Text(deck['title'] as String)),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            SubsumoCard(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(deck['beschreibung'] as String? ?? '', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    '${_areaLabels[deck['area']] ?? deck['area']}  ·  '
                    'Klausur: ${klausur['typ'] ?? '-'}, ${klausur['minuten'] ?? '-'} min',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: Spacing.md),
                  SubsumoProgressMeter(
                    label: '${deck['cards_mature']} von ${deck['cards_total']} Karten reif',
                    value: mastery,
                  ),
                  const SizedBox(height: Spacing.md),
                  SubsumoButton.primary(
                    label: 'Deck lernen (${deck['cards_due']} faellig)',
                    icon: Icons.style_outlined,
                    onPressed: () => _openDeck(
                      context,
                      DeckFilter(title: deck['title'] as String, deck: deck['slug'] as String),
                    ),
                  ),
                ],
              ),
            ),
            if (lernziele.isNotEmpty) ...[
              const SizedBox(height: Spacing.lg),
              Text('Lernziele', style: theme.textTheme.titleMedium),
              const SizedBox(height: Spacing.sm),
              for (final ziel in lernziele)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: SubsumoFeedbackBlock(message: ziel, severity: FeedbackSeverity.neutral),
                ),
            ],
            if (landesrechtFehlt.isNotEmpty) ...[
              const SizedBox(height: Spacing.lg),
              const SubsumoFeedbackBlock(
                message: 'Landesrecht fehlt in diesem Deck.',
                detail: 'Waehle im Examen-Reiter ein Bundesland, dann kommt das passende '
                    'Landesrecht dazu.',
                severity: FeedbackSeverity.hint,
              ),
            ],
            const SizedBox(height: Spacing.lg),
            Text('Themen', style: theme.textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            for (final topic in topics) ...[
              _TopicRow(topic: topic),
              const SizedBox(height: Spacing.sm),
            ],
            if (schemata.isNotEmpty) ...[
              const SizedBox(height: Spacing.lg),
              Text('Schemata', style: theme.textTheme.titleMedium),
              const SizedBox(height: Spacing.sm),
              for (final schema in schemata)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.account_tree_outlined,
                      color: theme.colorScheme.onSurfaceVariant),
                  title: Text(schema['title'] as String),
                ),
            ],
            if (cases.isNotEmpty) ...[
              const SizedBox(height: Spacing.lg),
              Text('Faelle', style: theme.textTheme.titleMedium),
              const SizedBox(height: Spacing.sm),
              for (final fall in cases)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.gavel_outlined, color: theme.colorScheme.onSurfaceVariant),
                  title: Text(fall['title'] as String),
                  subtitle: Text(
                    'Schwierigkeit ${fall['difficulty']}/5  ·  ${fall['minutes']} min',
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
            ],
            if (fehlend.isNotEmpty) ...[
              const SizedBox(height: Spacing.lg),
              SubsumoFeedbackBlock(
                message: 'Noch nicht im Deck (Content in Arbeit):',
                detail: fehlend.join('; '),
                severity: FeedbackSeverity.hint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lernschleife fuer ein Deck: derselbe [ReviewPage]-Screen, nur mit
/// gesetztem [AppState.activeDeck]. Der Filter endet mit dieser Route.
class DeckReviewPage extends StatefulWidget {
  const DeckReviewPage({required this.filter, super.key});

  final DeckFilter filter;

  @override
  State<DeckReviewPage> createState() => _DeckReviewPageState();
}

class _DeckReviewPageState extends State<DeckReviewPage> {
  bool _focusMode = false;
  AppState? _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
  }

  @override
  void dispose() {
    _app?.clearDeck();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _focusMode ? null : AppBar(title: Text('Deck: ${widget.filter.title}')),
      body: SafeArea(
        top: _focusMode,
        child: ReviewPage(
          focusMode: _focusMode,
          onToggleFocusMode: () => setState(() => _focusMode = !_focusMode),
        ),
      ),
    );
  }
}

Future<void> _openDeck(BuildContext context, DeckFilter filter) async {
  final app = AppScope.of(context);
  app.activeDeck = filter;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => DeckReviewPage(filter: filter)),
  );
}

// --------------------------------------------------------------------------- //
// Helfer
// --------------------------------------------------------------------------- //

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? [for (final item in value) if (item is Map) Map<String, dynamic>.from(item)]
    : <Map<String, dynamic>>[];

List<String> _strings(Object? value) =>
    value is List ? [for (final item in value) '$item'] : <String>[];

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String _formatIsoDate(String iso) {
  final parsed = DateTime.tryParse(iso);
  return parsed == null ? iso : _formatDate(parsed);
}

String _isoDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _weekdayOf(String iso) {
  final parsed = DateTime.tryParse(iso);
  return parsed == null ? '' : _wochentage[parsed.weekday - 1];
}
