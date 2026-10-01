/// Harte Plattformgrenze fuer den Werkbank-Sandbox-Einstiegspunkt (SUB-409,
/// docs/27 Abschnitt 1.1/1.4): Mobile (Android/iOS) ist keine unterstuetzte
/// Werkbank-Laufzeit. Seit SUB-382 kennt `IoSandboxRuntime` keinen
/// In-Process-Pfad mehr, und kein natives Build-Tooling buendelt die
/// Worker-Binary fuer Mobile (anders als fuer Desktop, siehe
/// `linux/CMakeLists.txt`, `windows/CMakeLists.txt`,
/// `macos/Runner.xcodeproj/project.pbxproj`). Ohne diesen Check scheitert
/// ein Aufruf auf Mobile zufaellig an einer fehlenden Binary
/// (`resolveSandboxWorkerExecutable` in `sandbox_runtime_io.dart`) statt an
/// einer beabsichtigten, dokumentierten Plattformgrenze.
library;

import 'package:flutter/foundation.dart';

/// true fuer Web und Desktop (Linux/Windows/macOS), false fuer Android/iOS
/// und jede andere, von Flutter nicht als Desktop/Mobile unterschiedene
/// Zielplattform.
///
/// [platformOverride] ist ausschliesslich fuer Tests gedacht (siehe
/// `sandbox_platform_support_test.dart`) - im echten Betrieb bleibt er
/// `null` und [defaultTargetPlatform] entscheidet.
bool isWerkbankSandboxSupported({TargetPlatform? platformOverride}) {
  if (kIsWeb) {
    return true;
  }
  switch (platformOverride ?? defaultTargetPlatform) {
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

/// Wirft einen [UnsupportedError], wenn die aktuelle Plattform die
/// Werkbank-Sandbox nicht unterstuetzt (docs/27 Abschnitt 1.4). Jeder
/// Werkbank-Einstiegspunkt - aktuell nur [createSandboxRuntime] in
/// `sandbox_runtime.dart`, die Werkbank-UI ist weiterhin dark - muss dies
/// vor der ersten Sandbox-Nutzung pruefen.
void assertWerkbankSandboxSupported({TargetPlatform? platformOverride}) {
  if (!isWerkbankSandboxSupported(platformOverride: platformOverride)) {
    throw UnsupportedError(
      'Werkbank-Sandbox ist auf Mobile (Android/iOS) nicht unterstuetzt '
      '(docs/27 Abschnitt 1.4, SUB-409) - der Einstiegspunkt ist auf dieser '
      'Plattform absichtlich nicht erreichbar.',
    );
  }
}
