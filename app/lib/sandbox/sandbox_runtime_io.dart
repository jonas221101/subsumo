/// Mobile/Desktop-Implementierung der Werkbank-Sandbox (SUB-318, docs/27
/// Ticket 5), seit SUB-382 per Prozessisolation statt In-Process-QuickJS.
///
/// AELTERER STAND (bis SUB-359/vor SUB-382, nur noch als Kontext):
/// diese Datei fuehrte QuickJS ueber `package:flutter_js` direkt im
/// Host-Prozess aus. Empirisch bestaetigt: eine echte `while (true) {}`
/// haengt sich dabei nicht wie dokumentiert an `JS_SetInterruptHandler`
/// (`QuickJsRuntime2(timeout: ...)` kehrte nicht zurueck, obwohl `nm -D`
/// das Symbol als gebunden zeigt) - der native FFI-Aufruf ist synchron und
/// blockiert den OS-Thread, kein Dart-seitiger Mechanismus (Timer,
/// Isolate.kill) kann ihn unterbrechen, weil kein Dart-Code laeuft, bis die
/// native Funktion zurueckkehrt. Zusaetzlich fehlte der Wrapper-Symbolname
/// `jsSetMemoryLimit` in der gebundenen Linux-`.so` (nur das rohe
/// `JS_SetMemoryLimit` war exportiert), weshalb kein Speicherlimit gesetzt
/// wurde.
///
/// SUB-382-LOESUNG: die QuickJS-Auswertung laeuft jetzt in einem separaten
/// Worker-Prozess (`sandbox_worker_main.dart`, per `dart compile exe`
/// uebersetzt), den dieser Host-Code per Wall-Clock-Timeout hart per
/// SIGKILL beendet (unabhaengig davon, was der Prozess gerade tut - anders
/// als ein In-Process-Timer funktioniert das garantiert, siehe
/// `sandbox_worker_main.dart`-Dateikommentar) und dem er per POSIX
/// `ulimit -v` (siehe [_startMemoryLimitedProcess]) eine Obergrenze fuer den
/// virtuellen Adressraum mitgibt. Beide vorherigen Luecken sind damit auf
/// Linux empirisch geschlossen (siehe Kommentare an den jeweiligen
/// Funktionen unten fuer den genauen Nachweis); macOS teilt denselben
/// Mechanismus, ist aber nicht auf echter Hardware verifiziert. Windows hat
/// noch keine durchgesetzte Speicherobergrenze (fehlendes Job-Object,
/// siehe [_startMemoryLimitedProcess]) - der Wall-Clock-Hard-Kill
/// funktioniert dort trotzdem, weil `Process.kill()` in `dart:io`
/// plattformuebergreifend auf `TerminateProcess` abbildet.
///
/// Wie die kompilierte Worker-Binary in einem Release-Build je
/// Desktop-Plattform gebuendelt wird, ist NICHT Teil dieser Datei, sondern
/// des nativen Build-Tooling (`linux/CMakeLists.txt`, `windows/
/// CMakeLists.txt`, `macos/Runner.xcodeproj/project.pbxproj` - siehe
/// CONTRIBUTING.md "Generierte Dateien" fuer die benannte Ausnahme von der
/// sonstigen Nicht-Commit-Konvention dieser Verzeichnisse, sowie
/// `.github/workflows/manual-builds.yml`). Ohne eine an
/// [resolveSandboxWorkerExecutable] auffindbare Binary wirft [execute]
/// absichtlich, statt still auf eine ungesicherte In-Process-Ausfuehrung
/// zurueckzufallen.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sandbox_envelope.dart';
import 'sandbox_types.dart';

SandboxRuntime createSandboxRuntime() => const IoSandboxRuntime();

class IoSandboxRuntime implements SandboxRuntime {
  const IoSandboxRuntime({this.workerExecutable});

  /// Expliziter Pfad zur Worker-Binary, ueberschreibt
  /// [resolveSandboxWorkerExecutable]. Hauptsaechlich fuer Tests gedacht
  /// (siehe test/sandbox/sandbox_runtime_io_test.dart, das die Binary per
  /// `dart compile exe` in ein Scratch-Verzeichnis uebersetzt).
  final String? workerExecutable;

