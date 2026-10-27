import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import 'examen_page.dart' show openLernprofilFromAnywhere;

/// Dezenter Hinweis in Schemata- und Faelle-Tab, solange kein Bundesland im
/// Profil steht (das Cockpit ist geladen, aber `profil.bundesland` leer).
/// Ohne geladenes Cockpit bleibt er aus - kein Hinweis auf Verdacht.
class BundeslandHint extends StatelessWidget {
  const BundeslandHint({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final profil = app.examenCockpit?['profil'];
    if (profil is! Map || profil['bundesland'] != null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Landesrecht wird angezeigt, sobald du dein Bundesland einstellst. ',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          InkWell(
            onTap: () => openLernprofilFromAnywhere(context),
            child: Text(
              'Bundesland einstellen',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
