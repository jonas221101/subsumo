/// Mobile/Desktop-Implementierung der Werkbank-Sandbox (SUB-318, docs/27
/// Ticket 5): ein eingebetteter QuickJS-Interpreter ueber das `flutter_js`-
/// Paket, pro Aufruf neu instanziiert und danach verworfen.
///
/// Warum `flutter_js` statt einer eigenen QuickJS-FFI-Bindung: das Paket
/// bindet QuickJS bereits per FFI fuer Android/Windows/Linux
/// (`DynamicLibrary.process()`/`.open()`) und JavaScriptCore fuer iOS, und
/// `QuickJsRuntime2` nimmt `timeout`/`memoryLimit` als native, im
/// Interpreter selbst durchgesetzte Konstruktorparameter entgegen
/// (`jsNewRuntime(channel, timeoutMs, port)`, `jsSetMemoryLimit`) statt nur
/// eine von aussen kooperativ gemessene Zeit. Das entspricht Abschnitt 1.1:
/// die Grenze wird vom Host/der Engine erzwungen, nicht vom generierten
/// Code eingehalten.
///
/// KRITISCHER, EMPIRISCH BESTAETIGTER BEFUND (nicht nur eine Vermutung):
/// `timeout` haengt sich auf dieser Plattform NICHT wie dokumentiert an
/// QuickJS' `JS_SetInterruptHandler` (der laut `nm -D` zwar von der
/// gebundenen nativen Bibliothek exportiert wird). Eine echte
/// `while (true) {}` im generierten Code liess den Aufruf manuell
/// verifiziert weit ueber `timeoutMs` hinaus (>30s bei konfigurierten 50ms)
/// unbegrenzt weiterlaufen, bis der Prozess von aussen mit `kill -9`
/// beendet wurde - der native Aufruf ist synchron und blockiert den
/// gesamten Isolate/Thread, weshalb ihn kein Dart-seitiger Timer
/// (auch nicht der Stopwatch-Check unten oder ein `Future.timeout`)
/// unterbrechen kann: Dart-Code laeuft erst wieder, wenn die native
/// Funktion zurueckkehrt. Der Stopwatch-Check unten faengt daher nur
/// Faelle ab, in denen QuickJS *selbst* rechtzeitig zurueckkehrt - er ist
/// keine Grenzverletzungs-Erkennung fuer einen echten Haenger.
///
/// Damit ist Abschnitt 1.1 ("Grenzverletzung -> Interpreter hart beenden")
/// fuer eine synchrone Endlosschleife auf diesem Implementierungspfad NICHT
/// erfuellt. Ein echtes Hard-Kill braucht Prozess- oder zumindest
/// OS-Thread-Isolation von aussen (analog zu `worker.terminate()` im
/// Web-Pfad, siehe sandbox_runtime_web.dart) - ein reiner Dart-`Isolate`
/// reicht dafuer vermutlich nicht, weil ein blockierender synchroner
/// FFI-Aufruf den zugrunde liegenden OS-Thread auch nach `Isolate.kill()`
/// nicht zwingend freigibt. Deshalb bewusst kein Automatiktest fuer diesen
/// Fall (siehe `test/sandbox/sandbox_runtime_io_test.dart`, `skip:`-Grund) -
/// er wuerde CI unbegrenzt haengen statt rot zu werden. Offener Punkt fuer
/// eine Entscheidung vor Ticket 9 / einem Rollout: entweder eine echte
/// Prozessisolation bauen, oder einen anderen Engine-Binding-Weg waehlen,
/// oder das Restrisiko bewusst tragen, solange nichts ausgeliefert wird.
///
/// Zweiter, ebenfalls bestaetigter Befund: die vorgebaute native
/// Bibliothek fuer Linux (`linux/shared/libquickjs_c_bridge_plugin.so`) ist
/// aelter als die aktuellen Dart-Bindings und exportiert `jsSetMemoryLimit`
/// nicht (per `nm -D` verifiziert - nur das rohe `JS_SetMemoryLimit` ohne
/// den Wrapper). `QuickJsRuntime2`s Konstruktor allokiert die native
/// Runtime (`jsNewRuntime`) *bevor* er `jsSetMemoryLimit` aufloest; ein
/// Abfangen des daraus resultierenden `ArgumentError` wuerde die bereits
/// allokierte Runtime undisponiert lassen (`_rt` wird erst danach gesetzt)
/// - ein Speicher-Leck bei jedem Aufruf. Deshalb wird `memoryLimit` hier
/// bewusst *nicht* gesetzt, statt das Symbol-Fehlen leck-behaftet
/// abzufangen. Ob Windows (vorgebaute DLL) und Android/iOS (aus Quellcode
/// bzw. JavaScriptCore) den Wrapper haben, ist unverifiziert - vor einem
/// echten Rollout (Ticket 9) auf einem realen Geraet pruefen. Bis dahin
/// gilt fuer diese Engine-Instanz keine durchgesetzte Speichergrenze.
library;

import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';

import 'sandbox_envelope.dart';
import 'sandbox_types.dart';

