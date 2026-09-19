/// Rechtstexte-Slugs (`/rechtliches/:slug`) mit Titel und Quelldatei.
///
/// Einzige Quelle der Inhalte bleiben die Entwuerfe in `docs/legal/` (SUB-85);
/// [PublicLegalPage] laedt diese Dateien zur Laufzeit als Asset (siehe
/// `assets:` in pubspec.yaml), statt ihren Inhalt zu kopieren. Diese Liste
/// treibt sowohl die Rechtstexte-Seite als auch den gemeinsamen Footer
/// (SUB-111).
class LegalDoc {
  const LegalDoc({required this.slug, required this.title, required this.assetPath});

  final String slug;
  final String title;
  final String assetPath;
}

const legalDocs = [
  LegalDoc(slug: 'impressum', title: 'Impressum', assetPath: '../docs/legal/01-impressum.md'),
  LegalDoc(slug: 'agb', title: 'AGB', assetPath: '../docs/legal/02-agb.md'),
  LegalDoc(
    slug: 'datenschutz',
    title: 'Datenschutzerklaerung',
    assetPath: '../docs/legal/03-datenschutzerklaerung.md',
  ),
  LegalDoc(
    slug: 'widerruf',
    title: 'Widerrufsbelehrung',
    assetPath: '../docs/legal/04-widerrufsbelehrung.md',
  ),
  LegalDoc(
    slug: 'cookies',
    title: 'Cookie-Hinweis',
    assetPath: '../docs/legal/05-cookie-hinweis.md',
  ),
];

LegalDoc? legalDocForSlug(String slug) {
  for (final doc in legalDocs) {
    if (doc.slug == slug) return doc;
  }
  return null;
}
