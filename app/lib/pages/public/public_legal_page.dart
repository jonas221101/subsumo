import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../api.dart' show kBetaMode;
import '../../design/design.dart';
import 'legal_docs.dart';
import 'public_scaffold.dart';

/// Rechtstexte-Seiten (`/rechtliches/:slug`), oeffentlich ohne Login
/// erreichbar (Abnahme SUB-108/SUB-111). Rendert unveraendert den Inhalt der
/// jeweiligen `docs/legal/*.md`-Datei aus SUB-85 - keine redaktionelle
/// Freiheit, da die Texte rechtlich abgestimmt sind (siehe Abnahme SUB-111).
class PublicLegalPage extends StatelessWidget {
  const PublicLegalPage({required this.slug, this.betaMode = kBetaMode, super.key});

  final String slug;

  /// Im Test-Zugang ([kBetaMode]) erscheinen statt der Entwuerfe nur
  /// ehrliche "Privater Testzugang"-Seiten. Ueberschreibbar fuer Tests.
  final bool betaMode;

  @override
  Widget build(BuildContext context) {
    final doc = legalDocForSlug(slug);
    return PublicScaffold(
      child: SubsumoSection(
        child: doc == null
            ? _UnknownLegalSlug(slug: slug)
            : betaMode
                ? _BetaLegalBody(doc: doc)
                : _LegalDocBody(doc: doc),
      ),
    );
  }
}

const betaDatenschutzText =
    'Gespeichert werden nur: deine E-Mail-Adresse und ein Passwort-Hash für den Login, '
    'dein Lernfortschritt, deine Lösungen und dein Feedback aus dem Feedback-Button. '
    'Die Daten liegen auf einem Server in Deutschland und werden nicht an Dritte '
    'weitergegeben; es gibt keine Tracking- oder Werbedienste. Eine KI-Auswertung '
    'findet nicht statt. Auf Wunsch werden deine Daten vollständig gelöscht – sag '
    'einfach über den Feedback-Button Bescheid.';

class _BetaLegalBody extends StatelessWidget {
  const _BetaLegalBody({required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Privater Testzugang', style: theme.textTheme.headlineMedium),
        const SizedBox(height: Spacing.md),
        Text(
          'Dies ist ein geschlossener, nicht öffentlicher Testzugang für einzelne '
          'eingeladene Testerinnen und Tester. Ein öffentliches Angebot besteht nicht. '
          'Impressum, Datenschutzerklärung und Nutzungsbedingungen werden vor dem '
          'öffentlichen Start veröffentlicht.',
          style: body,
        ),
        if (doc.slug == 'datenschutz') ...[
          const SizedBox(height: Spacing.md),
          Text('Datenschutz', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.xs),
          Text(betaDatenschutzText, style: body),
        ],
        const SizedBox(height: Spacing.md),
        Text('Kontakt', style: theme.textTheme.titleMedium),
        const SizedBox(height: Spacing.xs),
        Text('Fragen und Wünsche bitte über den Feedback-Button in der App.', style: body),
      ],
    );
  }
}

/// Entfernt interne Verweise (docs/..., SUB-nnn) aus dem sichtbaren Text.
String bereinigeInterneVerweise(String md) {
  var t = md;
  t = t.replaceAll(RegExp(r'\[[^\]]*SUB-\d+[^\]]*\]\([^)]*\)'), '');
  t = t.replaceAll(
    RegExp(r'`?(?:\.\./)?docs/[\w./-]+`?(?:\s+Abschnitt\s+[\w./„“"-]+)?'),
    '',
  );
  t = t.replaceAll(RegExp(r'SUB-\d+(?:-Interaktion)?'), '');
  t = t.replaceAll(RegExp(r'\(\s*[,;]?\s*\)'), '');
  t = t.replaceAll(RegExp(r'[ \t]+([,.;:])'), r'$1');
  t = t.replaceAll(RegExp(r'(?<=\S)[ \t]{2,}'), ' ');
  return t;
}

class _UnknownLegalSlug extends StatelessWidget {
  const _UnknownLegalSlug({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rechtliches', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: Spacing.xs),
        Text(
          'Unbekannter Rechtstext "$slug".',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _LegalDocBody extends StatelessWidget {
  const _LegalDocBody({required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString(doc.assetPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Text(
            '${doc.title} konnte nicht geladen werden.',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        return MarkdownBody(data: bereinigeInterneVerweise(snapshot.data!), selectable: true);
      },
    );
  }
}
