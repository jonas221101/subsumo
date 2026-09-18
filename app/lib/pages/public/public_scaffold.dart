import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import '../../theme.dart';
import 'public_footer.dart';

/// Gemeinsames Geruest fuer oeffentliche Seiten (Landing, Preise, Rechtstexte,
/// siehe SUB-108). Zeigt eine schlichte Kopfzeile mit Login-CTA zur
/// eingeloggten App unter `/app` - der bisherige Login-Fluss bleibt dadurch
/// unveraendert erreichbar, siehe [HomeShell] in main.dart. Der [PublicFooter]
/// verlinkt hier zentral alle Rechtstexte (SUB-111), damit Landing- und
/// Preisseite ihn automatisch mitbekommen.
class PublicScaffold extends StatelessWidget {
  const PublicScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SubsumoWordmark(accent: true),
        actions: [
          TextButton(
            onPressed: () => context.go('/app'),
            child: const Text('Anmelden'),
          ),
          const SizedBox(width: Spacing.sm),
        ],
      ),
      body: SingleChildScrollView(
        child: ReadableWidth(
          maxWidth: 720,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                child,
                const PublicFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
