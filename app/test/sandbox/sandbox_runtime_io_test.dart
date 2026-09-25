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
