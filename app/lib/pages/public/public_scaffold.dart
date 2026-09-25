import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/design.dart';
import 'public_footer.dart';

/// Gemeinsames Geruest fuer oeffentliche Seiten (Landing, Preise, Rechtstexte,
/// siehe SUB-108). Zeigt eine schlichte Kopfzeile mit Login-CTA zur
/// eingeloggten App unter `/app` - der bisherige Login-Fluss bleibt dadurch
/// unveraendert erreichbar, siehe [HomeShell] in main.dart. Der [PublicFooter]
/// verlinkt hier zentral alle Rechtstexte (SUB-111), damit Landing- und
/// Preisseite ihn automatisch mitbekommen.
///
/// Erzwingt seit SUB-241 keine pauschale `maxWidth` mehr fuer [child] - jede
/// Seite/Sektion begrenzt ihren eigenen Inhalt ueber [SubsumoSection]
/// (Brief Abschnitt 3, docs/25). Der Scaffold reicht nur noch AppBar, Footer
/// und die Fensterbreite durch. Der Footer sitzt in einem eigenen
/// `brandDark`-Band als dunkler Bookend-Kontrast zum Hero (Brief Abschnitt
/// 3.9) - Linktext braucht deshalb die helle, gegen `brand900` geprueften
/// Rolle (Weiss, 15.80:1, docs/11 Abschnitt 5) statt der Standard-Textfarbe.
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            child,
            SubsumoSection(
              background: SubsumoSectionBackground.brandDark,
              child: Theme(
                data: Theme.of(context).copyWith(
                  textButtonTheme: const TextButtonThemeData(
                    style: ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(Colors.white),
                    ),
                  ),
                  dividerColor: Colors.white24,
                ),
                child: const PublicFooter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
