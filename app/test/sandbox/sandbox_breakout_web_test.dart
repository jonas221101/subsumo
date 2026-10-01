/// Sandbox-Sicherheitsabnahme (SUB-369, docs/27 Abschnitt 7 Ticket 9):
/// dedizierte Ausbruchsversuch-Testsuite als Rollout-Gate fuer Ticket 5
/// (SUB-318), Web-Pfad (sandboxed Iframe + Worker). Jeder Test hier *ist*
/// ein Angriffsversuch gegen eine der in docs/27 Abschnitt 7 Zeile 9
/// genannten Flaechen (Netzwerk, Datei, Storage, Timing-Seitenkanal) - er ist
/// **gruen, wenn der Ausbruch scheitert**, nicht wenn er gelingt.
///
/// Baut bewusst auf `sandbox_runtime_web_test.dart` (SUB-318) auf: Netzwerk
/// (fetch-Promise kann die synchrone Rueckgabe nicht mehr beeinflussen),
/// `localStorage` und der Wall-Clock-Hard-Kill per `worker.terminate()` sind
/// dort bereits abgedeckt. Diese Datei ergaenzt die restlichen Flaechen:
/// echte Dateisystem-APIs existieren im Browser ohnehin nicht (siehe
/// Gruppenkommentar unten), `indexedDB`/Cache-API als weitere Storage-Wege
/// neben `localStorage`, und einen dedizierten Timing-Seitenkanal-Versuch.
///
/// **Speichergrenze bewusst nicht Gegenstand dieser Datei:** docs/27
/// Abschnitt 1.1 nennt fuer Web explizit "das Prozesslimit des Browsers fuer
/// das Iframe", nicht eine vom Host konfigurierte Grenze -
/// `SandboxResourceLimits.maxMemoryBytes` wird vom Web-Pfad unveraendert
/// ignoriert (siehe Dateikommentar `sandbox_types.dart`). Ein Test, der
/// behauptet, eine Speichergrenze zu pruefen, waere hier irrefuehrend - siehe
/// stattdessen den Rollout-Vermerk im SUB-369-Thread, der diese Luecke
/// explizit als bekannt und spezifikationskonform dokumentiert statt sie
/// stillschweigend zu uebergehen.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:subsumo/sandbox/sandbox_runtime.dart';

