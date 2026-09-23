import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import '../../state.dart';
import 'public_scaffold.dart';
import 'subsumo_brand_motif.dart';

/// Ein einziger Breakpoint fuer alle Zweispalten-/Mehrspalten-Wechsel auf
/// oeffentlichen Flaechen (SUB-241, docs/25 Abschnitt 3) - identisch mit dem
/// bestehenden `HomeShell`-Breakpoint (`main.dart:135`,
/// `NavigationBar` -> `NavigationRail`). Bewusst kein zweiter, auf die
/// Landingpage optimierter Wert.
const double publicSectionBreakpoint = 800;

bool _isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= publicSectionBreakpoint;

/// Startseite (`/`), oeffentlich ohne Login erreichbar (SUB-108). Enthaelt
/// alle 9 Sektionen aus docs/21-landing-preisseite-launchtext.md Abschnitt 2.2
/// wortgleich - Fassung A (ohne KI-Korrektur), da der Stichtagsentscheid
/// SUB-135 noch aussteht (siehe docs/21 Abschnitt 2.3). Jede Sektion ist ein
/// eigenes, randloses `SubsumoSection`-Band (SUB-227/SUB-228/SUB-241,
/// docs/25 Abschnitt 3) statt einer durchgehend weissen Spalte - Sektion 9
/// (Footer) liefert [PublicScaffold] bereits gemeinsam mit der Preisseite
/// (SUB-111) in einem eigenen `brandDark`-Band.
class PublicLandingPage extends StatelessWidget {
  const PublicLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PublicScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroSection(),
          _FuerWenSection(),
          _WasDuBekommstSection(),
          _WieEsFunktioniertSection(),
          _EhrlichUeberDenUmfangSection(),
          _RechtsgebieteSection(),
          _PreisTeaserSection(),
          _FaqSection(),
        ],
      ),
    );
  }
}

/// 1. Hero. Vollbreites Band, Verlauf `brand700` -> `brand900` (Brief
/// Abschnitt 3.1). >=800px: zweispaltig (Text links, Motiv rechts), <800px:
/// einspaltig gestapelt, Motiv entfaellt (Kontrastrisiko ueber Text
/// vermeiden). Primaer-/Sekundaer-CTA bekommen auf dem dunklen Band ein
/// lokales Theme (weisse Fuellung/Kontur) - der Verlauf ist sonst zu nah an
/// `primary` (`brand700`), um einen gefuellten Button erkennbar abzusetzen.
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).extension<SubsumoTypography>()!;
    final wide = _isWide(context);

    final headline = Text(
      'Karteikarten, Schemata und Fälle für dein Jurastudium — mit '
      'ehrlichem Feedback zum Aufbau deiner Gutachten.',
      style: (wide ? typography.heroLarge : typography.heroSmall).copyWith(color: Colors.white),
    );
    final subheadline = Text(
      'Subsumo ist gerade gestartet: 180 geprüfte Karten, 8+ Schemata und '
      '6+ geführte Fälle über Zivilrecht, Strafrecht und Öffentliches '
      'Recht — und wächst laufend weiter. Zum Gründerpreis ab 3,99 '
      '€/Monat, dauerhaft garantiert.',
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
    );
    final ctas = Theme(
      data: Theme.of(context).copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: SubsumoPalette.brand700,
          ),
        ),
        outlinedButtonTheme: const OutlinedButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(Colors.white),
            side: WidgetStatePropertyAll(BorderSide(color: Colors.white)),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SubsumoButton.primary(
            label: 'Kostenlos starten',
            onPressed: () => context.go('/app'),
          ),
          const SizedBox(height: Spacing.md),
          SubsumoButton.secondary(
            label: 'Preise ansehen',
            onPressed: () => context.go('/preise'),
          ),
        ],
      ),
    );

    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        headline,
        const SizedBox(height: Spacing.md),
        subheadline,
        const SizedBox(height: Spacing.xl),
        ctas,
      ],
    );

    return SubsumoSection(
      background: SubsumoSectionBackground.heroGradient,
      maxContentWidth: wide ? 1100 : 760,
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: textColumn),
                const SizedBox(width: Spacing.xxxl),
                const Expanded(
                  flex: 2,
                  child: SubsumoBrandMotif(color: Colors.white),
                ),
              ],
            )
          : textColumn,
    );
  }
}

/// 2. Für wen. Flaechenfarbe `surface0`, einspaltig, zentriert - etwas
/// groessere Textrolle (`titleMedium` statt `bodyMedium`), damit der eine
/// Satz nicht wie eine Fussnote wirkt (Brief Abschnitt 3.2).
class _FuerWenSection extends StatelessWidget {
  const _FuerWenSection();

