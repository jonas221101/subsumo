import 'package:flutter/material.dart';

import '../design/design.dart';
import 'tool_spec_labeling.dart';

/// Dauerhafte, nicht schliessbare Kennzeichnung eines generierten Werkzeugs
/// (docs/27-werkbank-spezifikation.md Abschnitt 3.2). Rendert ausschliesslich
/// den Basis-[SubsumoChip]-Konstruktor - der verdrahtet weder `onDeleted`
/// noch einen Icon-Button, es gibt also strukturell keinen Dismiss-Pfad,
/// keine Wisch-Geste und keinen clientseitigen "geschlossen"-Zustand.
class GeneratedToolBadge extends StatelessWidget {
  const GeneratedToolBadge({required this.labeling, super.key});

  final ToolSpecLabeling labeling;

  @override
  Widget build(BuildContext context) {
    return SubsumoChip(label: labeling.badgeText, icon: Icons.auto_awesome);
  }
}

/// Umschliesst ein per Sandbox dargestelltes generiertes Werkzeug
/// (`app/lib/sandbox/sandbox_runtime.dart`) in einem Kopfbereich mit
/// [GeneratedToolBadge]. Jeder kuenftige Aufrufer (Ticket 3/4a) bekommt die
/// Kennzeichnungspflicht aus Abschnitt 3.2 dadurch automatisch, ohne sie pro
/// Screen erneut zu verdrahten.
///
/// [toolSpec] ist das vollstaendig dekodierte, **persistierte** Tool-Spec-
/// JSON (Abschnitt 3.1) - die Kennzeichnung wird bei jedem Aufbau neu daraus
/// gelesen, nie aus clientseitigem Zustand zwischengespeichert. Dieselbe
/// Instanz liefert deshalb nach App-Neustart oder erneutem Aufruf desselben
/// Werkzeugs dieselbe Kennzeichnung (Fertig-Kriterium 3).
///
/// [toolContent] ist der bereits durch die Sandbox erzeugte, host-eigene
/// Widget-Baum fuer die eigentliche Werkzeug-Ausgabe.
///
/// Fehlt `labeling` im Spec oder ist `is_suggestion != true`, wird
/// [toolContent] **nicht** dargestellt (Fertig-Kriterium 4, Fail-Closed) -
/// stattdessen eine feste Fehlermeldung, analog zu Fehlerklasse D in
/// Abschnitt 4.3.
class GeneratedToolHost extends StatelessWidget {
  const GeneratedToolHost({
    required this.toolSpec,
    required this.toolContent,
    super.key,
  });

  final Map<String, dynamic> toolSpec;
  final Widget toolContent;

  @override
  Widget build(BuildContext context) {
    final labeling = ToolSpecLabeling.fromToolSpecJson(toolSpec);
    if (labeling == null) {
      return const SubsumoPanel(
        child: SubsumoFeedbackBlock(
          message: 'Werkzeug kann nicht angezeigt werden.',
          detail: 'Fehlende oder ungueltige Vorschlags-Kennzeichnung.',
          severity: FeedbackSeverity.negative,
        ),
      );
    }

    return SubsumoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GeneratedToolBadge(labeling: labeling),
          ),
          const SizedBox(height: Spacing.md),
          toolContent,
        ],
      ),
    );
  }
}
