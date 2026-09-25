import 'package:flutter_test/flutter_test.dart';
import 'package:subsumo/sandbox/sandbox_envelope.dart';
import 'package:subsumo/sandbox/sandbox_types.dart';

void main() {
  const limits = SandboxResourceLimits(maxOutputBytes: 16);

  test('decodeSandboxEnvelope gibt output bei ok:true zurueck', () {
    final output = decodeSandboxEnvelope({'ok': true, 'output': 3}, limits);
    expect(output, 3);
  });

  test('decodeSandboxEnvelope wirft invalidOutput ueber max_output_bytes', () {
    expect(
      () => decodeSandboxEnvelope({'ok': true, 'output': 'x' * 100}, limits),
      throwsA(
        isA<SandboxException>().having(
          (e) => e.errorClass,
          'errorClass',
          SandboxErrorClass.invalidOutput,
        ),
      ),
    );
  });

  test('decodeSandboxEnvelope wirft die klassifizierte Fehlerklasse bei ok:false', () {
    expect(
      () => decodeSandboxEnvelope({'ok': false, 'error': 'timeout'}, limits),
      throwsA(
        isA<SandboxException>().having(
          (e) => e.errorClass,
          'errorClass',
          SandboxErrorClass.timeout,
        ),
      ),
    );
  });

  test('classifySandboxError ordnet die festen Fehlercodes beider Harnesses zu', () {
    expect(classifySandboxError('timeout'), SandboxErrorClass.timeout);
    expect(classifySandboxError('no_execute_function'), SandboxErrorClass.runtimeError);
    expect(classifySandboxError('worker_error'), SandboxErrorClass.runtimeError);
    expect(classifySandboxError('invalid_envelope'), SandboxErrorClass.invalidOutput);
    expect(classifySandboxError('irgendwas_unbekanntes'), SandboxErrorClass.runtimeError);
    expect(classifySandboxError(null), SandboxErrorClass.runtimeError);
  });
}
