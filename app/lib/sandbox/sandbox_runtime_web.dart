/// Web-Implementierung der Werkbank-Sandbox (SUB-318, docs/27 Ticket 5):
/// generierter Code laeuft in einem eigenen, same-origin `<iframe
/// sandbox="allow-scripts">` **ohne** `allow-same-origin` - das Iframe
/// bekommt dadurch eine undurchsichtige ("opaque") Origin und hat keinen
/// Zugriff auf Cookies, `localStorage` oder das DOM der Host-Seite.
///
/// Innerhalb des Iframes laeuft der generierte Code nicht direkt im
/// Dokument-Skript, sondern in einem dedizierten Web Worker: nur ein
/// Worker laeuft auf einem eigenen Thread, sodass `worker.terminate()`
/// eine haengende/endlose Schleife wirklich hart beendet. Ein Timer im
/// Iframe-Hauptdokument (das selbst nur den Worker startet und auf dessen
/// Antwort wartet, nie selbst rechnet) bleibt dafuer reaktionsfaehig und
/// erzwingt das 300-ms-Budget. Ein reiner Timer im Iframe-Hauptthread
/// allein wuerde bei einer synchron endlosen Schleife *im selben Thread*
/// nie feuern - deshalb der Worker, nicht nur der Iframe.
///
/// Netzwerkzugriff wird zusaetzlich durch eine Content-Security-Policy im
/// Iframe-Dokument blockiert (`default-src 'none'`), weil das
/// `sandbox`-Attribut allein `fetch`/`XMLHttpRequest`-Aufrufe *nicht*
/// unterbindet - nur Navigation, Formulare, Popups und (ohne
/// `allow-same-origin`) den Zugriff auf Storage/Cookies/DOM der Host-Seite.
/// Kommunikation ausschliesslich per `postMessage` mit demselben
/// JSON-Vertrag wie auf Mobile/Desktop (`sandbox_runtime_io.dart`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'sandbox_envelope.dart';
import 'sandbox_types.dart';

SandboxRuntime createSandboxRuntime() => const WebSandboxRuntime();

class WebSandboxRuntime implements SandboxRuntime {
  const WebSandboxRuntime();

  @override
  Future<Object?> execute(
    String source,
    Object? input, {
    SandboxResourceLimits limits = const SandboxResourceLimits(),
  }) async {
    final iframe = web.HTMLIFrameElement()
      ..sandbox.add('allow-scripts')
      ..loading = 'eager'
      ..style.display = 'none'
      ..srcdoc = _harnessHtml.toJS;

    final completer = Completer<Map<String, dynamic>>();
    late final web.EventListener listener;
    Timer? outerTimeoutTimer;
    var settled = false;

    void finish(Map<String, dynamic> envelope) {
      if (settled) return;
      settled = true;
      outerTimeoutTimer?.cancel();
      web.window.removeEventListener('message', listener);
      iframe.remove();
      completer.complete(envelope);
    }

    listener = ((web.Event event) {
      final message = event as web.MessageEvent;
      // Ohne diese Pruefung wuerden gleichzeitig laufende
      // execute()-Aufrufe sich gegenseitig ihre Antworten stehlen, weil
      // "message" global auf dem Window ausgeloest wird, nicht pro Iframe.
      // Bewusst `JSAny.equals` statt Dart-`==`: `dart:js_interop`-Wrapper
      // wie `web.Window` ueberladen `==` nicht auf JS-Objektidentitaet,
      // sondern fallen auf Dart-Objektidentitaet der jeweiligen
      // Proxy-Instanz zurueck - zwei um dasselbe JS-Fenster gebaute
      // Wrapper (hier `message.source` und `iframe.contentWindow`) sind
      // dann nie `==`, selbst wenn sie dasselbe JS-Objekt referenzieren
      // (per Test in einem echten Headless-Chrome verifiziert: mit `==`
      // schlaegt der Vergleich immer fehl, jede Antwort wird verworfen und
      // `execute()` haengt unbegrenzt).
      final sourceMatches = (message.source as JSAny?)?.equals(iframe.contentWindow).toDart ?? false;
      if (!sourceMatches) return;
      final data = message.data;
      if (data == null) return;
      final raw = (data as JSString).toDart;
      try {
        finish(jsonDecode(raw) as Map<String, dynamic>);
      } on FormatException {
        finish({'ok': false, 'error': 'invalid_envelope'});
      }
    }).toJS;
    web.window.addEventListener('message', listener);

    // Aeusseres Sicherheitsnetz, NICHT die eigentliche Budget-Durchsetzung:
    // die zaehlt erst ab dem inneren Timer in _harnessHtml, der erst startet,
    // nachdem die Harness die Nachricht empfangen hat und den Worker
    // erzeugt. Dieser aeussere Timer muss zusaetzlich die Zeit fuer
    // Iframe-Erzeugung/-Ladevorgang abdecken - bei einem same-origin-
    // isolierten (opaken) Iframe kann Chromes Site Isolation dafuer einen
    // neuen Renderer-Prozess starten, was allein schon einige hundert
    // Millisekunden dauern kann. Er greift nur, falls ueberhaupt keine
    // Antwort ankommt (z. B. das Iframe laedt nie) - das eigentliche
    // 300-ms-Budget fuer die Codeausfuehrung selbst erzwingt ausschliesslich
    // der innere Timer.
    outerTimeoutTimer = Timer(
      Duration(milliseconds: limits.timeoutMs + 5000),
      () => finish({'ok': false, 'error': 'timeout'}),
    );

    void onLoad(web.Event _) {
      iframe.contentWindow?.postMessage(
        jsonEncode({
          'source': source,
          'input': input,
          'timeoutMs': limits.timeoutMs,
        }).toJS,
        '*'.toJS,
      );
    }

    iframe.addEventListener('load', (onLoad).toJS);
    web.document.body!.appendChild(iframe);

    final envelope = await completer.future;
    return decodeSandboxEnvelope(envelope, limits);
  }
}

