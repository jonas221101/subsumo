@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:subsumo/sandbox/sandbox_runtime.dart';

Future<Object?> _run(String source, {Object? input, SandboxResourceLimits? limits}) {
  final runtime = createSandboxRuntime();
  return runtime.execute(source, input, limits: limits ?? const SandboxResourceLimits());
}

Future<SandboxErrorClass> _errorClassOf(Future<Object?> future) async {
  try {
    await future;
  } on SandboxException catch (e) {
    return e.errorClass;
  }
  throw StateError('expected a SandboxException, got a normal result');
}

void main() {
  group('IoSandboxRuntime (QuickJS)', () {
    test('fuehrt ein festes Beispiel-Snippet ueber denselben JSON-Vertrag aus', () async {
      final output = await _run(
        'function execute(input) { return {sum: input.a + input.b}; }',
        input: {'a': 1, 'b': 2},
      );
      expect(output, {'sum': 3});
    });

    test('fehlende execute-Funktion ist ein Laufzeitfehler', () async {
      final errorClass = await _errorClassOf(_run('var notExecute = 1;'));
      expect(errorClass, SandboxErrorClass.runtimeError);
    });

    test('Syntaxfehler im Quelltext ist ein Compile-Fehler', () async {
      final errorClass = await _errorClassOf(_run('function execute(input) { ---; }'));
      expect(errorClass, SandboxErrorClass.compileError);
    });

    test('kein Netzwerkzugriff: fetch und XMLHttpRequest sind nicht definiert', () async {
      for (final probe in ['fetch("https://example.invalid")', 'new XMLHttpRequest()']) {
        final errorClass = await _errorClassOf(_run('function execute(input) { $probe; }'));
        expect(errorClass, SandboxErrorClass.runtimeError, reason: probe);
      }
    });

    test('kein Datei-/Storage-Zugriff: require, process und localStorage fehlen', () async {
      for (final probe in ['require("fs")', 'process.exit(0)', 'localStorage.getItem("x")']) {
        final errorClass = await _errorClassOf(_run('function execute(input) { $probe; }'));
        expect(errorClass, SandboxErrorClass.runtimeError, reason: probe);
      }
    });

    test('console und setTimeout sind entfernt (leere Capability-Liste)', () async {
      for (final probe in ['console.log("x")', 'setTimeout(function () {}, 0)']) {
        final errorClass = await _errorClassOf(_run('function execute(input) { $probe; }'));
        expect(errorClass, SandboxErrorClass.runtimeError, reason: probe);
      }
    });

    // Regressionstest fuer den SUB-318-Review-Befund: `_stripHostBridges`
    // entfernte frueher nur die JS-Bezeichner `console`/`setTimeout`, nicht
    // die native `sendMessage`-Bruecke, die `flutter_js` selbst einhaengt.
    // Generierter Code konnte darueber den Denylist umgehen und z. B.
    // `sendMessage("SetTimeout", ...)` direkt aufrufen, um einen Dart-Timer
    // scharf zu schalten. Dieser Test spricht den Kanal direkt an statt nur
    // die JS-Bezeichner zu pruefen.
    test('sendMessage-Kanal ist entfernt: direkter Aufruf umgeht den setTimeout-Denylist nicht', () async {
      final errorClass = await _errorClassOf(
        _run('''
          function execute(input) {
            sendMessage("SetTimeout", JSON.stringify({timeoutIndex: "0", timeout: 10}));
            return "unreachable";
          }
        '''),
      );
      expect(errorClass, SandboxErrorClass.runtimeError);
    });

    test('flutter_js-Hilfsvariablen fuer setTimeout sind entfernt', () async {
      for (final probe in [
        'typeof __NATIVE_FLUTTER_JS__setTimeoutCallbacks !== "undefined"',
        'typeof __NATIVE_FLUTTER_JS__setTimeoutCount !== "undefined"',
      ]) {
        final output = await _run('function execute(input) { return $probe; }');
        expect(output, false, reason: probe);
      }
    });

    // Absichtlich NICHT automatisiert: `QuickJsRuntime2(timeout: ...)` haengt
    // bei einer echten `while (true) {}` auf diesem Linux-Build unbegrenzt
    // (manuell verifiziert, mit `kill -9` beendet) statt nach `timeoutMs`
    // zurueckzukehren - JS_SetInterruptHandler wird laut `nm -D` zwar
    // gebunden, greift hier aber nicht wie dokumentiert. Ein Test, der sich
    // darauf verlaesst, wuerde CI unbegrenzt haengen lassen, nicht rot
    // werden: ein von aussen (Isolate/Prozess) hart abbrechender Timeout
    // fehlt noch (siehe sandbox_runtime_io.dart-Dateikommentar). Nicht
    // Teil dieser Aufgabe, offen fuer eine Folgeentscheidung.
    test(
      'Endlosschleife ohne Yield-Punkt ueberschreitet das Timeout-Budget',
      () async {},
      skip: 'siehe Kommentar: timeout-Parameter haengt statt abzubrechen (nicht automatisierbar ohne Prozessisolation)',
    );

    // SUB-359: Rueckfallgrenze aus docs/27 Abschnitt 1.1 ("Interpreter-
    // Schrittzaehler ... gegen Endlosschleifen, die innerhalb von 300 ms
    // viele kurze Yield-Punkte erzeugen"), umgesetzt per Quelltext-
    // Instrumentierung statt nativem Interpreter-Hook (siehe
    // sandbox_step_guard.dart). Unabhaengig vom Wall-Clock-Timeout: das
    // Timeout-Budget bleibt bewusst gross, nur maxSteps ist klein.
    test('Schleife ohne Endlosschleife-Charakter, aber ueber maxSteps, bricht mit stepLimitExceeded ab', () async {
      final errorClass = await _errorClassOf(
        _run(
          'function execute(input) { var i = 0; for (i = 0; i < 1000000; i++) {} return i; }',
          limits: const SandboxResourceLimits(timeoutMs: 10000, maxSteps: 1000),
        ),
      );
      expect(errorClass, SandboxErrorClass.stepLimitExceeded);
    });

    test('while- und do-while-Schleifen werden ebenfalls durch maxSteps begrenzt', () async {
      for (final source in [
        'function execute(input) { var i = 0; while (i < 1000000) { i++; } return i; }',
        'function execute(input) { var i = 0; do { i++; } while (i < 1000000); return i; }',
      ]) {
        final errorClass = await _errorClassOf(
          _run(source, limits: const SandboxResourceLimits(timeoutMs: 10000, maxSteps: 1000)),
        );
        expect(errorClass, SandboxErrorClass.stepLimitExceeded, reason: source);
      }
    });

    test('Schleife innerhalb von maxSteps liefert weiterhin ihr normales Ergebnis', () async {
      final output = await _run(
        'function execute(input) { var sum = 0; for (var i = 0; i < 100; i++) { sum += i; } return sum; }',
        limits: const SandboxResourceLimits(maxSteps: 10000),
      );
      expect(output, 4950);
    });

    test('das Wort "for"/"while" als Text in String- oder Kommentar-Literalen loest keine Instrumentierung aus', () async {
      final output = await _run(
        '''
          function execute(input) {
            // for while do - nur ein Kommentar
            var s = "for (;;) while (;;) do";
            return s.length;
          }
        ''',
        limits: const SandboxResourceLimits(maxSteps: 10000),
      );
      expect(output, 'for (;;) while (;;) do'.length);
    });

    test('Ausgabe ueber max_output_bytes wird als invalidOutput abgefangen', () async {
      final errorClass = await _errorClassOf(
        _run(
          'function execute(input) { return "x".repeat(1000); }',
          limits: const SandboxResourceLimits(maxOutputBytes: 16),
        ),
      );
      expect(errorClass, SandboxErrorClass.invalidOutput);
    });

    test('kein Zustand ueberlebt einen Aufruf: globale Variable verschwindet zwischen Aufrufen', () async {
      final firstRun = await _run(
        'globalThis.counter = (globalThis.counter || 0) + 1; '
        'function execute(input) { return globalThis.counter; }',
      );
      final secondRun = await _run(
        'globalThis.counter = (globalThis.counter || 0) + 1; '
        'function execute(input) { return globalThis.counter; }',
      );
      expect(firstRun, 1);
      expect(secondRun, 1);
    });
  });
}
