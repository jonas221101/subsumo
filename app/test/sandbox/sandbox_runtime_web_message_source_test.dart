/// Regressionstest fuer eine Invariante, auf die sich
/// `WebSandboxRuntime._listener` (sandbox_runtime_web.dart) verlaesst: ohne
/// den Filter auf den Nachrichtenursprung wuerden gleichzeitig laufende
/// `execute()`-Aufrufe sich gegenseitig ihre Antworten stehlen, weil
/// `message`-Events global auf `window` ausgeloest werden, nicht pro
/// Iframe. Verwendet bewusst `JSAny.equals` statt Dart-`==` - Letzteres
/// vergleicht bei `dart:js_interop`-Wrappern nur Dart-Proxy-Identitaet,
/// nicht JS-Objektidentitaet, und schlaegt hier immer fehl (siehe
/// Kommentar in sandbox_runtime_web.dart).
///
/// `dart:js_interop`/`package:web` kompilieren nicht fuer die VM - ohne
/// dieses Tag versucht `flutter test` (VM-Plattform) trotzdem, die Datei zu
/// laden, und bricht mit einem Compile-Fehler ab statt sie zu uebergehen.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('message.source equals iframe.contentWindow after postMessage roundtrip', () async {
    final iframe = web.HTMLIFrameElement()
      ..sandbox.add('allow-scripts')
      ..srcdoc = '''
<html><body><script>
window.addEventListener("message", function (event) {
  event.source.postMessage(JSON.stringify({ok:true, echo: event.data}), "*");
});
</script></body></html>
'''.toJS;

    final completer = Completer<bool>();
    late final web.EventListener listener;
    listener = ((web.Event event) {
      final message = event as web.MessageEvent;
      final matches = (message.source as JSAny?)?.equals(iframe.contentWindow).toDart ?? false;
      if (!completer.isCompleted) completer.complete(matches);
    }).toJS;
    web.window.addEventListener('message', listener);

    void onLoad(web.Event _) {
      iframe.contentWindow?.postMessage(jsonEncode({'hello': 1}).toJS, '*'.toJS);
    }

    iframe.addEventListener('load', (onLoad).toJS);
    web.document.body!.appendChild(iframe);

    final matches = await completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    );
    web.window.removeEventListener('message', listener);
    iframe.remove();
    expect(matches, isTrue, reason: 'JSAny.equals(message.source, iframe.contentWindow) must hold for the reply filter to work');
  });
}
