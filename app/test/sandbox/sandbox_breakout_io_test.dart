/// Sandbox-Sicherheitsabnahme (SUB-369, docs/27 Abschnitt 7 Ticket 9):
/// dedizierte Ausbruchsversuch-Testsuite als Rollout-Gate fuer Ticket 5
/// (SUB-318/SUB-359/SUB-382), nativer Pfad (QuickJS). Jeder Test hier *ist*
/// ein Angriffsversuch gegen eine der in docs/27 Abschnitt 7 Zeile 9 genannten
/// Flaechen (Netzwerk, Datei, Storage, Timing-Seitenkanal) oder gegen die
/// Ressourcengrenzen aus Abschnitt 1.1 (Timeout, Speicher) - er ist **gruen,
/// wenn der Ausbruch scheitert**, nicht wenn er gelingt.
///
/// Baut bewusst auf `sandbox_runtime_io_test.dart` (SUB-318/SUB-382) auf,
/// statt dessen Faelle zu duplizieren: Netzwerk/Datei/Storage-Abwesenheit,
/// der echte Wall-Clock-Hard-Kill und die echte OS-Speichergrenze sind dort
/// bereits durch einen Ausbruchsversuch pro Flaeche abgedeckt. Diese Datei
/// ergaenzt nur, was dort fehlt: einen dedizierten Timing-Seitenkanal-Versuch
/// sowie den Nachweis, dass der Worker-Pfad bei einer fehlenden Binary hart
/// und sichtbar fehlschlaegt, statt still auf eine ungesicherte In-Process-
/// Ausfuehrung zurueckzufallen - genau der Zustand, den Mobile (Android/iOS)
/// heute hat (siehe Rollout-Vermerk im SUB-369-Thread: `IoSandboxRuntime`
/// kennt keinen In-Process-Pfad mehr seit SUB-382, und kein Build-Tooling
/// buendelt die Worker-Binary fuer Mobile - anders als fuer Desktop, siehe
/// CONTRIBUTING.md "Generierte Dateien").
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subsumo/sandbox/sandbox_runtime.dart';
import 'package:subsumo/sandbox/sandbox_runtime_io.dart';

late final String _sandboxWorkerExecutable;

