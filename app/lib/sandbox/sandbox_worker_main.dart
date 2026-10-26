/// Eigenstaendiger Worker-Prozess fuer die Werkbank-Sandbox auf Mobile/
/// Desktop (SUB-382, Folgearbeit aus SUB-359/SUB-318). Fuehrt genau eine
/// QuickJS-Auswertung aus und beendet sich danach.
///
/// Warum ein eigener Prozess statt der bisherigen In-Process-Ausfuehrung
/// (siehe `sandbox_runtime_io.dart`, Stand vor SUB-382): eine echte
/// synchrone `while (true) {}` blockiert den nativen QuickJS-FFI-Aufruf
/// unbegrenzt - kein Dart-seitiger Mechanismus (Timer, Future.timeout,
/// Isolate.kill) kann einen bereits laufenden blockierenden FFI-Aufruf im
/// selben Prozess unterbrechen, weil kein Dart-Code laeuft, bis die native
/// Funktion zurueckkehrt (empirisch verifiziert, siehe SUB-359-Kommentar
/// zu `sandbox_runtime_io.dart`). Ein separater Prozess hat dieses Problem
/// nicht: der Host (`sandbox_runtime_io.dart`) kann ihn von aussen per
/// SIGKILL/TerminateProcess hart beenden, unabhaengig davon, was der
/// Prozess gerade tut - `SIGKILL` ist nicht abfangbar oder blockierbar.
///
/// WICHTIGER, EMPIRISCH BESTAETIGTER BEFUND (aendert die in SUB-382
/// vorgeschlagene Architektur): `package:flutter_js`s High-Level-API
/// (`QuickJsRuntime2`) kann NICHT in einer per `dart compile exe`
/// erzeugten eigenstaendigen Binary laufen. `QuickJsRuntime2` erweitert
/// `JavascriptRuntime` (`package:flutter_js/javascript_runtime.dart`),
/// das `package:flutter/foundation.dart` importiert; `quickjs_runtime2.dart`
/// importiert zusaetzlich den `flutter_js.dart`-Barrel, der wiederum
/// `package:flutter/services.dart` zieht. `dart compile exe` kompiliert
/// aber nur reine Dart-SDK-Abhaengigkeiten, keine Flutter-Framework-
/// Abhaengigkeiten (verifiziert: ein Worker, der `package:flutter_js/
/// flutter_js.dart` importiert, bricht die AOT-Kompilierung mit
/// Kernel-Fehlern in `package:flutter/src/services/text_layout_metrics.dart`
/// ab). Deshalb bindet diese Datei bewusst NICHT `QuickJsRuntime2`, sondern
/// direkt die rohe, Flutter-unabhaengige FFI-Schicht aus
/// `package:flutter_js/quickjs/ffi.dart` (importiert dort nur `dart:ffi`,
/// `dart:io`, `dart:isolate`, `package:ffi/ffi.dart` - keine Flutter-
/// Abhaengigkeit) und implementiert die minimale Teilmenge selbst: Runtime/
/// Kontext anlegen, Quelltext auswerten, Ergebnis/Exception als String
/// lesen, wieder freigeben. Kein `sendMessage`-Kanal, keine Objekt-
/// Marshaling-Schicht noetig, weil die Harness (`buildIoHarness`) das
/// Ergebnis ohnehin als `JSON.stringify(...)`-String zurueckgibt - die
/// generische bidirektionale JS<->Dart-Konvertierung aus `quickjs_runtime2
/// .dart` (`_jsToDart`/`_dartToJs`) wird dafuer nicht gebraucht.
///
/// Das im SUB-359-Kommentar dokumentierte fehlende `jsSetMemoryLimit`-
/// Symbol in der gebundenen Linux-`.so` ist dadurch kein Problem mehr: das
/// Speicherlimit wird jetzt ohnehin vom Host auf Prozessebene durchgesetzt
/// (POSIX `rlimit`/`setrlimit` ueber den Shell-Wrapper in
/// `sandbox_runtime_io.dart`, s. `resolveSandboxWorkerExecutable`-
/// Dateikommentar dort), nicht mehr innerhalb der Engine-Instanz.
///
/// Protokoll: genau eine Zeile JSON auf stdin
/// (`{"source": ..., "input": ..., "maxSteps": ...}`), genau eine Zeile
/// JSON-Umschlag (`{"ok": true, "output": ...}` oder
/// `{"ok": false, "error": "..."}`) auf stdout, danach Prozessende. Kein
/// interaktiver Dialog, kein Zustand ueber einen Aufruf hinaus - deckt sich
/// mit der bestehenden Garantie "pro Aufruf neu instanziiert und danach
/// verworfen" (docs/27 Abschnitt 1.1), hier zusaetzlich durch das
/// Prozessende selbst erzwungen statt nur durch ein `dispose()`.
///
/// Wird per `dart compile exe` zu einer eigenstaendigen Binary uebersetzt
/// (siehe `sandbox_runtime_io.dart`, `resolveSandboxWorkerExecutable`) - der
/// Host braucht dafuer keinen Dart-SDK-Pfad zur Laufzeit. Die Frage, wie
/// diese Binary in Release-Builds je Desktop-Plattform gebuendelt wird
/// (natives Build-Tooling, `linux/CMakeLists.txt`/Windows-Runner/macOS-
/// Xcode-Bundle), ist bewusst NICHT Teil dieser Datei - siehe SUB-382,
/// weiterhin offen (Routing-Entscheidung Lead-Developer).
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_js/quickjs/ffi.dart';