/// Statisches Harness-Dokument fuer das sandboxed Iframe. Enthaelt keinerlei
/// vom Nutzer/Modell beeinflussten Text als Markup oder Skript - `source`
/// und `input` kommen ausschliesslich per `postMessage` nach dem Laden und
/// werden im Worker nur als Programmtext bzw. JSON-Literal gespliced, nie in
/// dieses HTML-Dokument selbst eingesetzt.
const String _harnessHtml = r'''
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' blob:; worker-src blob:; connect-src 'none';">
</head>
<body>
<script>
"use strict";
window.addEventListener("message", function (event) {
  var msg;
  try {
    msg = JSON.parse(event.data);
  } catch (e) {
    return;
  }

  function reply(envelope) {
    event.source.postMessage(JSON.stringify(envelope), "*");
  }

  var inputJson = JSON.stringify(msg.input === undefined ? null : msg.input);
  var timeoutMs = msg.timeoutMs || 300;

  var workerLines = [
    "(function () {",
    "  try {",
    "    " + msg.source,
    "    if (typeof execute !== 'function') {",
    "      self.postMessage(JSON.stringify({ok: false, error: 'no_execute_function'}));",
    "      return;",
    "    }",
    "    var output = execute(" + inputJson + ");",
    "    self.postMessage(JSON.stringify({ok: true, output: output === undefined ? null : output}));",
    "  } catch (err) {",
    "    self.postMessage(JSON.stringify({ok: false, error: String((err && err.message) || err)}));",
    "  }",
    "})();",
  ];
  var blob = new Blob([workerLines.join("\n")], {type: "text/javascript"});
  var url = URL.createObjectURL(blob);

  var worker;
  try {
    worker = new Worker(url);
  } catch (e) {
    URL.revokeObjectURL(url);
    reply({ok: false, error: "no_execute_function"});
    return;
  }

  var settled = false;
  var timer = setTimeout(function () {
    if (settled) return;
    settled = true;
    worker.terminate();
    URL.revokeObjectURL(url);
    reply({ok: false, error: "timeout"});
  }, timeoutMs);

  worker.onmessage = function (e) {
    if (settled) return;
    settled = true;
    clearTimeout(timer);
    worker.terminate();
    URL.revokeObjectURL(url);
    try {
      reply(JSON.parse(e.data));
    } catch (parseErr) {
      reply({ok: false, error: "invalid_envelope"});
    }
  };
  worker.onerror = function (e) {
    if (settled) return;
    settled = true;
    clearTimeout(timer);
    worker.terminate();
    URL.revokeObjectURL(url);
    reply({ok: false, error: String(e.message || "worker_error")});
  };
});
</script>
</body>
</html>
''';
