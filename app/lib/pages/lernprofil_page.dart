import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';

/// Lernprofil (docs/33-individualisierung.md): alles, was die App an den
/// Nutzer anpasst, auf einer Seite - Semester und Ziel, Schwerpunkte,
/// Rhythmus, Gedaechtnis-Sicherheitsniveau, Fokus-/Pause-Themen und eigene
/// Decks. Jede Einstellung aendert Verhalten (Stapel, Intervalle, Plan,
/// naechster Schritt), keine ist Dekoration.
///
/// Speichern ersetzt das Profil komplett (`PUT /v1/me/lernprofil`).
const _ziele = {
  'orientierung': 'Orientierung (erste Semester)',
  'zwischenpruefung': 'Zwischenpruefung',
  'semesterklausur': 'Semesterklausuren',
  'examen': 'Examen',
  'wiederholung': 'Wiederholung / Auffrischung',
};

const _areaLabels = {
  'zivilrecht': 'Zivilrecht',
  'strafrecht': 'Strafrecht',
  'oeffentliches-recht': 'Oeffentliches Recht',
};

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

const _sicherheitsniveaus = {
  'kompakt': ('Kompakt', 'weniger Wiederholungen, mehr Vergessensrisiko'),
  'standard': ('Standard', 'FSRS-Ziel-Retention je Kartentyp'),
  'sicher': ('Sicher', 'kuerzere Intervalle, mehr Wiederholungen'),
};

class LernprofilPage extends StatefulWidget {
  const LernprofilPage({required this.profil, required this.themen, super.key});

  /// Aktuelles Profil aus dem Cockpit (`lernprofil`).
  final Map<String, dynamic> profil;

  /// Sichtbare Themen (`themen` aus dem Cockpit): slug, title, area.
  final List<Map<String, dynamic>> themen;

  @override
  State<LernprofilPage> createState() => _LernprofilPageState();
}