  @override
  Future<Object?> execute(
    String source,
    Object? input, {
    SandboxResourceLimits limits = const SandboxResourceLimits(),
  }) async {
    final executable = workerExecutable ?? resolveSandboxWorkerExecutable();
    final process = await _startMemoryLimitedProcess(
      executable,
      limits.maxMemoryBytes,
      environment: _quickJsLibraryEnvironment(executable),
    );

    process.stdin.writeln(jsonEncode({
      'source': source,
      'input': input,
      'maxSteps': limits.maxSteps,
    }));
    await process.stdin.close();

    // Muss vor dem Warten auf den Exitcode angestossen werden: ein Absturz
    // unter niedrigem `ulimit -v` (siehe [_startMemoryLimitedProcess]) kann
    // einen mehrere KB grossen Stacktrace auf stderr schreiben. Ohne
    // aktives Drainen wuerde der Worker beim Vollschreiben der OS-Pipe
    // blockieren und nie beenden - der Host wartet dann unbegrenzt auf
    // einen Exitcode, der nie kommt.
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    unawaited(process.stderr.drain<void>());

    final int exitCode;
    try {
      exitCode = await process.exitCode.timeout(Duration(milliseconds: limits.timeoutMs));
    } on TimeoutException {
      // SIGKILL ist nicht abfangbar oder blockierbar - anders als beim
      // fruesheren In-Process-Timeout (siehe Dateikommentar) spielt es
      // deshalb keine Rolle, ob der Worker gerade in einem blockierenden
      // nativen FFI-Aufruf haengt. Empirisch verifiziert: eine echte
      // `while (true) {}` im Worker haengt unbegrenzt, bis dieser Kill
      // eintrifft (siehe sandbox_worker_main.dart), und stirbt dann
      // zuverlaessig.
      process.kill(ProcessSignal.sigkill);
      await process.exitCode; // Kindprozess einsammeln, keinen Zombie hinterlassen.
      throw SandboxException(SandboxErrorClass.timeout);
    }

    if (exitCode != 0) {
      // `sandbox_worker_main.dart` faengt jede erwartbare Fehlerquelle
      // (Syntaxfehler, Laufzeitfehler, ungueltige Ausgabe) bereits ab und
      // meldet sie als JSON-Umschlag mit Exitcode 0 - ein von aussen
      // sichtbarer Absturz bedeutet daher praktisch immer, dass der Worker
      // die per `ulimit -v` gesetzte Obergrenze ueberschritten hat.
      // Empirisch verifiziert: die gebundene QuickJS-Bibliothek prueft das
      // Ergebnis eines fehlgeschlagenen `malloc` nicht ueberall und
      // segfaultet dann, statt eine JS-Exception zu werfen (siehe
      // [_startMemoryLimitedProcess]-Dateikommentar) - das ist trotzdem
      // eine durchgesetzte Grenze, nur ohne sauberen Abbruch.
      throw SandboxException(SandboxErrorClass.memoryLimitExceeded);
    }

    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode((await stdoutFuture).trim()) as Map<String, dynamic>;
    } on FormatException {
      throw SandboxException(SandboxErrorClass.invalidOutput);
    }
    return decodeSandboxEnvelope(envelope, limits);
  }
}

/// Ermittelt den Pfad zur AOT-kompilierten Worker-Binary
/// (`sandbox_worker_main.dart`).
///
/// Reihenfolge:
/// 1. `SANDBOX_WORKER_PATH` (Umgebungsvariable) - fuer Tests/CI/Entwicklung,
///    wo die Binary bei Bedarf per `dart compile exe` in ein temporaeres
///    Verzeichnis uebersetzt wird (siehe
///    test/sandbox/sandbox_runtime_io_test.dart). Nutzt einen Dart-SDK-Pfad
///    zur Uebersetzungszeit, nicht zur Laufzeit - der Worker selbst ist
///    danach eine eigenstaendige Binary.
/// 2. Ein Pfad direkt neben der laufenden App-Executable
///    (`sandbox_worker`/`sandbox_worker.exe`) - der Ort, an dem natives
///    Build-Tooling (SUB-382, Routing-Entscheidung beim Lead-Developer noch
///    offen) die Binary in einem Release-Build ablegen muesste.
///
/// Wirft absichtlich einen [StateError], wenn keine der beiden Quellen eine
/// existierende Datei liefert - KEIN stiller Rueckfall auf eine In-Process-
/// Ausfuehrung ohne Prozessisolation, weil das genau die Sicherheitsgarantie
/// (harter Wall-Clock-Kill, durchgesetztes Speicherlimit) unterlaufen wuerde,
/// die dieser gesamte Umbau herstellen soll. Aktuell hat kein Endnutzerpfad
/// einen Aufrufer dieser Funktion (Werkbank ist weiterhin dark, siehe
/// docs/27) - dieser Fehlerfall betrifft also nur zukuenftige Integration,
/// nicht produktiven Betrieb.
String resolveSandboxWorkerExecutable() {
  final override = Platform.environment['SANDBOX_WORKER_PATH'];
  if (override != null && File(override).existsSync()) {
    return override;
  }

  final exeName = Platform.isWindows ? 'sandbox_worker.exe' : 'sandbox_worker';
  final adjacent = '${File(Platform.resolvedExecutable).parent.path}/$exeName';
  if (File(adjacent).existsSync()) {
    return adjacent;
  }

  throw StateError(
    'Sandbox-Worker-Binary nicht gefunden (weder SANDBOX_WORKER_PATH="$override" '
    'noch "$adjacent"). SUB-382: natives Build-Tooling, das diese Binary in '
    'Release-Builds ausliefert, ist noch nicht entschieden/umgesetzt.',
  );
}