Future<Object?> _run(String source,
    {Object? input, SandboxResourceLimits? limits}) {
  final runtime = IoSandboxRuntime(workerExecutable: _sandboxWorkerExecutable);
  return runtime.execute(source, input,
      limits: limits ?? const SandboxResourceLimits());
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
    // Dieselbe Uebersetzung + Bibliothekslayout wie
    // sandbox_runtime_io_test.dart (siehe dort fuer die ausfuehrliche
    // Begruendung) - hier nicht erneut kommentiert, um Duplikation zu
    // vermeiden.
    scratchDir =
        await Directory.systemTemp.createTemp('sandbox_breakout_test_');
    final outputPath =
        '${scratchDir.path}/sandbox_worker${Platform.isWindows ? '.exe' : ''}';
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

    if (Platform.isLinux) {
      final packageConfig = jsonDecode(
        await File('.dart_tool/package_config.json').readAsString(),
      ) as Map<String, dynamic>;
      final packages =
          (packageConfig['packages'] as List).cast<Map<String, dynamic>>();
      final flutterJsPackage = packages.firstWhere(
        (p) => p['name'] == 'flutter_js',
        orElse: () => throw StateError(
            'package:flutter_js fehlt in package_config.json.'),
      );
      final packageRoot =
          Uri.parse(flutterJsPackage['rootUri'] as String).toFilePath();
      final bundledLibrary =
          File('$packageRoot/linux/shared/libquickjs_c_bridge_plugin.so');
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

  group('Ausbruchsversuch: Netzwerkzugriff (nativ)', () {
    // sandbox_runtime_io_test.dart deckt fetch/XMLHttpRequest bereits ab.
    // Ergaenzung hier: QuickJS' eigene CLI-Standardbibliothek (`std`/`os`,
    // auch bekannt als "quickjs-libc") bindet auf dem offiziellen qjs-Binary
    // echte Netz-/Datei-Funktionen (`os.open`, `std.urlGet` in manchen
    // Builds) als Module ein - ein plausibler, QuickJS-spezifischer
    // Ausbruchsversuch, der bei einer generischen "fetch ist undefined"-
    // Pruefung uebersehen werden koennte. Empirisch verifiziert (siehe
    // SUB-369-Thread): die von `flutter_js` gebundene Engine exponiert
    // weder `std` noch `os` als globale Bezeichner.
    test(
        'QuickJS-eigene std/os-Standardbibliothek (quickjs-libc) ist nicht erreichbar',
        () async {
      for (final probe in [
        'std.open("/etc/passwd", "r")',
        'os.open("/etc/passwd", 0)'
      ]) {
        final errorClass =
            await _errorClassOf(_run('function execute(input) { $probe; }'));
        expect(errorClass, SandboxErrorClass.runtimeError, reason: probe);
      }
    });
  });

  group('Ausbruchsversuch: Timing-Seitenkanal (nativ)', () {
    // Ein klassischer JS-Timing-Seitenkanal (z. B. SharedArrayBuffer +
    // Atomics als hochaufloesende, von einem zweiten Thread aus getaktete
    // Uhr) braucht zwingend zwei gleichzeitig laufende Ausfuehrungskontexte,
    // die sich dieselbe Speicherregion teilen. Empirisch verifiziert (siehe
    // SUB-369-Thread): die gebundene QuickJS-Engine definiert
    // `SharedArrayBuffer` zwar als Konstruktor (Teil der Engine-Baseline),
    // aber weder `Atomics` noch `Worker` noch einen anderen
    // Nebenlaeufigkeits-Mechanismus - ohne einen zweiten, gleichzeitig
    // laufenden Thread bleibt ein per Spin-Loop ausgelesener
    // SharedArrayBuffer-Zaehler bedeutungslos, weil ihn niemand sonst
    // veraendert. Der Ausbruchsversuch (eine funktionierende
    // Seitenkanal-Uhr bauen) scheitert damit strukturell, nicht nur durch
    // eine zufaellig fehlende einzelne API.
    test(
        'kein nebenlaeufiger Ausfuehrungskontext fuer eine SharedArrayBuffer-Taktung verfuegbar',
        () async {
      final output = await _run(
        'function execute(input) { return { '
        'hasSharedArrayBuffer: typeof SharedArrayBuffer, '
        'hasAtomics: typeof Atomics, '
        'hasWorker: typeof Worker, '
        'hasPostMessage: typeof postMessage '
        '}; }',
      );
      expect(output, {
        'hasSharedArrayBuffer': 'function',
        'hasAtomics': 'undefined',
        'hasWorker': 'undefined',
        'hasPostMessage': 'undefined',
      });
    });
  });

  group(
      'Ausbruchsversuch: Timeout-Durchsetzung ueberschreitet das Budget wirklich (nativ)',
      () {
    // sandbox_runtime_io_test.dart deckt bereits eine `while (true);`
    // Endlosschleife ab (Wall-Clock-Hard-Kill per Prozess-Kill, SUB-382).
    // Ergaenzung hier: eine Schleife, die NICHT ewig laeuft, sondern real
    // laenger braucht als das konfigurierte Budget - unterscheidet den
    // Wall-Clock-Pfad vom Schrittzaehler-Pfad (sandbox_step_guard.dart),
    // der ueber `maxSteps`, nicht ueber Zeit, auswertet.
    test(
      'eine endliche, aber zu langsame Berechnung ueberschreitet das Zeitbudget real und wird hart beendet',
      () async {
        const slowButFinite = 'function execute(input) { '
            'var x = 0; '
            'for (var i = 0; i < 2000000000; i++) { x += i % 7; } '
            'return x; '
            '}';
        final errorClass = await _errorClassOf(
          _run(
            slowButFinite,
            limits: const SandboxResourceLimits(
                timeoutMs: 200, maxSteps: 50000000000),
          ),
        );
        expect(errorClass, SandboxErrorClass.timeout);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  group(
      'Ausbruchsversuch: fehlende Worker-Binary faellt NICHT still auf unsichere Ausfuehrung zurueck',
      () {
    // Der kritischste denkbare Ausbruch waere kein Capability-Leck, sondern
    // ein stiller Fallback auf eine ungesicherte In-Process-Ausfuehrung ohne
    // Prozessisolation, falls die kompilierte Worker-Binary fehlt - genau
    // der Zustand, den Mobile (Android/iOS) heute hat, weil kein
    // Build-Tooling sie dort buendelt (siehe Rollout-Vermerk im
    // SUB-369-Thread). `resolveSandboxWorkerExecutable()`
    // (sandbox_runtime_io.dart) wirft stattdessen bewusst einen
    // `StateError` - dieser Test ist ein Regressionsschutz fuer genau diese
    // Entscheidung.
    test(
        'resolveSandboxWorkerExecutable() wirft, wenn keine Binary auffindbar ist',
        () {
      // Im Testprozess (flutter_tester) ist weder `SANDBOX_WORKER_PATH`
      // gesetzt noch liegt eine `sandbox_worker`-Datei neben der laufenden
      // Test-Executable - genau der Zustand, den Mobile heute tatsaechlich
      // hat (siehe Gruppenkommentar oben).
      expect(Platform.environment['SANDBOX_WORKER_PATH'], isNull);
      expect(resolveSandboxWorkerExecutable, throwsA(isA<StateError>()));
    });

    test(
        'IoSandboxRuntime ohne auffindbare Binary wirft, statt ungesichert auszufuehren',
        () async {
      // workerExecutable bewusst auf einen garantiert nicht existierenden
      // Pfad gesetzt, statt die Umgebungsvariable zu manipulieren - deckt
      // denselben Fehlerfall ab, den resolveSandboxWorkerExecutable() auf
      // Mobile heute immer liefert (kein `SANDBOX_WORKER_PATH`, keine
      // Datei neben der App-Executable).
      final runtime = IoSandboxRuntime(
        workerExecutable:
            '${Directory.systemTemp.path}/definitely-not-a-sandbox-worker-binary',
      );
      await expectLater(
        runtime.execute('function execute(input) { return 1; }', null),
        throwsA(anything),
      );
    });
  });
}
