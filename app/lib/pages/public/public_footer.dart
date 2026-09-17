import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import 'legal_docs.dart';

/// Gemeinsamer Footer fuer alle oeffentlichen Seiten (Landing, Preise,
/// Rechtstexte selbst) - verlinkt konsistent alle fuenf Rechtstexte-Routen
/// (Abnahme SUB-111, Punkt 2). Sitzt in [PublicScaffold], damit Landing- und
/// Preisseite (die zwei anderen SUB-104-Kinder) ihn ohne eigenen Aufwand
/// mitbekommen.
class PublicFooter extends StatelessWidget {
  const PublicFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.xs,
            children: [
              for (final doc in legalDocs)
                _FooterLink(
                  label: doc.title,
                  path: '/rechtliches/${doc.slug}',
                  isCurrent: currentPath == '/rechtliches/${doc.slug}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.path, required this.isCurrent});

  final String label;
  final String path;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isCurrent ? null : () => context.go(path),
      child: Text(label),
    );
  }
}