import 'sandbox_step_guard.dart';

Future<void> main() async {
  final Map<String, dynamic> request;
  try {
    final line = stdin.readLineSync(encoding: utf8);
    if (line == null) {
      _reply({'ok': false, 'error': 'no_request'});
      return;
    }
    request = jsonDecode(line) as Map<String, dynamic>;
  } on FormatException {
    _reply({'ok': false, 'error': 'invalid_request'});
    return;
  }

  final source = request['source'] as String;
  final input = request['input'];
  final maxSteps = request['maxSteps'] as int?;

  _reply(_evaluateOnce(buildIoHarness(source, input, maxSteps: maxSteps)));
}

void _reply(Map<String, dynamic> envelope) {
  stdout.writeln(jsonEncode(envelope));
}

/// Nie tatsaechlich aufgerufener JS-Channel: die Harness ruft keine
/// Host-Bruecke auf (kein `console`/`setTimeout`/`sendMessage` - anders als
/// im alten In-Process-Pfad muss hier nichts nachtraeglich entfernt werden,
/// weil nie etwas eingehaengt wird). Falls QuickJS diesen Kanal doch
/// aufruft (z. B. ein zukuenftiger Harness-Fehler ruft versehentlich eine
/// native Funktion auf), liefert er `undefined` statt abzustuerzen.
Pointer<JSValue> _unusedChannel(Pointer<JSContext> ctx, int type, Pointer<JSValue> argv) {
  return jsUNDEFINED();
}

/// Legt eine frische QuickJS-Runtime+Kontext an, wertet [harnessSource] aus
/// und gibt den `{ok, output|error}`-Umschlag zurueck - `source`/`error`
/// sind dabei bereits fertige JSON-Strings, die die Harness selbst per
/// `JSON.stringify` erzeugt (siehe `buildIoHarness`). Gibt die Runtime in
/// jedem Fall wieder frei, auch bei einer JS-Exception.
Map<String, dynamic> _evaluateOnce(String harnessSource) {
  final port = ReceivePort();
  final rt = jsNewRuntime(_unusedChannel, 0, port);
  try {
    final ctx = jsNewContext(rt);
    try {
      final jsval = jsEval(ctx, harnessSource, '<sandbox>', JSEvalFlag.GLOBAL);
      if (jsIsException(jsval) != 0) {
        jsFreeValue(ctx, jsval);
        final exc = jsGetException(ctx);
        final message = jsToCString(ctx, exc);
        jsFreeValue(ctx, exc);
        return {'ok': false, 'error': _classifyEngineErrorCode(message)};
      }
      final resultString = jsToCString(ctx, jsval);
      jsFreeValue(ctx, jsval);
      try {
        return jsonDecode(resultString) as Map<String, dynamic>;
      } on FormatException {
        return {'ok': false, 'error': 'invalid_envelope'};
      }
    } finally {
      jsFreeContext(ctx);
    }
  } finally {
    jsFreeRuntime(rt);
    port.close();
  }
}

/// Bestmoegliche Einordnung einer Top-Level-Engine-Exception (Syntaxfehler,
/// Speicherlimit) anhand der QuickJS-Fehlermeldung als fester Fehlercode
/// fuer den JSON-Umschlag (siehe `sandbox_envelope.dart`,
/// `classifySandboxError`). Kein `timeout`/`interrupt`-Fall mehr wie im
/// alten In-Process-Pfad (`classifyIoEngineError` vor SUB-382): der
/// Wall-Clock-Timeout wird jetzt ausschliesslich vom Host per
/// Prozess-Kill erzwungen (siehe `sandbox_runtime_io.dart`), dieser Prozess
/// bekommt davon nichts mehr mit - er wird einfach beendet. Nicht
/// sicherheitsrelevant: der Host zeigt in jedem Fall nur eine feste
/// Nutzermeldung, diese Klassifizierung entscheidet nur, welche der festen
/// Meldungen angezeigt wird.
String _classifyEngineErrorCode(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('syntax')) return 'compile_error';
  if (lower.contains('memory') || lower.contains('alloc')) return 'memory_limit_exceeded';
  return 'worker_error';
}

/// Baut das JS-Programm, das `source` laedt, `execute(input)` aufruft und
/// das Ergebnis als `{ok, output|error}`-JSON-String zurueckgibt. Oeffentliche
/// Top-Level-Funktion, damit sie ohne QuickJS-Engine getestet werden kann
/// (siehe test/sandbox/sandbox_worker_main_test.dart). Entfernt keine
/// Host-Bruecken (anders als der alte In-Process-Pfad) - dieser minimale
/// Channel (siehe [_unusedChannel]) haengt von vornherein keine ein, es
/// gibt nichts zu entfernen.
String buildIoHarness(String source, Object? input, {int? maxSteps}) {
  final encodedInput = jsonEncode(input);
  final instrumentedSource = maxSteps == null ? source : instrumentStepLimit(source, maxSteps);
  return '''
(function () {
  try {
    $instrumentedSource
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
