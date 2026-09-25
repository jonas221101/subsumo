/// Gemeinsamer JSON-Vertrag fuer die Werkbank-Sandbox (SUB-318, Ticket 5 aus
/// docs/27-werkbank-spezifikation.md Abschnitt 7). Diese Datei ist bewusst
/// plattformunabhaengig (kein dart:io, kein dart:js_interop) und wird von der
/// Mobile/Desktop- (QuickJS) und der Web-Implementierung (Iframe) geteilt,
/// damit beide denselben Vertrag durchsetzen statt ihn zu duplizieren.
library;

/// Grenzen, die der Host durchsetzt (docs/27 Abschnitt 1.1) - der generierte
/// Code kann sie nicht veraendern, weil er sie nie zu Gesicht bekommt.
class SandboxResourceLimits {
  const SandboxResourceLimits({
    this.timeoutMs = 300,
    this.maxOutputBytes = 8192,
  });

  /// Wall-Clock-Budget je Aufruf in Millisekunden (docs/27 Abschnitt 1.1).
  final int timeoutMs;

  /// Maximale Groesse des JSON-serialisierten Rueckgabewerts in Bytes
  /// (`resource_limits.max_output_bytes`, docs/27 Abschnitt 3.1).
  final int maxOutputBytes;
}

/// Fehlerklasse D aus docs/27 Abschnitt 4.3: eine vom Host erzwungene
/// Grenzverletzung, nie ein Fehler des Nutzers oder eine Fachlogik-Ausnahme.
/// Jede Variante bekommt eine feste, nicht-technische Nutzermeldung -
/// niemals die rohe Engine-Fehlermeldung, um keine Interna zu verraten.
enum SandboxErrorClass {
  /// 300-ms-Budget ueberschritten; Interpreter/Iframe wurde hart beendet.
  timeout,

  /// Speicherobergrenze der Engine-Instanz ueberschritten.
  memoryLimitExceeded,

  /// `code.source` ist kein gueltiges JavaScript oder wirft beim Laden.
  compileError,

  /// `execute(input)` wirft zur Laufzeit oder liefert keine `execute`-Funktion.
  runtimeError,

  /// Rueckgabewert laesst sich nicht als JSON serialisieren, oder
  /// `resource_limits.max_output_bytes` wurde ueberschritten.
  invalidOutput,
}

/// Feste, uebersetzungsfaehige Nutzermeldungen je Fehlerklasse - dieselbe
/// Meldung unabhaengig davon, welche Plattform die Grenze durchgesetzt hat.
const Map<SandboxErrorClass, String> sandboxErrorMessages = {
  SandboxErrorClass.timeout: 'Zeitlimit ueberschritten.',
  SandboxErrorClass.memoryLimitExceeded: 'Speicherlimit ueberschritten.',
  SandboxErrorClass.compileError: 'Werkzeug konnte nicht geladen werden.',
  SandboxErrorClass.runtimeError: 'Werkzeug konnte nicht ausgefuehrt werden.',
  SandboxErrorClass.invalidOutput: 'Werkzeugausgabe ungueltig.',
};

/// Wird geworfen, wenn eine der Host-Grenzen aus [SandboxResourceLimits]
/// verletzt wird oder die Ausfuehrung sonst fehlschlaegt. Traegt bewusst
/// keine rohe Engine-Fehlermeldung als `message` - nur die feste Meldung aus
/// [sandboxErrorMessages].
class SandboxException implements Exception {
  SandboxException(this.errorClass) : message = sandboxErrorMessages[errorClass]!;

  final SandboxErrorClass errorClass;
  final String message;

  @override
  String toString() => 'SandboxException(${errorClass.name}: $message)';
}

/// Ausfuehrungsumgebung fuer generierten Code als reine Funktion
/// `execute(input) -> output` mit leerer Capability-Liste (docs/27
/// Abschnitt 1.1). Jede Implementierung instanziiert die zugrundeliegende
/// Engine pro Aufruf neu und verwirft sie danach - kein Zustand ueberlebt
/// einen Aufruf.
///
/// [source] ist der JavaScript-Quelltext, der eine globale Funktion
/// `execute` definieren muss. [input] und der Rueckgabewert sind JSON-
/// kompatible Dart-Werte (`Map`/`List`/`String`/`num`/`bool`/`null`).
abstract class SandboxRuntime {
  Future<Object?> execute(
    String source,
    Object? input, {
    SandboxResourceLimits limits = const SandboxResourceLimits(),
  });
}
