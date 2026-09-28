@TestOn('browser')
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
  group('WebSandboxRuntime (Iframe + Worker)', () {
    test('fuehrt dasselbe feste Beispiel-Snippet ueber denselben JSON-Vertrag aus', () async {
      final output = await _run(
        'function execute(input) { return {sum: input.a + input.b}; }',
        input: {'a': 1, 'b': 2},
      );
      expect(output, {'sum': 3});
    });

    test(
      'Netzwerkzugriff im Worker kann das Ergebnis nicht beeinflussen: '
      'fetch() liefert ein Promise, das erst nach der synchronen Rueckgabe '
      'ablehnt (CSP connect-src none) und daher nie beobachtet wird',
      () async {
        // execute() ruft fetch() bewusst fire-and-forget auf, ohne
        // darauf zu warten (es ist synchron und gibt nichts zurueck) -
        // genau das ist der Punkt: es gibt keinen Kanal, ueber den ein
        // (ohnehin von der CSP blockierter) Netzwerkaufruf den
        // Rueckgabewert noch beeinflussen koennte.
        final output = await _run('function execute(input) { fetch("https://example.invalid"); return "done"; }');
        expect(output, 'done');
      },
    );

    test('kein Storage-Zugriff im Worker: localStorage ist im Worker-Kontext nicht definiert', () async {
      final errorClass = await _errorClassOf(
        _run('function execute(input) { localStorage.getItem("x"); }'),
      );
      expect(errorClass, SandboxErrorClass.runtimeError);
    });

    test('Endlosschleife wird per worker.terminate() hart beendet', () async {
      final errorClass = await _errorClassOf(
        _run(
          'function execute(input) { while (true) {} }',
          limits: const SandboxResourceLimits(timeoutMs: 100),
        ),
      );
      expect(errorClass, SandboxErrorClass.timeout);
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

    test('kein Zustand ueberlebt einen Aufruf: jeder Aufruf bekommt einen frischen Worker', () async {
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

    test('zwei gleichzeitige Aufrufe stehlen sich nicht gegenseitig die Antwort', () async {
      final results = await Future.wait([
        _run('function execute(input) { return "A"; }'),
        _run('function execute(input) { return "B"; }'),
      ]);
      expect(results, ['A', 'B']);
    });
  });
}
