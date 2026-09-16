import 'package:flutter/material.dart';

import '../../design/design.dart';
import 'public_scaffold.dart';

/// Titel je Rechtstexte-Slug (`/rechtliches/:slug`), passend zu den
/// Entwuerfen in `docs/legal/` (SUB-85). Ein unbekannter Slug faellt auf
/// einen generischen Titel zurueck statt auf einen 404.
const _legalTitles = {
  'impressum': 'Impressum',
  'agb': 'AGB',
  'datenschutz': 'Datenschutzerklaerung',
  'widerruf': 'Widerrufsbelehrung',
  'cookies': 'Cookie-Hinweis',
};

/// Platzhalter fuer die Rechtstexte-Seiten (`/rechtliches/:slug`), oeffentlich
/// ohne Login erreichbar (Abnahme SUB-108). Die eigentlichen Rechtstexte
/// (Entwuerfe bereits in docs/legal/, siehe SUB-85) folgen in einem eigenen
/// Kind-Issue von SUB-104 - dieses Geruest liefert nur die Route.
class PublicLegalPage extends StatelessWidget {
  const PublicLegalPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final title = _legalTitles[slug] ?? 'Rechtliches';
    return PublicScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: Spacing.xs),
          Text(
            'Dieser Rechtstext wird in Kuerze befuellt.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
