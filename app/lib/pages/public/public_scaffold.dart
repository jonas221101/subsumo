import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import '../../theme.dart';

/// Gemeinsames Geruest fuer oeffentliche Seiten (Landing, Preise, Rechtstexte,
/// siehe SUB-108). Zeigt eine schlichte Kopfzeile mit Login-CTA zur
/// eingeloggten App unter `/app` - der bisherige Login-Fluss bleibt dadurch
/// unveraendert erreichbar, siehe [HomeShell] in main.dart.
class PublicScaffold extends StatelessWidget {
  const PublicScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subsumo'),
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
            child: child,
          ),
        ),
      ),
    );
  }
}
