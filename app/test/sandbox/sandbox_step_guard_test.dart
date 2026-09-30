import 'package:flutter_test/flutter_test.dart';
import 'package:subsumo/sandbox/sandbox_step_guard.dart';

void main() {
  test('instrumentStepLimit fuegt __stepGuard() an den Kopf von for/while/do-Rumpfen ein', () {
    final result = instrumentStepLimit(
      'function execute(input) {\n'
      '  for (var i = 0; i < 10; i++) { doSomething(); }\n'
      '  while (x) { doSomething(); }\n'
      '  do { doSomething(); } while (x);\n'
      '}',
      5,
    );
    expect(result, contains('function __stepGuard()'));
    expect(result, contains('if (++__steps > 5)'));
    expect(result, contains(stepLimitErrorMarker));
    expect(RegExp(r'for \(var i = 0; i < 10; i\+\+\) \{ __stepGuard\(\);').hasMatch(result), isTrue);
    expect(RegExp(r'while \(x\) \{ __stepGuard\(\);').hasMatch(result), isTrue);
    expect(RegExp(r'do \{ __stepGuard\(\);').hasMatch(result), isTrue);
  });

  test('instrumentStepLimit laesst Schleifen ohne geschweiften Rumpf unveraendert (dokumentierte Grenze)', () {
    final result = instrumentStepLimit('function execute(input) { for (;;) doSomething(); }', 5);
    expect(result, contains('for (;;) doSomething();'));
    expect(result, isNot(contains('__stepGuard(); doSomething()')));
  });

  test('instrumentStepLimit laesst "for"/"while"/"do" in Strings, Templates und Kommentaren unveraendert', () {
    const source = '''
function execute(input) {
  // for while do als Kommentartext
  /* auch hier: for while do */
  var s = "for (;;) while (;;) do";
  var t = 'while(true){}';
  var u = `do { } while (true)`;
  return s + t + u;
}
''';
    final result = instrumentStepLimit(source, 5);
    expect(result, contains('"for (;;) while (;;) do"'));
    expect(result, contains("'while(true){}'"));
    expect(result, contains('`do { } while (true)`'));
    // Ausserhalb der drei Schleifen-Schluesselworte im String-/Template-Text
    // gibt es keine echte Schleife im Quelltext - keine Instrumentierung.
    expect('__stepGuard();'.allMatches(result).length, 0);
  });

  test('instrumentStepLimit erkennt for/while/do nicht als Praefix laengerer Bezeichner', () {
    final result = instrumentStepLimit(
      'function execute(input) { forEach(); doSomething(); whileTrue(); return 1; }',
      5,
    );
    expect(result, contains('forEach(); doSomething(); whileTrue();'));
  });

  test('instrumentStepLimit verschachtelt korrekt bei geschachtelten Schleifen', () {
    final result = instrumentStepLimit(
      'function execute(input) { for (var i = 0; i < 2; i++) { for (var j = 0; j < 2; j++) { doSomething(); } } }',
      5,
    );
    final guardCount = RegExp(r'__stepGuard\(\);').allMatches(result).length;
    // Je 1x fuer die aeussere und die innere Schleife - die Definition von
    // `__stepGuard` selbst ruft sich nicht auf, taucht darum hier nicht auf.
    expect(guardCount, 2);
  });
}
