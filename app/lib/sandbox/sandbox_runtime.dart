/// Oeffentlicher Einstiegspunkt der Werkbank-Sandbox (SUB-318, docs/27
/// Ticket 5). Waehlt die passende Implementierung zur Kompilierzeit aus -
/// `sandbox_runtime_io.dart` (QuickJS via `flutter_js`) auf Mobile/Desktop,
/// `sandbox_runtime_web.dart` (sandboxed Iframe + Worker) auf Web.
library;

import 'sandbox_runtime_stub.dart'
    if (dart.library.io) 'sandbox_runtime_io.dart'
    if (dart.library.js_interop) 'sandbox_runtime_web.dart' as impl;
import 'sandbox_types.dart';

export 'sandbox_types.dart';

/// Erstellt eine plattformpassende [SandboxRuntime]. Zustandslos - kann bei
/// jedem Aufruf neu erzeugt oder wiederverwendet werden, die zugrunde
/// liegende Engine wird trotzdem pro [SandboxRuntime.execute]-Aufruf neu
/// instanziiert und danach verworfen (siehe die jeweilige Implementierung).
SandboxRuntime createSandboxRuntime() => impl.createSandboxRuntime();