/// Ermittelt eine Umgebungsvariable, die dem Worker-Prozess hilft, die
/// native QuickJS-Bibliothek zu finden (nur Linux - siehe unten).
///
/// EMPIRISCH BESTAETIGTER FUND (SUB-382, per `strace -f -e trace=openat`
/// gegen einen echten Testlauf verifiziert, nicht nur vermutet): der
/// Worker-Prozess ist eine eigenstaendige `dart compile exe`-Binary ohne
/// eigenes RPATH und liegt nicht automatisch neben `libquickjs_c_bridge_
/// plugin.so` - anders als im alten In-Process-Aufbau, wo derselbe
/// `DynamicLibrary.open('libquickjs_c_bridge_plugin.so')`-Aufruf aus
/// `libapp.so` heraus erfolgte, das der Flutter-Linux-Build selbst neben die
/// Bibliothek in `bundle/lib/` legt (RPATH `$ORIGIN` greift dort). Ohne
/// diesen Fix bricht jeder Worker-Aufruf mit "cannot open shared object
/// file" ab, was [execute] faelschlich als [SandboxErrorClass.
/// memoryLimitExceeded] meldet (siehe Kommentar dort) - nicht nur ein
/// Theoriefall, sondern der Grund, warum alle QuickJS-Tests in dieser
/// Umgebung zunaechst mit genau dieser falschen Fehlerklasse fehlschlugen.
///
/// `package:flutter_js/quickjs/ffi.dart` liest fuer Linux bewusst eine
/// Umgebungsvariable als Override, bevor es auf den blossen Dateinamen
/// zurueckfaellt - genau dafuer gedacht. Zweite empirisch verifizierte Falle
/// dabei (wieder per `strace`, nicht nur aus dem Quelltext geraten): welche
/// der beiden Variablen `ffi.dart` liest, haengt von einer DRITTEN Variable
/// ab, `FLUTTER_TEST` - ist die (wie von `flutter test` fuer den gesamten
/// Prozessbaum gesetzt und vom Worker-Prozess geerbt) `"true"`, liest
/// `ffi.dart` `LIBQUICKJSC_TEST_PATH` statt `LIBQUICKJSC_PATH`. Nur eine der
/// beiden zu setzen, funktioniert deshalb nur in genau einem der beiden
/// Kontexte - diese Funktion setzt darum beide auf denselben Pfad.
///
/// Der Pfad selbst: `<Worker-Verzeichnis>/lib/libquickjs_c_bridge_plugin.so`,
/// wenn diese Datei existiert (das Layout, das `linux/CMakeLists.txt` fuer
/// Release-Builds erzeugt: die Worker-Binary im Bundle-Wurzelverzeichnis,
/// die von `flutter_js`s eigenem `linux/CMakeLists.txt` gebuendelte
/// Bibliothek eine Ebene darunter in `lib/`, siehe SUB-382-Kommentar dort).
/// `test/sandbox/sandbox_runtime_io_test.dart` legt fuer denselben Zweck
/// probeweise eine Kopie in genau dieses `lib/`-Unterverzeichnis neben die
/// im Scratch-Verzeichnis uebersetzte Test-Binary.
///
/// Windows braucht diesen Override nicht: `quickjs_c_bridge.dll` liegt dort
/// direkt neben der Executable (kein separates `lib/`, siehe windows/
/// CMakeLists.txt), und Windows' Standard-DLL-Suchreihenfolge prueft das
/// Executable-Verzeichnis zuerst.
///
/// macOS bleibt ungeloest: `ffi.dart` nutzt dort `DynamicLibrary.process()`
/// statt eines Dateipfads, was voraussetzt, dass die Bibliothek bereits in
/// den aufrufenden Prozess geladen ist (im alten In-Process-Aufbau der Fall,
/// weil der Haupt-App-Prozess das Plugin-Framework selbst laedt) - der
/// separate Worker-Prozess laedt dieses Framework nie und kann es ueber
/// `ffi.dart`s aktuelle API auch nicht gezielt nachladen. Empirisch NICHT
/// verifiziert (keine macOS-Hardware verfuegbar), aber aus dem Quelltext von
/// `ffi.dart` eindeutig ableitbar: die Sandbox duerfte auf macOS mit der
/// Prozessisolations-Architektur in der jetzigen Form nicht funktionieren,
/// unabhaengig vom bereits dokumentierten `RLIMIT_AS`-Vorbehalt. Vor einem
/// macOS-Rollout waere entweder ein Patch/Fork von `flutter_js` noetig (ein
/// Pfad-Override analog zu `LIBQUICKJSC_PATH`) oder ein anderer Mechanismus.
Map<String, String>? _quickJsLibraryEnvironment(String executable) {
  if (!Platform.isLinux) {
    return null;
  }
  final candidate = '${File(executable).parent.path}/lib/libquickjs_c_bridge_plugin.so';
  if (!File(candidate).existsSync()) {
    return null;
  }
  return {'LIBQUICKJSC_PATH': candidate, 'LIBQUICKJSC_TEST_PATH': candidate};
}

