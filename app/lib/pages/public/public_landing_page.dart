import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import 'public_scaffold.dart';

/// Platzhalter fuer die Startseite (`/`), oeffentlich ohne Login erreichbar.
/// Der eigentliche Landing-Page-Inhalt (Text aus SUB-88) folgt in einem
/// eigenen Kind-Issue von SUB-104 - dieses Geruest liefert nur die Route.
class PublicLandingPage extends StatelessWidget {
  const PublicLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subsumo', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: Spacing.xs),
          Text(
            'Jura lernen vom ersten Semester bis zum Examen.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Spacing.xl),
          SubsumoButton.primary(
            label: 'Preise ansehen',
            onPressed: () => context.go('/preise'),
          ),
          const SizedBox(height: Spacing.md),
          SubsumoButton.secondary(
            label: 'Anmelden',
            onPressed: () => context.go('/app'),
          ),
        ],
      ),
    );
  }
}
