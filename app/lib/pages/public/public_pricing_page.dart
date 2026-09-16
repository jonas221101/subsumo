import 'package:flutter/material.dart';

import '../../design/design.dart';
import 'public_scaffold.dart';

/// Platzhalter fuer die Preisseite (`/preise`), oeffentlich ohne Login
/// erreichbar (Abnahme SUB-108). Die eigentlichen Preis-Inhalte folgen in
/// einem eigenen Kind-Issue von SUB-104 - dieses Geruest liefert nur die Route.
class PublicPricingPage extends StatelessWidget {
  const PublicPricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preise', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: Spacing.xs),
          Text(
            'Die Preisseite wird in Kuerze mit den Tarifdetails befuellt.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
