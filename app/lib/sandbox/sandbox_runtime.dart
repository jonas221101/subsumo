/// Oeffentlicher Einstiegspunkt der Werkbank-Sandbox (SUB-318, docs/27
/// Ticket 5). Waehlt die passende Implementierung zur Kompilierzeit aus -
/// `sandbox_runtime_io.dart` (QuickJS via `flutter_js`) auf Desktop,
/// `sandbox_runtime_web.dart` (sandboxed Iframe + Worker) auf Web. Mobile
/// (Android/iOS) ist keine unterstuetzte Laufzeit (docs/27 Abschnitt 1.4,
/// SUB-409) - [createSandboxRuntime] wirft dort ueber
/// [assertWerkbankSandboxSupported], bevor die Mobile/Desktop-Implementierung
/// (`sandbox_runtime_io.dart`) ueberhaupt ausgewaehlt wird.
library;

import 'package:flutter/foundation.dart';

import 'sandbox_platform_support.dart';
import 'sandbox_runtime_stub.dart'
    if (dart.library.io) 'sandbox_runtime_io.dart'
    if (dart.library.js_interop) 'sandbox_runtime_web.dart' as impl;
import 'sandbox_types.dart';

export 'sandbox_platform_support.dart';
export 'sandbox_types.dart';

/// Erstellt eine plattformpassende [SandboxRuntime]. Zustandslos - kann bei
/// jedem Aufruf neu erzeugt oder wiederverwendet werden, die zugrunde
/// liegende Engine wird trotzdem pro [SandboxRuntime.execute]-Aufruf neu
/// instanziiert und danach verworfen (siehe die jeweilige Implementierung).
///
/// [platformOverride] ist ausschliesslich fuer Tests gedacht (siehe
/// `sandbox_platform_support_test.dart`).
SandboxRuntime createSandboxRuntime({TargetPlatform? platformOverride}) {
  assertWerkbankSandboxSupported(platformOverride: platformOverride);
  return impl.createSandboxRuntime();
}