  @override
  Widget build(BuildContext context) {
    return SubsumoSection(
      child: Text(
        'Für Jurastudierende ab dem ersten Semester, die nicht nur lesen, '
        'sondern wiederholen, anwenden und ihre eigenen Lösungen überprüfen '
        'wollen.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

/// 3. Was du heute bekommst. Flaechenfarbe `surface1`. >=800px: 2x2-Grid
/// (Icon in Akzent-Kreisflaeche + Ueberschrift + Text), <800px: einspaltig
/// gestapelt (Brief Abschnitt 3.3). Der Abgrenzungssatz zum Struktur-Check
/// bleibt ein eigener, nicht im Grid versteckter Absatz darunter.
class _WasDuBekommstSection extends StatelessWidget {
  const _WasDuBekommstSection();

  static const _items = [
    (
      icon: Icons.style_outlined,
      heading: 'Karteikarten',
      text: 'Karteikarten mit automatischer Wiederholung (FSRS-Verfahren) — die App '
          'entscheidet, wann eine Karte wieder fällig ist, du entscheidest, was '
          'du lernst.',
    ),
    (
      icon: Icons.list_alt_outlined,
      heading: 'Schemata',
      text: 'Prüfungsschemata zum Nachschlagen (Pro: zusätzlich als '
          'Reihenfolge-Drill).',
    ),
    (
      icon: Icons.task_outlined,
      heading: 'Geführte Fälle',
      text: 'Geführte Übungsfälle mit hinterlegtem Erwartungshorizont.',
    ),
    (
      icon: Icons.fact_check_outlined,
      heading: 'Struktur-Check',
      text: 'Struktur-Check für deine Gutachten: Lade deine eigene Lösung zu einem '
          'Übungsfall hoch und bekommst automatisiert Rückmeldung zu Aufbau '
          'und Stil.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final wide = _isWide(context);

    return SubsumoSection(
      background: SubsumoSectionBackground.surface1,
      maxContentWidth: wide ? 900 : 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Was du heute bekommst', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: Spacing.lg),
          wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in _items.sublist(0, 2))
                      Expanded(child: _BekommstTile(item: item)),
                  ],
                )
              : Column(children: [for (final item in _items.sublist(0, 2)) _BekommstTile(item: item)]),
          if (wide) const SizedBox(height: Spacing.lg),
          wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in _items.sublist(2, 4))
                      Expanded(child: _BekommstTile(item: item)),
                  ],
                )
              : Column(children: [for (final item in _items.sublist(2, 4)) _BekommstTile(item: item)]),
          const SizedBox(height: Spacing.md),
          Text(
            'Was der Struktur-Check ist — und was nicht: Lernhilfe, keine '
            'Rechtsberatung, keine Note. Er ist ein regelbasierter '
            '(heuristischer) Check gegen den in der Anwendung hinterlegten '
            'Erwartungshorizont deines Übungsfalls — kein Ersatz für eine '
            'Korrektur durch Lehrpersonal, keine Bewertung deiner Studien- '
            'oder Examensklausuren.',
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}

typedef _BekommstItem = ({IconData icon, String heading, String text});

class _BekommstTile extends StatelessWidget {
  const _BekommstTile({required this.item});

  final _BekommstItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<SubsumoColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg, right: Spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.accentWash,
            child: Icon(item.icon, size: 22, color: colors.accent),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.heading, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Spacing.xs),
                Text(item.text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 4. Wie es funktioniert. Flaechenfarbe `surface0`. >=800px: drei Schritte
/// horizontal mit verbindendem Pfeil, <800px: nummeriert gestapelt (Brief
/// Abschnitt 3.4).
class _WieEsFunktioniertSection extends StatelessWidget {
  const _WieEsFunktioniertSection();

  static const _steps = [
    'Konto anlegen, Rechtsgebiet wählen.',
    'Karten lernen, Schemata nachschlagen, Fälle bearbeiten.',
    'Eigene Lösung zum Struktur-Check hochladen und Rückmeldung bekommen.',
  ];

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final wide = _isWide(context);

    return SubsumoSection(
      maxContentWidth: wide ? 900 : 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Wie es funktioniert', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: Spacing.lg),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, step) in _steps.indexed) ...[
                  if (index > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.md),
                      child: Icon(Icons.arrow_forward_outlined, color: Theme.of(context).colorScheme.outline),
                    ),
                  Expanded(child: _StepTile(index: index, step: step)),
                ],
              ],
            )
          else
            for (final (index, step) in _steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${index + 1}.  ', style: bodyStyle),
                    Expanded(child: Text(step, style: bodyStyle)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.step});

