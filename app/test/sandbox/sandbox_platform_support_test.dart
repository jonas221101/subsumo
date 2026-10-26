/// SUB-409 (docs/27 Abschnitt 1.4): Mobile (Android/iOS) ist keine
/// unterstuetzte Werkbank-Laufzeit. Diese Tests belegen, dass der
/// Werkbank-Sandbox-Einstiegspunkt (`createSandboxRuntime()`) auf Mobile
/// durch eine beabsichtigte, benannte Plattformgrenze nicht erreichbar ist -
/// nicht nur zufaellig an einer fehlenden Worker-Binary scheitert (siehe
/// `sandbox_breakout_io_test.dart`, dort noch der unabsichtliche
/// Vorzustand).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subsumo/sandbox/sandbox_runtime.dart';

void main() {
  group('isWerkbankSandboxSupported', () {
    test('Desktop-Plattformen sind unterstuetzt', () {
      expect(isWerkbankSandboxSupported(platformOverride: TargetPlatform.linux), isTrue);
      expect(isWerkbankSandboxSupported(platformOverride: TargetPlatform.macOS), isTrue);
      expect(isWerkbankSandboxSupported(platformOverride: TargetPlatform.windows), isTrue);
    });

    test('Mobile-Plattformen sind nicht unterstuetzt', () {
      expect(isWerkbankSandboxSupported(platformOverride: TargetPlatform.android), isFalse);
      expect(isWerkbankSandboxSupported(platformOverride: TargetPlatform.iOS), isFalse);
    });

    test('Fuchsia ist nicht unterstuetzt (keine Werkbank-Build-Tooling-Abdeckung)', () {
      expect(isWerkbankSandboxSupported(platformOverride: TargetPlatform.fuchsia), isFalse);
    });
  });

  group('assertWerkbankSandboxSupported', () {
    test('wirft auf Android/iOS', () {
      expect(
        () => assertWerkbankSandboxSupported(platformOverride: TargetPlatform.android),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => assertWerkbankSandboxSupported(platformOverride: TargetPlatform.iOS),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('wirft nicht auf Desktop', () {
      expect(() => assertWerkbankSandboxSupported(platformOverride: TargetPlatform.linux), returnsNormally);
    });
  });

  group('createSandboxRuntime() - Werkbank-Einstiegspunkt', () {
    test('ist auf Android/iOS nicht erreichbar', () {
      expect(
        () => createSandboxRuntime(platformOverride: TargetPlatform.android),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => createSandboxRuntime(platformOverride: TargetPlatform.iOS),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('bleibt auf Desktop erreichbar', () {
      expect(() => createSandboxRuntime(platformOverride: TargetPlatform.linux), returnsNormally);
    });
  });
}
