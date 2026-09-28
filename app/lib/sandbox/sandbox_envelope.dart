/// Gemeinsame Dekodierung des `{ok, output|error}`-Antwortumschlags, den die
/// QuickJS-Harness (`sandbox_runtime_io.dart`) und die Worker-Harness
/// (`sandbox_runtime_web.dart`) beide zurueckgeben. Eigene Datei, damit
/// diese reine, engine-unabhaengige Logik ohne QuickJS/Iframe testbar ist
/// (siehe test/sandbox/sandbox_envelope_test.dart).
library;

import 'dart:convert';

import 'sandbox_types.dart';

/// Prueft den von einer Harness zurueckgegebenen Umschlag gegen
/// [limits.maxOutputBytes] und wirft [SandboxException], falls die
/// Ausfuehrung fehlgeschlagen ist oder die Ausgabe zu gross ist. Gibt sonst
/// den reinen `output`-Wert zurueck.
Object? decodeSandboxEnvelope(
  Map<String, dynamic> envelope,
  SandboxResourceLimits limits,
) {
  if (envelope['ok'] != true) {
    throw SandboxException(classifySandboxError(envelope['error'] as String?));
  }
  final output = envelope['output'];
  final outputBytes = utf8.encode(jsonEncode(output)).length;
  if (outputBytes > limits.maxOutputBytes) {
    throw SandboxException(SandboxErrorClass.invalidOutput);
  }
  return output;
}

/// Ordnet den festen Fehlercode, den beide Harnesses fuer einen
/// abgefangenen Laufzeitfehler senden, einer [SandboxErrorClass] zu.
SandboxErrorClass classifySandboxError(String? error) {
  switch (error) {
    case 'timeout':
      return SandboxErrorClass.timeout;
    case 'no_execute_function':
    case 'worker_error':
      return SandboxErrorClass.runtimeError;
    case 'invalid_envelope':
      return SandboxErrorClass.invalidOutput;
    default:
      return SandboxErrorClass.runtimeError;
  }
}