  final int index;
  final String step;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<SubsumoColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.accentWash,
            child: Text(
              '${index + 1}',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: colors.accent),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(step, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// 5. Ehrlich über den Umfang. Eigene, abgesetzte Flaeche (`accentWash`,
/// Brief Abschnitt 3.5) - einspaltig, zentriert, kein weiteres visuelles
/// Element (auch nicht das Marken-Motiv) lenkt vom ehrlichen Ton ab.
class _EhrlichUeberDenUmfangSection extends StatelessWidget {
  const _EhrlichUeberDenUmfangSection();

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    return SubsumoSection(
      background: SubsumoSectionBackground.accentWash,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Ehrlich über den Umfang',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'Subsumo ist neu. Zum Start stehen 180 Karten, 8+ Schemata und 6+ '
            'geführte Fälle über drei Rechtsgebiete bereit — spürbar weniger '
            'als etablierte Anbieter mit tausenden Fällen. Das sagen wir '
            'offen, weil wir lieber jede Karte selbst prüfen, als früh eine '
            'Vollständigkeit zu behaupten, die es nicht gibt.',
            textAlign: TextAlign.center,
            style: bodyStyle,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'Deshalb der Gründerpreis: Wer jetzt einsteigt, sichert sich '
            'einen Preis, der niedriger bleibt, als der Umfang — und der '
            'Preis für neue Kund:innen — mit der Zeit wächst.',
            textAlign: TextAlign.center,
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}

/// 6. Die drei Rechtsgebiete. Flaechenfarbe `surface1`. >=800px: feste
/// 3-Spalten-Reihe, <800px: gestapelt (bisheriges `Wrap`-Verhalten). Jede
/// Karte bekommt einen schmalen, **kategorischen** Farbakzent oben (fest pro
/// Gebiet ueber `SubsumoColors.legalArea*`, Brief Abschnitt 3.6) - keine
/// Bewertung, nur Wiedererkennung. Themenbeispiele je Gebiet kommen vom
/// oeffentlichen `GET /v1/content/topics` (kein Login noetig). Schlaegt der
/// Abruf fehl (kein Netz o.ae.), zeigt die Sektion nur den Einleitungstext
/// ohne Themenbeispiele - kein Fehlerzustand fuer die Landing Page.
class _RechtsgebieteSection extends StatefulWidget {
  const _RechtsgebieteSection();

  @override
  State<_RechtsgebieteSection> createState() => _RechtsgebieteSectionState();
}

class _RechtsgebieteSectionState extends State<_RechtsgebieteSection> {
  Future<List<Map<String, dynamic>>>? _topics;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _topics ??= _loadTopics();
  }

  Future<List<Map<String, dynamic>>> _loadTopics() async {
    final api = AppScope.of(context).api;
    try {
      return await api.publicTopics();
    } on Exception {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<SubsumoColors>()!;
    final wide = _isWide(context);
    // Feste, wertunabhaengige Zuordnung Gebiet -> Akzentton (SUB-241) - keine
    // Ableitung aus einem Lernstand/Score, siehe Klassendoku.
    final areas = [
      ('zivilrecht', 'Zivilrecht', colors.legalAreaZivilrecht),
      ('strafrecht', 'Strafrecht', colors.legalAreaStrafrecht),
      ('oeffentliches-recht', 'Öffentliches Recht', colors.legalAreaOeffentlichesRecht),
    ];

    return SubsumoSection(
      background: SubsumoSectionBackground.surface1,
      maxContentWidth: wide ? 900 : 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Die drei Rechtsgebiete', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),
          Text(
            'Zivilrecht · Strafrecht · Öffentliches Recht — Karten, Schemata '
            'und Fälle zu den Themen, die in der Pflichtfachprüfung zählen.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Spacing.lg),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _topics,
            builder: (context, snapshot) {
              final topics = snapshot.data ?? const [];
              final tiles = [
                for (final (area, label, accent) in areas)
                  _RechtsgebietTile(
                    label: label,
                    accent: accent,
                    topicTitles: topics
                        .where((topic) => topic['area'] == area)
                        .take(3)
                        .map((topic) => topic['title'] as String)
                        .toList(),
                  ),
              ];
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final tile in tiles)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: Spacing.md),
                              child: tile,
                            ),
                          ),
                      ],
                    )
                  : Wrap(spacing: Spacing.md, runSpacing: Spacing.md, children: tiles);
            },
          ),
        ],
      ),
    );
  }
}

