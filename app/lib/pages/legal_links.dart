import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/design.dart';
import 'public/legal_docs.dart';

/// Links zu Impressum, Datenschutz und AGB (oeffentliche Seiten
/// `/rechtliches/:slug`) fuer Konto-Screen und Login-Fusszeile. Ohne
/// GoRouter (Widget-Tests ohne Router) bleiben die Links sichtbar, tun aber
/// nichts.
class LegalLinks extends StatelessWidget {
  const LegalLinks({this.alignment = WrapAlignment.center, super.key});

  final WrapAlignment alignment;

  static const _slugs = ['impressum', 'datenschutz', 'agb'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      spacing: Spacing.sm,
      runSpacing: Spacing.xs,
      children: [
        for (final slug in _slugs)
          TextButton(
            onPressed: () => GoRouter.maybeOf(context)?.push('/rechtliches/$slug'),
            child: Text(legalDocForSlug(slug)?.title ?? slug),
          ),
      ],
    );
  }
}
