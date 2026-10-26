@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subsumo/sandbox/sandbox_runtime.dart';
import 'package:subsumo/sandbox/sandbox_runtime_io.dart';

/// SUB-382: `IoSandboxRuntime` fuehrt QuickJS seit der Prozessisolation in
/// einem separaten Worker-Prozess aus (`sandbox_worker_main.dart`), den es
/// per `dart compile exe` als eigenstaendige Binary braucht (siehe
/// `sandbox_runtime_io.dart`, `resolveSandboxWorkerExecutable`). Fuer die
/// Tests hier wird diese Binary einmalig in ein Scratch-Verzeichnis
/// uebersetzt - im Dev-/Test-Setup ist der Dart-SDK-Pfad verfuegbar (siehe
/// SUB-382-Fertig-Kriterien), im Release-Build braucht es stattdessen
/// natives Build-Tooling (weiterhin offen, siehe dortiger Dateikommentar).
late final String _sandboxWorkerExecutable;

Future<Object?> _run(String source, {Object? input, SandboxResourceLimits? limits}) {
  final runtime = IoSandboxRuntime(workerExecutable: _sandboxWorkerExecutable);
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
  late Directory scratchDir;

  setUpAll(() async {
    scratchDir = await Directory.systemTemp.createTemp('sandbox_worker_test_');
    final outputPath = '${scratchDir.path}/sandbox_worker${Platform.isWindows ? '.exe' : ''}';
    final result = await Process.run('dart', [
      'compile',
      'exe',
      'lib/sandbox/sandbox_worker_main.dart',
      '-o',
      outputPath,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'dart compile exe fuer sandbox_worker_main.dart fehlgeschlagen:\n${result.stderr}',
      );
    }
    _sandboxWorkerExecutable = outputPath;

    // SUB-382, empirisch per `strace -f -e trace=openat` verifiziert: die
    // eigenstaendige Worker-Binary hat kein RPATH und findet
    // `libquickjs_c_bridge_plugin.so` deshalb nicht von selbst (anders als
    // der alte In-Process-Aufbau, wo derselbe `DynamicLibrary.open`-Aufruf
    // aus `libapp.so` heraus erfolgte, das der Flutter-Linux-Build selbst
    // neben die Bibliothek legt). `sandbox_runtime_io.dart`
    // (`_quickJsLibraryEnvironment`) sucht die Bibliothek unter
    // `<Worker-Verzeichnis>/lib/libquickjs_c_bridge_plugin.so` - genau das
    // Layout, das `linux/CMakeLists.txt` fuer einen echten Release-Build
    // erzeugt (siehe SUB-382-Kommentar dort). Hier wird dasselbe Layout im
    // Scratch-Verzeichnis nachgebildet, damit der Test exakt denselben
    // Auffindungsmechanismus uebt statt eines rein testspezifischen.
    if (Platform.isLinux) {
      // `Isolate.resolvePackageUri` ist im Test-Host (flutter_tester) nicht
      // unterstuetzt ("Unsupported operation") - stattdessen direkt
      // `.dart_tool/package_config.json` lesen, das `pub get` immer erzeugt.
      final packageConfig = jsonDecode(
        await File('.dart_tool/package_config.json').readAsString(),
      ) as Map<String, dynamic>;
      final packages = (packageConfig['packages'] as List).cast<Map<String, dynamic>>();
      final flutterJsPackage = packages.firstWhere(
        (p) => p['name'] == 'flutter_js',
        orElse: () => throw StateError('package:flutter_js fehlt in package_config.json.'),
      );
      final packageRoot = Uri.parse(flutterJsPackage['rootUri'] as String).toFilePath();
      final bundledLibrary = File('$packageRoot/linux/shared/libquickjs_c_bridge_plugin.so');
      if (!bundledLibrary.existsSync()) {
        throw StateError(
          'libquickjs_c_bridge_plugin.so nicht gefunden unter ${bundledLibrary.path} - '
          'package:flutter_js-Layout hat sich vermutlich geaendert.',
        );
      }
      final libDir = await Directory('${scratchDir.path}/lib').create();
      await bundledLibrary.copy('${libDir.path}/libquickjs_c_bridge_plugin.so');
    }
  });

  tearDownAll(() async {
    await scratchDir.delete(recursive: true);
  });

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

    test('console und setTimeout existieren nicht (leere Capability-Liste)', () async {
      for (final probe in ['console.log("x")', 'setTimeout(function () {}, 0)']) {
        final errorClass = await _errorClassOf(_run('function execute(input) { $probe; }'));
        expect(errorClass, SandboxErrorClass.runtimeError, reason: probe);
      }
    });

    // Regressionstest fuer den SUB-318-Review-Befund: die alte, auf
    // `package:flutter_js`s `QuickJsRuntime2` basierende Implementierung
    // haengte eine native `sendMessage`-Bruecke ein, die eine Denylist aus
    // `console`/`setTimeout` umgehen konnte (`sendMessage("SetTimeout", ...)`
    // rief den nativen Timer-Kanal direkt auf). Seit SUB-382 nutzt der
    // Worker-Prozess (`sandbox_worker_main.dart`) die rohe QuickJS-FFI-Schicht
    // direkt statt `QuickJsRuntime2` und haengt darum von vornherein keine
    // Host-Bruecke ein - dieser Test bleibt als Regressionsschutz bestehen,
    // falls das je wieder passiert.
    test('sendMessage-Kanal existiert nicht: direkter Aufruf ist ein Laufzeitfehler', () async {
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

    // Seit SUB-382 nie eingehaengt (siehe Kommentar oben) statt nachtraeglich
    // entfernt - bleibt als Regressionsschutz bestehen.
    test('flutter_js-Hilfsvariablen fuer setTimeout existieren nicht', () async {
      for (final probe in [
        'typeof __NATIVE_FLUTTER_JS__setTimeoutCallbacks !== "undefined"',
        'typeof __NATIVE_FLUTTER_JS__setTimeoutCount !== "undefined"',
      ]) {
        final output = await _run('function execute(input) { return $probe; }');
        expect(output, false, reason: probe);
      }
    });

    // SUB-382: vor der Prozessisolation war dieser Test bewusst nicht
    // automatisiert (siehe Git-Historie dieser Datei) - eine echte
    // `while (true);` (kein geschweifter Rumpf, siehe sandbox_step_guard.dart
    // "bewusst nicht abgedeckt") haengt sich beim In-Process-QuickJS-Aufruf
    // unbegrenzt auf, weil der native FFI-Aufruf synchron ist und der
    // Host-Prozess selbst blockiert waere. Jetzt laeuft die Auswertung in
    // einem separaten Worker-Prozess (`sandbox_worker_main.dart`), den
    // `IoSandboxRuntime` per SIGKILL beendet, sobald `timeoutMs` ueberschritten
    // ist - unabhaengig davon, dass der Worker dabei selbst haengt.
    test(
      'Endlosschleife ohne Yield-Punkt wird per Wall-Clock-Hard-Kill (Prozess-Kill) beendet',
      () async {
        final errorClass = await _errorClassOf(
          _run(
            'function execute(input) { while (true); }',
            limits: const SandboxResourceLimits(timeoutMs: 200),
          ),
        );
        expect(errorClass, SandboxErrorClass.timeout);
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    // SUB-382: die OS-Speicherobergrenze deckt den gesamten Worker-Prozess ab
    // (POSIX `ulimit -v`, siehe sandbox_runtime_io.dart), nicht nur einen
    // JS-Engine-internen Heap. Empirisch ermittelt: unter welchem genauen
    // Mechanismus die Grenze durchschlaegt (sauberer JS-Catch vs. Absturz)
    // ist nicht deterministisch - dieselbe Kombination aus Skript und Limit
    // lieferte in wiederholten Laeufen beide Ergebnisse (Speicherallokations-
    // Fehlerpfade in der gebundenen QuickJS-Bibliothek sind nicht in jedem
    // Fall robust gegen ein fehlgeschlagenes `malloc`). Der Test prueft
    // deshalb nur die stabile Invariante: die Ausfuehrung wirft in jedem Fall
    // eine SandboxException, statt das eigentlich sehr grosse Ergebnis
    // zurueckzugeben - unabhaengig von der genauen Fehlerklasse.
    test('durchgesetzte OS-Speicherobergrenze bricht einen Speicher-Bombardierungsversuch ab', () async {
      const bomb = 'function execute(input) { '
          'var arrs = []; '
          'for (var i = 0; i < 5000; i++) { arrs.push(new Array(2000).fill(i)); } '
          'return arrs.length; '
          '}';
      await expectLater(
        _run(bomb, limits: const SandboxResourceLimits(timeoutMs: 5000, maxMemoryBytes: 24 * 1024 * 1024)),
        throwsA(isA<SandboxException>()),
      );
    });

    test('dasselbe Skript liefert unter einer grosszuegigen Speicherobergrenze sein echtes Ergebnis', () async {
      const bomb = 'function execute(input) { '
          'var arrs = []; '
          'for (var i = 0; i < 5000; i++) { arrs.push(new Array(2000).fill(i)); } '
          'return arrs.length; '
          '}';
      final output = await _run(
        bomb,
        limits: const SandboxResourceLimits(timeoutMs: 5000, maxMemoryBytes: 512 * 1024 * 1024),
      );
      expect(output, 5000);
    });

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
