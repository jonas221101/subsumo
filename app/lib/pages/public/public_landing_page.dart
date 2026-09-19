import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import '../../state.dart';
import 'public_scaffold.dart';

/// Startseite (`/`), oeffentlich ohne Login erreichbar (SUB-108). Enthaelt
/// alle 9 Sektionen aus docs/21-landing-preisseite-launchtext.md Abschnitt 2.2
/// wortgleich - Fassung A (ohne KI-Korrektur), da der Stichtagsentscheid
/// SUB-135 noch aussteht (siehe docs/21 Abschnitt 2.3). Sektion 9 (Footer)
/// liefert [PublicScaffold] bereits gemeinsam mit der Preisseite (SUB-111).
class PublicLandingPage extends StatelessWidget {
  const PublicLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PublicScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroSection(),
          _SectionSpacer(),
          _FuerWenSection(),
          _SectionSpacer(),
          _WasDuBekommstSection(),
          _SectionSpacer(),
          _WieEsFunktioniertSection(),
          _SectionSpacer(),
          _EhrlichUeberDenUmfangSection(),
          _SectionSpacer(),
          _RechtsgebieteSection(),
          _SectionSpacer(),
          _PreisTeaserSection(),
          _SectionSpacer(),
          _FaqSection(),
        ],
      ),
    );
  }
}

class _SectionSpacer extends StatelessWidget {
  const _SectionSpacer();

  @override
  Widget build(BuildContext context) => const SizedBox(height: Spacing.xxxl);
}

/// 1. Hero.
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Karteikarten, Schemata und Fälle für dein Jurastudium — mit '
          'ehrlichem Feedback zum Aufbau deiner Gutachten.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: Spacing.md),
        Text(
          'Subsumo ist gerade gestartet: 180 geprüfte Karten, 8+ Schemata und '
          '6+ geführte Fälle über Zivilrecht, Strafrecht und Öffentliches '
          'Recht — und wächst laufend weiter. Zum Gründerpreis ab 3,99 '
          '€/Monat, dauerhaft garantiert.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: Spacing.xl),
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
    );
  }
}

/// 2. Für wen.
class _FuerWenSection extends StatelessWidget {
  const _FuerWenSection();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Für Jurastudierende ab dem ersten Semester, die nicht nur lesen, '
      'sondern wiederholen, anwenden und ihre eigenen Lösungen überprüfen '
      'wollen.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

/// 3. Was du heute bekommst.
class _WasDuBekommstSection extends StatelessWidget {
  const _WasDuBekommstSection();

  static const _bullets = [
    'Karteikarten mit automatischer Wiederholung (FSRS-Verfahren) — die App '
        'entscheidet, wann eine Karte wieder fällig ist, du entscheidest, was '
        'du lernst.',
    'Prüfungsschemata zum Nachschlagen (Pro: zusätzlich als '
        'Reihenfolge-Drill).',
    'Geführte Übungsfälle mit hinterlegtem Erwartungshorizont.',
    'Struktur-Check für deine Gutachten: Lade deine eigene Lösung zu einem '
        'Übungsfall hoch und bekommst automatisiert Rückmeldung zu Aufbau '
        'und Stil.',
  ];

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Was du heute bekommst', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: Spacing.md),
        for (final bullet in _bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: bodyStyle),
                Expanded(child: Text(bullet, style: bodyStyle)),
              ],
            ),
          ),
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
    );
  }
}

/// 4. Wie es funktioniert.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Wie es funktioniert', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: Spacing.md),
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
    );
  }
}

/// 5. Ehrlich über den Umfang.
class _EhrlichUeberDenUmfangSection extends StatelessWidget {
  const _EhrlichUeberDenUmfangSection();

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ehrlich über den Umfang', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: Spacing.md),
        Text(
          'Subsumo ist neu. Zum Start stehen 180 Karten, 8+ Schemata und 6+ '
          'geführte Fälle über drei Rechtsgebiete bereit — spürbar weniger '
          'als etablierte Anbieter mit tausenden Fällen. Das sagen wir '
          'offen, weil wir lieber jede Karte selbst prüfen, als früh eine '
          'Vollständigkeit zu behaupten, die es nicht gibt.',
          style: bodyStyle,
        ),
        const SizedBox(height: Spacing.md),
        Text(
          'Deshalb der Gründerpreis: Wer jetzt einsteigt, sichert sich '
          'einen Preis, der niedriger bleibt, als der Umfang — und der '
          'Preis für neue Kund:innen — mit der Zeit wächst.',
          style: bodyStyle,
        ),
      ],
    );
  }
}

/// 6. Die drei Rechtsgebiete. Themenbeispiele je Gebiet kommen vom
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

  static const _areas = [
    ('zivilrecht', 'Zivilrecht'),
    ('strafrecht', 'Strafrecht'),
    ('oeffentliches-recht', 'Öffentliches Recht'),
  ];

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
    return Column(
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
            return Wrap(
              spacing: Spacing.md,
              runSpacing: Spacing.md,
              children: [
                for (final (area, label) in _areas)
                  _RechtsgebietTile(
                    label: label,
                    topicTitles: topics
                        .where((topic) => topic['area'] == area)
                        .take(3)
                        .map((topic) => topic['title'] as String)
                        .toList(),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RechtsgebietTile extends StatelessWidget {
  const _RechtsgebietTile({required this.label, required this.topicTitles});

  final String label;
  final List<String> topicTitles;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: SubsumoCard(
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
    );
  }
}

/// 7. Preis-Teaser.
class _PreisTeaserSection extends StatelessWidget {
  const _PreisTeaserSection();

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Free: 20 fällige Karten/Tag in einem Rechtsgebiet, 2 geführte '
          'Fälle, 3 Struktur-Checks/Woche.',
          style: bodyStyle,
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          'Pro (Gründerpreis): alle drei Rechtsgebiete, unbegrenzt Karten, '
          'Fälle und Struktur-Checks — 3,99 €/Monat oder 39 €/Jahr, Preis '
          'bleibt dir erhalten, auch wenn er für neue Kund:innen steigt.',
          style: bodyStyle,
        ),
        const SizedBox(height: Spacing.lg),
        SubsumoButton.secondary(
          label: 'Alle Preise ansehen',
          onPressed: () => context.go('/preise'),
        ),
      ],
    );
  }
}

/// 8. FAQ. Fassung A (ohne KI-Korrektur) - siehe docs/21 Abschnitt 2.3, gilt
/// bis der Stichtagsentscheid SUB-135 die Aktivierung bestaetigt.
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
    final questionStyle = Theme.of(context).textTheme.titleMedium;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FAQ', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: Spacing.md),
        for (final (question, answer) in _entries)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question, style: questionStyle),
                const SizedBox(height: Spacing.xs),
                Text(answer, style: bodyStyle),
              ],
            ),
          ),
      ],
    );
  }
}