SandboxRuntime createSandboxRuntime() => const IoSandboxRuntime();

class IoSandboxRuntime implements SandboxRuntime {
  const IoSandboxRuntime();

  @override
  Future<Object?> execute(
    String source,
    Object? input, {
    SandboxResourceLimits limits = const SandboxResourceLimits(),
  }) async {
    final runtime = QuickJsRuntime2(timeout: limits.timeoutMs);
    try {
      _stripHostBridges(runtime);

      final stopwatch = Stopwatch()..start();
      final result = runtime.evaluate(buildIoHarness(source, input));
      stopwatch.stop();

      // Eigenstaendige, von der Engine-Fehlermeldung unabhaengige
      // Zeitpruefung: selbst wenn `evaluate()` scheinbar erfolgreich
      // zurueckkommt, aber das Budget ueberschritten hat, gilt der Aufruf
      // als Grenzverletzung - der Host vertraut nicht darauf, dass die
      // Engine ihre eigene Deadline immer korrekt meldet.
      if (stopwatch.elapsedMilliseconds >= limits.timeoutMs) {
        throw SandboxException(SandboxErrorClass.timeout);
      }
      if (result.isError) {
        throw SandboxException(classifyIoEngineError(result.stringResult));
      }
      final Map<String, dynamic> envelope;
      try {
        envelope = jsonDecode(result.stringResult) as Map<String, dynamic>;
      } on FormatException {
        throw SandboxException(SandboxErrorClass.invalidOutput);
      }
      return decodeSandboxEnvelope(envelope, limits);
    } finally {
      // "pro Ausfuehrung neu instanziiert und danach verworfen" (docs/27
      // Abschnitt 1.1) - kein Zustand ueberlebt einen Aufruf.
      runtime.dispose();
    }
  }

  /// `JavascriptRuntime.init()` injiziert automatisch `console` (leitet auf
  /// `print` um) und `setTimeout` (bruecke ueber einen Dart-`Timer`, der bei
  /// Ablauf erneut in den Interpreter evaluiert). Fuer eine wirklich leere
  /// Capability-Liste werden beide vor der ersten Ausfuehrung des
  /// generierten Codes entfernt - insbesondere `setTimeout`, weil dessen
  /// Callback sonst asynchron, ausserhalb des 300-ms-Budgets und nach
  /// `dispose()` erneut in den (dann bereits verworfenen) Interpreter
  /// evaluieren wuerde. Kein `enableFetch()`/XHR-Erweiterung wird je
  /// aufgerufen, und es wird keine eigene Dart-Funktion in den Kontext
  /// eingehaengt - der generierte Code sieht ausschliesslich die
  /// ECMAScript-Built-ins.
  ///
  /// Zuweisung statt `delete`: `init()` definiert beide Eigenschaften mit
  /// `configurable: false` (per `Object.getOwnPropertyDescriptor` verifiziert)
  /// - `delete` schlaegt dort im Nicht-Strict-Modus lautlos fehl (gibt
  /// `false` zurueck, wirft nicht) und die Bindungen blieben unbemerkt
  /// erreichbar. Beide sind aber `writable: true`, daher entfernt eine
  /// Ueberschreibung mit `undefined` sie zuverlaessig.
  void _stripHostBridges(QuickJsRuntime2 runtime) {
    runtime.evaluate('globalThis.setTimeout = undefined; globalThis.console = undefined;');
  }
}

/// Baut das JS-Programm, das `source` laedt, `execute(input)` aufruft und
/// das Ergebnis als `{ok, output|error}`-JSON-String zurueckgibt. Oeffentliche
/// Top-Level-Funktion, damit sie ohne QuickJS-Engine getestet werden kann
/// (siehe test/sandbox/sandbox_runtime_io_test.dart).
String buildIoHarness(String source, Object? input) {
  final encodedInput = jsonEncode(input);
  return '''
(function () {
  try {
    $source
    if (typeof execute !== "function") {
      return JSON.stringify({ok: false, error: "no_execute_function"});
    }
    var output = execute($encodedInput);
    return JSON.stringify({ok: true, output: output === undefined ? null : output});
  } catch (e) {
    return JSON.stringify({ok: false, error: String((e && e.message) || e)});
  }
})();
''';
}

/// Bestmoegliche Einordnung einer Top-Level-Engine-Exception (Syntaxfehler,
/// Interrupt-Abbruch, Speicherlimit) anhand der QuickJS-Fehlermeldung. Nicht
/// sicherheitsrelevant: jeder Zweig wirft ohnehin eine [SandboxException] mit
/// fester Nutzermeldung, diese Klassifizierung entscheidet nur, welche der
/// festen Meldungen angezeigt wird.
SandboxErrorClass classifyIoEngineError(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('syntax')) return SandboxErrorClass.compileError;
  if (lower.contains('memory') || lower.contains('alloc')) {
    return SandboxErrorClass.memoryLimitExceeded;
  }
  if (lower.contains('interrupt') || lower.contains('timeout')) {
    return SandboxErrorClass.timeout;
  }
  return SandboxErrorClass.runtimeError;
}