/// Startet [executable] mit einer vom OS durchgesetzten Obergrenze fuer den
/// virtuellen Adressraum (`maxMemoryBytes`) - der Wert deckt den gesamten
/// Worker-Prozess ab (Dart-AOT-Laufzeit + gebundene QuickJS-Bibliothek +
/// generierter Code), nicht nur eine JS-Engine-interne Heap-Grenze. Das
/// entspricht dem SUB-382-Fertig-Kriterium woertlich ("durchgesetzte
/// OS-Speicherobergrenze fuer den Worker-Prozess"), nicht dem vor SUB-382
/// verfolgten Weg ueber `jsSetMemoryLimit` (Wrapper-Symbol fehlt in der
/// gebundenen Linux-Bibliothek, waere ausserdem nur eine JS-Heap-Grenze
/// gewesen, keine echte Prozessgrenze).
///
/// Nur fuer Linux empirisch verifiziert: `sh -c 'ulimit -v ...; exec ...'`
/// setzt `RLIMIT_AS` fuer den per `exec` ersetzten Kindprozess (kein
/// zusaetzlicher `fork` zwischen Shell und Worker - das Limit gilt darum
/// fuer den Worker-Prozess selbst, nicht nur fuer die Shell). Gegen die
/// reale gebundene QuickJS-Bibliothek getestet: ein
/// Speicher-Bombardierungsskript (verschachtelte grosse Arrays) stuerzt
/// unterhalb eines niedrigen Limits zuverlaessig ab (Segfault in
/// `JS_DefineProperty` - prueft das Ergebnis eines fehlgeschlagenen
/// `malloc` nicht), waehrend ein deutlich grosszuegigeres Limit dieselbe
/// Ausfuehrung anstandslos durchlaesst und ein normaler kurzer
/// `execute()`-Aufruf schon ab ca. 24 MiB nicht mehr betroffen ist.
///
/// macOS teilt denselben `ulimit -v`-Mechanismus (POSIX), aber der
/// xnu-Kernel ist dafuer bekannt, `RLIMIT_AS` nicht in jedem Fall
/// durchzusetzen wie Linux - nicht auf echter Hardware verifiziert, offener
/// Punkt vor einem macOS-Rollout.
///
/// Windows hat kein `rlimit`-Aequivalent - die richtige Entsprechung ist ein
/// Job Object (`CreateJobObject`/`SetInformationJobObject` mit
/// `JOBOBJECT_EXTENDED_LIMIT_INFORMATION`, `AssignProcessToJobObject`).
/// Bewusst NICHT hier implementiert: ungetestete Win32-FFI-Struct-Layouts
/// ohne echte Windows-Maschine zur Verifikation waeren genau die Art von
/// unbelegter Behauptung, die dieses Modul an anderer Stelle vermeidet -
/// offener Punkt fuer SUB-382. Bis dahin greift auf Windows nur der
/// Wall-Clock-Hard-Kill (funktioniert, weil `Process.kill()` in `dart:io`
/// dort plattformuebergreifend auf `TerminateProcess` abbildet), keine
/// durchgesetzte Speicherobergrenze.
Future<Process> _startMemoryLimitedProcess(
  String executable,
  int maxMemoryBytes, {
  Map<String, String>? environment,
}) {
  if (Platform.isWindows) {
    return Process.start(executable, const [], environment: environment);
  }
  final maxMemoryKb = (maxMemoryBytes / 1024).ceil();
  return Process.start(
    '/bin/sh',
    [
      '-c',
      r'ulimit -v "$1"; exec "$0"',
      executable,
      '$maxMemoryKb',
    ],
    environment: environment,
  );
}
