/// Wird nur erreicht, wenn weder `dart:io` noch `dart:js_interop` verfuegbar
/// sind - auf keiner von Flutter unterstuetzten Zielplattform der Fall.
library;

import 'sandbox_types.dart';

SandboxRuntime createSandboxRuntime() => throw UnsupportedError(
      'Keine Sandbox-Runtime fuer diese Plattform verfuegbar.',
    );
