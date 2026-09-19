import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../design/design.dart';
import 'legal_docs.dart';
import 'public_scaffold.dart';

/// Rechtstexte-Seiten (`/rechtliches/:slug`), oeffentlich ohne Login
/// erreichbar (Abnahme SUB-108/SUB-111). Rendert unveraendert den Inhalt der
/// jeweiligen `docs/legal/*.md`-Datei aus SUB-85 - keine redaktionelle
/// Freiheit, da die Texte rechtlich abgestimmt sind (siehe Abnahme SUB-111).
class PublicLegalPage extends StatelessWidget {
  const PublicLegalPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final doc = legalDocForSlug(slug);
    return PublicScaffold(
      child: doc == null ? _UnknownLegalSlug(slug: slug) : _LegalDocBody(doc: doc),
    );
  }
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
        return MarkdownBody(data: snapshot.data!, selectable: true);
      },
    );
  }
}