Future<Object?> _run(String source,
    {Object? input, SandboxResourceLimits? limits}) {
  final runtime = createSandboxRuntime();
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
  group('Ausbruchsversuch: Dateizugriff (Web)', () {
    // Im Browser gibt es ohne explizit vom Nutzer erteilte Berechtigung
    // (File System Access API, nur per Nutzerinteraktion erreichbar und vom
    // Worker aus ohnehin nicht aufrufbar) keine echte Dateisystem-API - die
    // Flaeche "Datei" aus docs/27 Abschnitt 7 ist fuer den Web-Pfad strukturell
    // bereits durch das Fehlen jeder Node-/Deno-aehnlichen API geschlossen,
    // nicht nur durch eine zusaetzliche Sandbox-Massnahme. Dieser Test haelt
    // das als Regressionsschutz fest, statt die Flaeche stillschweigend
    // auszulassen.
    test('keine Dateisystem-API im Worker-Kontext erreichbar', () async {
      final output = await _run(
        'function execute(input) { return { '
        'hasRequire: typeof require, '
        'hasShowOpenFilePicker: typeof showOpenFilePicker, '
        'hasFileReader: typeof FileReader '
        '}; }',
      );
      // FileReader existiert als Web-API (liest nur Blobs/Files, die das
      // Skript selbst im Speicher erzeugt - kein Zugriff auf das echte
      // Dateisystem ohne eine vom Nutzer ausgewaehlte Datei), ist also kein
      // Ausbruch. `require` und `showOpenFilePicker` (braucht Nutzergeste,
      // im Worker ohnehin nicht definiert) muessen fehlen.
      expect(output, {
        'hasRequire': 'undefined',
        'hasShowOpenFilePicker': 'undefined',
        'hasFileReader': 'function',
      });
    });
  });

  group('Ausbruchsversuch: Storage-Zugriff (Web)', () {
    // sandbox_runtime_web_test.dart deckt bereits `localStorage` ab.
    // Ergaenzung: IndexedDB und die Cache-API sind die beiden anderen
    // nutzerdaten-persistenten Storage-Mechanismen im Browser.
    test('IndexedDB-Zugriff scheitert mit SecurityError wegen opaker Origin',
        () async {
      final output = await _run(
        '''
        function execute(input) {
          try {
            indexedDB.open("escape-test-db", 1);
            return { opened: true };
          } catch (e) {
            return { opened: false, name: e.name };
          }
        }
        ''',
      );
      // Ohne `allow-same-origin` bekommt das Iframe eine undurchsichtige
      // ("opaque") Origin - `indexedDB.open()` wirft dafuer einen
      // `SecurityError`, bevor irgendein Zugriff auf echte Nutzerdaten
      // moeglich waere. Empirisch verifiziert (siehe SUB-369-Thread).
      expect(output, {'opened': false, 'name': 'SecurityError'});
    });

    test(
        'Cache-API (Service-Worker-Cache) ist im sandboxed Worker nicht definiert',
        () async {
      final output =
          await _run('function execute(input) { return typeof caches; }');
      expect(output, 'undefined');
    });
  });

  group('Ausbruchsversuch: Timing-Seitenkanal (Web)', () {
    // Der Standard-Browser-Seitenkanal (SharedArrayBuffer + Atomics als
    // hochaufloesende, von einem zweiten Thread getaktete Uhr, Grundlage von
    // Spectre-artigen Angriffen) braucht `crossOriginIsolated` (COOP+COEP).
    // Die Harness setzt diese Header bewusst nicht; empirisch verifiziert
    // (siehe SUB-369-Thread): `SharedArrayBuffer` ist im Worker-Kontext
    // tatsaechlich `undefined`.
    test('SharedArrayBuffer ist ohne Cross-Origin-Isolation nicht verfuegbar',
        () async {
      final output = await _run(
        'function execute(input) { return { '
        'sab: typeof SharedArrayBuffer, '
        'crossOriginIsolated: typeof crossOriginIsolated !== "undefined" ? crossOriginIsolated : null '
        '}; }',
      );
      expect(output, {'sab': 'undefined', 'crossOriginIsolated': false});
    });

    // Ueberraschender Befund (siehe SUB-369-Thread, nicht vorher getestet):
    // der sandboxed Worker kann selbst weitere, verschachtelte Worker
    // erzeugen (`new Worker(...)` ist im Worker-Kontext erreichbar und
    // funktioniert) - das waere die fehlende Zutat fuer eine
    // Nachrichten-basierte (deutlich grobkoernigere, weil durch
    // postMessage-Latenz verrauschte) Seitenkanal-Uhr ohne
    // SharedArrayBuffer. Der eigentliche Ausbruchsversuch - einen solchen
    // Seitenkanal zu nutzen, um Information in das Ergebnis einzuschleusen -
    // scheitert trotzdem strukturell: `execute()` muss synchron
    // zurueckkehren, bevor irgendeine asynchrone Worker-Antwort eintreffen
    // kann, und der Host entfernt das Iframe (inklusive aller
    // verschachtelten Worker) unmittelbar nach Erhalt dieser synchronen
    // Rueckgabe (`finish()` in sandbox_runtime_web.dart) - es gibt keinen
    // Zeitpunkt, zu dem eine verzoegerte Worker-Antwort das bereits
    // gelieferte Ergebnis noch aendern koennte.
    test(
      'verschachtelter Worker kann trotz erfolgreicher Erzeugung das synchrone Ergebnis nicht beeinflussen',
      () async {
        final output = await _run(
          '''
          function execute(input) {
            var nestedWorkerCreated = false;
            try {
              var blob = new Blob(["self.postMessage('nested-alive');"], {type: "text/javascript"});
              var url = URL.createObjectURL(blob);
              var w = new Worker(url);
              nestedWorkerCreated = true;
              // Bewusst nicht auf eine Antwort gewartet: execute() ist
              // synchron, eine asynchrone Worker-Nachricht kann die
              // Rueckgabe hier strukturell nicht mehr erreichen.
            } catch (e) {
              nestedWorkerCreated = false;
            }
            return { nestedWorkerCreated: nestedWorkerCreated, result: "unaffected" };
          }
          ''',
          limits: const SandboxResourceLimits(timeoutMs: 2000),
        );
        expect(output, {'nestedWorkerCreated': true, 'result': 'unaffected'});
      },
    );
  });

  group(
      'Ausbruchsversuch: Timeout-Durchsetzung ueberschreitet das Budget wirklich (Web)',
      () {
    // sandbox_runtime_web_test.dart deckt bereits eine echte Endlosschleife
    // ab. Ergaenzung: eine endliche, aber zu langsame Berechnung - stellt
    // sicher, dass die Durchsetzung wirklich am Zeitbudget haengt, nicht nur
    // an "laeuft nie fertig".
    test(
        'eine endliche, aber zu langsame Berechnung ueberschreitet das Zeitbudget real',
        () async {
      const slowButFinite = 'function execute(input) { '
          'var x = 0; '
          'for (var i = 0; i < 500000000; i++) { x += i % 7; } '
          'return x; '
          '}';
      final errorClass = await _errorClassOf(
        _run(slowButFinite,
            limits: const SandboxResourceLimits(timeoutMs: 150)),
      );
      expect(errorClass, SandboxErrorClass.timeout);
    });
  });
}