class _LernprofilPageState extends State<LernprofilPage> {
  int? _semester;
  String? _ziel;
  int? _zielnote;
  late Set<String> _schwerpunkte;
  late Set<int> _ruhetage;
  late int _klausurWochentag;
  late bool _wochenklausur;
  late int _neueKarten;
  late String _sicherheitsniveau;
  late Set<String> _fokus;
  late Set<String> _pausiert;
  late List<Map<String, dynamic>> _eigeneDecks;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.profil;
    _semester = p['semester'] as int?;
    _ziel = p['ziel'] as String?;
    _zielnote = p['zielnote'] as int?;
    _schwerpunkte = _stringSet(p['schwerpunkte']);
    _ruhetage = _intSet(p['ruhetage']);
    _klausurWochentag = p['klausur_wochentag'] as int? ?? 5;
    _wochenklausur = p['wochenklausur'] as bool? ?? true;
    _neueKarten = p['neue_karten_pro_tag'] as int? ?? 10;
    _sicherheitsniveau = p['sicherheitsniveau'] as String? ?? 'standard';
    _fokus = _stringSet(p['themen_fokus']);
    _pausiert = _stringSet(p['themen_pausiert']);
    _eigeneDecks = [
      for (final d in (p['eigene_decks'] as List? ?? const []))
        if (d is Map) Map<String, dynamic>.from(d),
    ];
  }

  Map<String, dynamic> get _payload => {
        'semester': _semester,
        'ziel': _ziel,
        'zielnote': _zielnote,
        'schwerpunkte': _schwerpunkte.toList(),
        'ruhetage': _ruhetage.toList()..sort(),
        'klausur_wochentag': _klausurWochentag,
        'wochenklausur': _wochenklausur,
        'neue_karten_pro_tag': _neueKarten,
        'sicherheitsniveau': _sicherheitsniveau,
        'themen_fokus': _fokus.toList(),
        'themen_pausiert': _pausiert.toList(),
        'eigene_decks': _eigeneDecks,
      };

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final app = AppScope.of(context);
    final ok = await app.saveLernprofil(_payload);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = app.error ?? 'Speichern fehlgeschlagen.');
    }
  }

  Future<void> _neuesDeck() async {
    final deck = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DeckDialog(themen: widget.themen, vergeben: {
        for (final d in _eigeneDecks) d['slug'] as String,
      }),
    );
    if (deck != null && mounted) setState(() => _eigeneDecks.add(deck));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lernprofil')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            Text(
              'Jede Einstellung hier veraendert, was die App dir vorlegt: welche Karten '
              'zuerst kommen, wie oft du wiederholst, wie der Plan deine Woche einteilt '
              'und was der naechste Schritt ist.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.lg),
            _section(theme, 'Wo stehst du?'),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Fachsemester'),
              child: DropdownButton<int?>(
                key: const ValueKey('semester'),
                isExpanded: true,
                underline: const SizedBox.shrink(),
                value: _semester,
                hint: const Text('Keine Angabe'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Keine Angabe')),
                  for (var s = 1; s <= 12; s++)
                    DropdownMenuItem<int?>(value: s, child: Text('$s. Semester')),
                ],
                onChanged: (v) => setState(() => _semester = v),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text('Ziel', style: theme.textTheme.titleSmall),
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.xs,
              children: [
                for (final e in _ziele.entries)
                  SubsumoChip.filter(
                    label: e.value,
                    selected: _ziel == e.key,
                    onSelected: (on) => setState(() => _ziel = on ? e.key : null),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Zielnote setzen'),
              subtitle: Text(
                _zielnote == null
                    ? 'Kein Punktziel - die Examensreife bleibt eine Beschreibung, keine Prognose.'
                    : 'Ziel: $_zielnote Punkte (JAP-Skala)',
              ),
              value: _zielnote != null,
              onChanged: (on) => setState(() => _zielnote = on ? 9 : null),
            ),
            if (_zielnote != null)
              Slider(
                value: _zielnote!.toDouble(),
                min: 4,
                max: 18,
                divisions: 14,
                label: '$_zielnote Punkte',
                onChanged: (v) => setState(() => _zielnote = v.round()),
              ),
            const SizedBox(height: Spacing.lg),
            _section(theme, 'Schwerpunkte'),
            Text(
              'Rechtsgebiete, die im Stapel und im Plan schwerer wiegen (Faktor 1,25).',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (final e in _areaLabels.entries)
                  SubsumoChip.filter(
                    label: e.value,
                    selected: _schwerpunkte.contains(e.key),
                    onSelected: (on) => setState(
                      () => on ? _schwerpunkte.add(e.key) : _schwerpunkte.remove(e.key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            _section(theme, 'Rhythmus'),
            Text('Ruhetage (kein Lernpensum im Plan)', style: theme.textTheme.bodySmall),
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (var i = 0; i < 7; i++)
                  SubsumoChip.filter(
                    label: _wochentage[i],
                    selected: _ruhetage.contains(i),
                    onSelected: (on) => setState(() {
                      if (on && _ruhetage.length >= 6) return;
                      on ? _ruhetage.add(i) : _ruhetage.remove(i);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Woechentliche Klausur unter Examensbedingungen'),
              subtitle: const Text('Ab der Vertiefungsphase ein fester Klausurtag pro Woche.'),
              value: _wochenklausur,
              onChanged: (v) => setState(() => _wochenklausur = v),
            ),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Klausurtag'),
              child: DropdownButton<int>(
                key: const ValueKey('klausurtag'),
                isExpanded: true,
                underline: const SizedBox.shrink(),
                value: _klausurWochentag,
                items: [
                  for (var i = 0; i < 7; i++)
                    DropdownMenuItem<int>(value: i, child: Text(_wochentage[i])),
                ],
                onChanged: (v) => setState(() => _klausurWochentag = v ?? 5),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text('Neue Karten pro Tag: $_neueKarten', style: theme.textTheme.bodyMedium),
            Slider(
              value: _neueKarten.toDouble(),
              min: 0,
              max: 30,
              divisions: 30,
              label: '$_neueKarten',
              onChanged: (v) => setState(() => _neueKarten = v.round()),
            ),
            const SizedBox(height: Spacing.lg),
            _section(theme, 'Gedaechtnis'),
            Text(
              'Wie sicher sollen Karten sitzen? Verschiebt die Ziel-Retention der '
              'Wiederholungsplanung um vier Prozentpunkte nach unten oder oben.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.sm),
            SegmentedButton<String>(
              segments: [
                for (final e in _sicherheitsniveaus.entries)
                  ButtonSegment(value: e.key, label: Text(e.value.$1)),
              ],
              selected: {_sicherheitsniveau},
              onSelectionChanged: (s) => setState(() => _sicherheitsniveau = s.first),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              _sicherheitsniveaus[_sicherheitsniveau]?.$2 ?? '',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.lg),
            _section(theme, 'Themen: Fokus und Pause'),
            Text(
              'Fokus zieht ein Thema im Stapel und im Plan nach vorn (Faktor 1,5). Pause '
              'nimmt es komplett heraus - fuer Stoff, den du anderswo abgedeckt hast.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.xs),
            for (final area in _areaLabels.keys)
              _ThemenAbschnitt(
                titel: _areaLabels[area]!,
                themen: widget.themen.where((t) => t['area'] == area).toList(),
                fokus: _fokus,
                pausiert: _pausiert,
                onChanged: () => setState(() {}),
              ),
            const SizedBox(height: Spacing.lg),
            _section(theme, 'Eigene Decks'),
            Text(
              'Eine eigene Themenauswahl, z. B. fuer die naechste Vorlesungsklausur - '
              'lernbar wie jedes Kurs-Deck.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.xs),
            for (final deck in _eigeneDecks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.style_outlined, color: theme.colorScheme.onSurfaceVariant),
                title: Text(deck['title'] as String),
                subtitle: Text('${(deck['topic_slugs'] as List).length} Themen'),
                trailing: IconButton(
                  tooltip: 'Deck entfernen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _eigeneDecks.remove(deck)),
                ),
              ),
            SubsumoButton.secondary(
              label: 'Neues Deck',
              icon: Icons.add,
              onPressed: _eigeneDecks.length >= 20 ? null : _neuesDeck,
            ),
            if (_error != null) ...[
              const SizedBox(height: Spacing.md),
              SubsumoFeedbackBlock(message: _error!, severity: FeedbackSeverity.negative),
            ],
            const SizedBox(height: Spacing.xl),
            SubsumoButton.primary(
              label: _busy ? 'Bitte warten ...' : 'Lernprofil speichern',
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: Spacing.xl),
          ],
        ),
      ),
    );
  }

  static Widget _section(ThemeData theme, String titel) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: Text(titel, style: theme.textTheme.titleMedium),
      );
}

class _ThemenAbschnitt extends StatelessWidget {
  const _ThemenAbschnitt({
    required this.titel,
    required this.themen,
    required this.fokus,
    required this.pausiert,
    required this.onChanged,
  });

  final String titel;
  final List<Map<String, dynamic>> themen;
  final Set<String> fokus;
  final Set<String> pausiert;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markiert = themen.where((t) => fokus.contains(t['slug']) || pausiert.contains(t['slug']));
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      title: Text(titel, style: theme.textTheme.titleSmall),
      subtitle: Text(
        '${themen.length} Themen  ·  ${markiert.length} markiert',
        style: theme.textTheme.bodySmall,
      ),
      children: [
        for (final t in themen)
          Row(
            children: [
              Expanded(child: Text(t['title'] as String, style: theme.textTheme.bodyMedium)),
              IconButton(
                tooltip: 'Fokus: ${t['title']}',
                isSelected: fokus.contains(t['slug']),
                icon: const Icon(Icons.center_focus_weak_outlined),
                selectedIcon: const Icon(Icons.center_focus_strong_outlined),
                onPressed: () {
                  final slug = t['slug'] as String;
                  if (!fokus.remove(slug)) {
                    fokus.add(slug);
                    pausiert.remove(slug);
                  }
                  onChanged();
                },
              ),
              IconButton(
                tooltip: 'Pause: ${t['title']}',
                isSelected: pausiert.contains(t['slug']),
                icon: const Icon(Icons.pause_circle_outline),
                selectedIcon: const Icon(Icons.pause_circle_filled_outlined),
                onPressed: () {
                  final slug = t['slug'] as String;
                  if (!pausiert.remove(slug)) {
                    pausiert.add(slug);
                    fokus.remove(slug);
                  }
                  onChanged();
                },
              ),
            ],
          ),
      ],
    );
  }
}

/// Dialog fuer ein neues eigenes Deck: Titel plus Themenauswahl.
class _DeckDialog extends StatefulWidget {
  const _DeckDialog({required this.themen, required this.vergeben});

  final List<Map<String, dynamic>> themen;
  final Set<String> vergeben;

  @override
  State<_DeckDialog> createState() => _DeckDialogState();
}

class _DeckDialogState extends State<_DeckDialog> {
  final _titel = TextEditingController();
  final Set<String> _auswahl = {};
  String? _fehler;

  @override
  void dispose() {
    _titel.dispose();
    super.dispose();
  }

  void _anlegen() {
    final titel = _titel.text.trim();
    if (titel.isEmpty) {
      setState(() => _fehler = 'Bitte einen Titel angeben.');
      return;
    }
    if (_auswahl.isEmpty) {
      setState(() => _fehler = 'Mindestens ein Thema auswaehlen.');
      return;
    }
    var slug = 'mein-${slugify(titel)}';
    var n = 2;
    while (widget.vergeben.contains(slug)) {
      slug = 'mein-${slugify(titel)}-$n';
      n++;
    }
    Navigator.of(context).pop({
      'slug': slug,
      'title': titel,
      'topic_slugs': _auswahl.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neues Deck'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SubsumoTextField(label: 'Titel', controller: _titel),
            const SizedBox(height: Spacing.sm),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in widget.themen)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(t['title'] as String),
                      value: _auswahl.contains(t['slug']),
                      onChanged: (on) => setState(() {
                        on == true ? _auswahl.add(t['slug'] as String) : _auswahl.remove(t['slug']);
                      }),
                    ),
                ],
              ),
            ),
            if (_fehler != null) ...[
              const SizedBox(height: Spacing.sm),
              SubsumoFeedbackBlock(message: _fehler!, severity: FeedbackSeverity.negative),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        FilledButton(onPressed: _anlegen, child: const Text('Deck anlegen')),
      ],
    );
  }
}

/// `Mein BGB AT (Klausur)` -> `bgb-at-klausur`; passt zum Server-Muster
/// `^mein-[a-z0-9-]{1,60}$`.
String slugify(String text) {
  final lower = text
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss');
  final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  final slug = cleaned.isEmpty ? 'deck' : cleaned;
  return slug.length > 60 ? slug.substring(0, 60).replaceAll(RegExp(r'-+$'), '') : slug;
}

Set<String> _stringSet(Object? value) =>
    value is List ? {for (final v in value) '$v'} : <String>{};

Set<int> _intSet(Object? value) =>
    value is List ? {for (final v in value) if (v is int) v} : <int>{};
