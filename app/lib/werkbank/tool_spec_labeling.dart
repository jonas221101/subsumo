/// Client-seitige Lesart des `labeling`-Felds aus der Werkbank-Tool-Spec
/// (Ticket 4b, docs/27-werkbank-spezifikation.md Abschnitt 3.1/3.2). Einzige
/// Quelle der Wahrheit fuer Inhalt und Pflicht der Kennzeichnung ist das
/// persistierte Tool-Spec-JSON selbst (`backend/app/services/tool_spec.py`,
/// `LABELING_BADGE_TEXT`) - dieser Typ dupliziert den Wortlaut nicht als
/// Dart-Literal, sondern liest ihn jedes Mal aus dem uebergebenen Artefakt.
library;

/// Gelesene, bereits gegen Abschnitt 3.1 gepruefte Kennzeichnung eines
/// generierten Werkzeugs. Instanzen entstehen ausschliesslich ueber
/// [ToolSpecLabeling.fromToolSpecJson] - es gibt keinen oeffentlichen
/// Konstruktor, der die Pruefung umgehen koennte.
class ToolSpecLabeling {
  const ToolSpecLabeling._(this.badgeText);

  /// Text aus `tool_spec.labeling.badge_text`, wie im Artefakt gespeichert.
  final String badgeText;

  /// Liest und prueft `tool_spec.labeling` aus dem rohen, dekodierten
  /// Tool-Spec-JSON. Gibt `null` zurueck, wenn `labeling` fehlt,
  /// `is_suggestion` nicht genau `true` ist oder `badge_text` fehlt/leer
  /// ist - jede dieser Abweichungen ist ein Fail-Closed-Fall (Fertig-
  /// Kriterium 4), keine stillschweigende Lücke.
  static ToolSpecLabeling? fromToolSpecJson(Map<String, dynamic> toolSpec) {
    final labeling = toolSpec['labeling'];
    if (labeling is! Map) {
      return null;
    }
    if (labeling['is_suggestion'] != true) {
      return null;
    }
    final badgeText = labeling['badge_text'];
    if (badgeText is! String || badgeText.isEmpty) {
      return null;
    }
    return ToolSpecLabeling._(badgeText);
  }
}