class _RechtsgebietTile extends StatelessWidget {
  const _RechtsgebietTile({required this.label, required this.accent, required this.topicTitles});

  final String label;
  final Color accent;
  final List<String> topicTitles;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.pill)),
            ),
          ),
          SubsumoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                if (topicTitles.isNotEmpty) ...[
                  const SizedBox(height: Spacing.sm),
                  Wrap(
                    spacing: Spacing.xs,
                    runSpacing: Spacing.xs,
                    children: [
                      for (final title in topicTitles) SubsumoChip(label: title),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 7. Preis-Teaser. Flaechenfarbe `surface0`. >=800px: Free-/Pro-Karten
/// nebeneinander, <800px: gestapelt (Brief Abschnitt 3.7). Die Pro-Karte
/// hebt sich ueber einen 2px-Akzent-Rahmen und `surface2` statt `surface1`
/// ab - keine neue Elevation-Stufe.
class _PreisTeaserSection extends StatelessWidget {
  const _PreisTeaserSection();

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    const freeCard = _PreisCard(
      title: 'Free',
      text: 'Free: 20 fällige Karten/Tag in einem Rechtsgebiet, 2 geführte '
          'Fälle, 3 Struktur-Checks/Woche.',
      highlighted: false,
    );
    const proCard = _PreisCard(
      title: 'Pro (Gründerpreis)',
      text: 'Pro (Gründerpreis): alle drei Rechtsgebiete, unbegrenzt Karten, '
          'Fälle und Struktur-Checks — 3,99 €/Monat oder 39 €/Jahr, Preis '
          'bleibt dir erhalten, auch wenn er für neue Kund:innen steigt.',
      highlighted: true,
    );

    return SubsumoSection(
      maxContentWidth: wide ? 900 : 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wide)
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: freeCard),
                SizedBox(width: Spacing.lg),
                Expanded(child: proCard),
              ],
            )
          else
            const Column(children: [freeCard, SizedBox(height: Spacing.md), proCard]),
          const SizedBox(height: Spacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: SubsumoButton.secondary(
              label: 'Alle Preise ansehen',
              onPressed: () => context.go('/preise'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreisCard extends StatelessWidget {
  const _PreisCard({required this.title, required this.text, required this.highlighted});

  final String title;
  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<SubsumoColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface2 = isDark ? SubsumoPalette.surface2Dark : SubsumoPalette.surface2Light;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: highlighted ? surface2 : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.md),
        border: highlighted ? Border.all(color: colors.accent, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          Text(text, style: bodyStyle),
        ],
      ),
    );
  }
}

/// 8. FAQ. Flaechenfarbe `surface1`. Akkordeon (`ExpansionTile`) statt drei
/// permanent sichtbaren Bloecken (Brief Abschnitt 3.8) - erste Frage
/// initial aufgeklappt, die uebrigen eingeklappt (Standard-`ExpansionTile`-
/// Verhalten: eingeklappte Antworten stehen nicht im Baum, bis
/// aufgeklappt wird - Tests klappen deshalb gezielt auf, bevor sie den
/// Antworttext pruefen). Fassung A (ohne KI-Korrektur) - siehe docs/21
/// Abschnitt 2.3, gilt bis der Stichtagsentscheid SUB-135 die Aktivierung
/// bestaetigt.
class _FaqSection extends StatelessWidget {
  const _FaqSection();

  static const _entries = [
    (
      'Ist das eine KI, die meine Klausur korrigiert?',
      'Nein. Der Struktur-Check ist heuristisch (regelbasiert) und vergibt '
          'keine Note. Eine KI-gestützte Korrektur ist nicht Teil des '
          'aktuellen Angebots.',
    ),
    (
      'Wie viele Karten gibt es wirklich?',
      'Zum Start 180 geprüfte Karten über drei Rechtsgebiete. Wir zeigen '
          'die aktuelle Zahl hier auf der Seite, nicht nur im '
          'Kleingedruckten.',
    ),
    (
      'Kann ich kündigen?',
      'Ja, jederzeit zum Ende der laufenden Laufzeit. Details in den AGB.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    return SubsumoSection(
      background: SubsumoSectionBackground.surface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FAQ', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),
          for (final (index, entry) in _entries.indexed)
            Material(
              type: MaterialType.transparency,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(entry.$1, style: Theme.of(context).textTheme.titleMedium),
                  initiallyExpanded: index == 0,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: Spacing.md),
                  expandedAlignment: Alignment.centerLeft,
                  children: [
                    Text(entry.$2, style: bodyStyle),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
