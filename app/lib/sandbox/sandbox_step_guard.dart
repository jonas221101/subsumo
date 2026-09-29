/// Interpreter-Schrittzaehler als Rueckfallgrenze (docs/27 Abschnitt 1.1:
/// "Interpreter-Schrittzaehler als Rueckfallgrenze gegen Endlosschleifen, die
/// innerhalb von 300 ms viele kurze Yield-Punkte erzeugen"). Folgearbeit aus
/// SUB-359 zu SUB-318/PR #94.
///
/// Kein natives QuickJS-Feature: `sandbox_runtime_io.dart` dokumentiert den
/// empirisch bestaetigten Befund, dass der `timeout`-Parameter (und damit der
/// zugrunde liegende `JS_SetInterruptHandler`) auf dieser Plattform bei einer
/// echten synchronen Endlosschleife NICHT greift - ein Wall-Clock-Hard-Kill
/// braucht dafuer Prozess- oder OS-Thread-Isolation von aussen. Seit SUB-382
/// per Prozessisolation umgesetzt (`sandbox_worker_main.dart`); der
/// Schrittzaehler hier bleibt trotzdem sinnvoll als schnellerer,
/// kooperativer Fehlerpfad (ein JS-seitiger Abbruch ist billiger als das
/// volle `timeoutMs`-Budget abzuwarten und den Worker-Prozess extern zu
/// killen) und deckt eine andere Klasse von Endlosschleifen ab: er
/// instrumentiert den Quelltext selbst, bevor er an die Engine geht, statt
/// sich auf eine Interpreter-Kooperation zu verlassen - jede `for`/`while`/
/// `do`-Schleife mit geschweiftem Rumpf bekommt an ihrem Kopf einen
/// Zaehler-Aufruf, der bei Ueberschreitung von `maxSteps` wirft. Das
/// funktioniert unabhaengig von der Engine (QuickJS, JavaScriptCore,
/// Web-Worker) und der Plattform, weil es reine Quelltext-Transformation ist.
///
/// Bewusst nicht abgedeckt (Rueckfallgrenze, kein Ersatz fuer den
/// Wall-Clock-Hard-Kill):
/// - Rekursion ohne Schleifenkonstrukt.
/// - Iteration ueber `Array.prototype.forEach`/`map`/`reduce` u.ae.
///   Callback-basierte Methoden.
/// - Schleifen ohne geschweiften Rumpf (`for (;;) tu_was();`) - werden
///   unveraendert durchgereicht statt riskant per Text geraten zu werden;
///   generierter Code aus der Werkbank verwendet durchgehend geschweifte
///   Rumpfe (siehe bestehende Testfaelle).
/// - Verschleierung durch dynamisch aus Strings gebauten Code: `Function(...)`
///   ist nicht erreichbar (nicht in der Baseline-Allowlist aus
///   `sandbox_runtime_io.dart`), `eval` bleibt zwar erreichbar, fuehrt aber
///   nur unsinstrumentierten Code aus seinem eigenen String aus - dieselbe
///   Luecke wie jeder Text-Instrumentierungsansatz ohne echten Parser.
library;

/// Fehlermeldungstext, den `__stepGuard()` wirft, wenn [maxSteps]
/// ueberschritten wird. Beide Harnesses (`sandbox_runtime_io.dart`,
/// potenziell `sandbox_runtime_web.dart`) liefern eine Engine-Exception als
/// `{ok: false, error: String(e.message)}` zurueck - `classifySandboxError`
/// in `sandbox_envelope.dart` ordnet genau diesen Text
/// [SandboxErrorClass.stepLimitExceeded] zu, nicht `runtimeError`.
const String stepLimitErrorMarker = '__sandbox_step_limit_exceeded__';

/// Instrumentiert [source]: fuegt am Kopf jedes `for`/`while`/`do`-Rumpfs
/// (sofern geschweift) einen Aufruf von `__stepGuard()` ein, der bei
/// Ueberschreitung von [maxSteps] eine `Error` mit Nachricht
/// [stepLimitErrorMarker] wirft. String-, Template-Literale und Kommentare
/// werden unveraendert kopiert, damit `for`/`while`/`do` als Text darin keine
/// falschen Treffer erzeugt.
String instrumentStepLimit(String source, int maxSteps) {
  final buffer = StringBuffer()
    ..writeln('var __steps = 0;')
    ..writeln('function __stepGuard() {')
    ..writeln('  if (++__steps > $maxSteps) { throw new Error("$stepLimitErrorMarker"); }')
    ..writeln('}')
    ..write(_instrumentLoops(source));
  return buffer.toString();
}

bool _isIdentifierStart(String c) => RegExp(r'[A-Za-z_$]').hasMatch(c);

bool _isIdentifierChar(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

String _instrumentLoops(String source) {
  final out = StringBuffer();
  final n = source.length;
  var i = 0;
  while (i < n) {
    final ch = source[i];

    if (ch == '"' || ch == "'" || ch == '`') {
      i = _copyStringLiteral(source, i, out);
      continue;
    }
    if (ch == '/' && i + 1 < n && source[i + 1] == '/') {
      i = _copyLineComment(source, i, out);
      continue;
    }
    if (ch == '/' && i + 1 < n && source[i + 1] == '*') {
      i = _copyBlockComment(source, i, out);
      continue;
    }

    if (_isIdentifierStart(ch)) {
      final start = i;
      var j = i;
      while (j < n && _isIdentifierChar(source[j])) {
        j++;
      }
      final word = source.substring(start, j);
      out.write(word);
      i = j;
      if (word == 'for' || word == 'while') {
        i = _skipWhitespaceAndComments(source, i, out);
        if (i < n && source[i] == '(') {
          final closeParen = _matchDelimiter(source, i, '(', ')');
          out.write(source.substring(i, closeParen + 1));
          i = closeParen + 1;
          i = _writeBody(source, i, out);
        }
      } else if (word == 'do') {
        i = _writeBody(source, i, out);
      }
      continue;
    }

    out.write(ch);
    i++;
  }
  return out.toString();
}

/// Kopiert ab `i` (auf dem oeffnenden Anfuehrungszeichen) einen String- oder
/// Template-Literal unveraendert, respektiert `\`-Escapes. Gibt den Index
/// direkt nach dem schliessenden Anfuehrungszeichen zurueck.
int _copyStringLiteral(String source, int i, StringBuffer out) {
  final quote = source[i];
  final n = source.length;
  out.write(quote);
  i++;
  while (i < n) {
    final c = source[i];
    if (c == r'\' && i + 1 < n) {
      out.write(c);
      out.write(source[i + 1]);
      i += 2;
      continue;
    }
    out.write(c);
    i++;
    if (c == quote) break;
  }
  return i;
}

int _copyLineComment(String source, int i, StringBuffer out) {
  final end = source.indexOf('\n', i);
  final stop = end == -1 ? source.length : end;
  out.write(source.substring(i, stop));
  return stop;
}

int _copyBlockComment(String source, int i, StringBuffer out) {
  final end = source.indexOf('*/', i + 2);
  final stop = end == -1 ? source.length : end + 2;
  out.write(source.substring(i, stop));
  return stop;
}

int _skipWhitespaceAndComments(String source, int i, StringBuffer out) {
  final n = source.length;
  while (i < n) {
    final c = source[i];
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      out.write(c);
      i++;
      continue;
    }
    if (c == '/' && i + 1 < n && source[i + 1] == '/') {
      i = _copyLineComment(source, i, out);
      continue;
    }
    if (c == '/' && i + 1 < n && source[i + 1] == '*') {
      i = _copyBlockComment(source, i, out);
      continue;
    }
    break;
  }
  return i;
}

/// Findet ab `openIdx` (auf `openChar`) das zugehoerige `closeChar`,
/// respektiert dabei Klammertiefe sowie String-Literale und Kommentare
/// dazwischen (z. B. `for (var i = 0; i < "x)".length; i++)`).
int _matchDelimiter(String source, int openIdx, String openChar, String closeChar) {
  var depth = 0;
  final n = source.length;
  var i = openIdx;
  while (i < n) {
    final c = source[i];
    if (c == '"' || c == "'" || c == '`') {
      i = _copyStringLiteral(source, i, StringBuffer());
      continue;
    }
    if (c == '/' && i + 1 < n && source[i + 1] == '/') {
      final end = source.indexOf('\n', i);
      i = end == -1 ? n : end;
      continue;
    }
    if (c == '/' && i + 1 < n && source[i + 1] == '*') {
      final end = source.indexOf('*/', i + 2);
      i = end == -1 ? n : end + 2;
      continue;
    }
    if (c == openChar) depth++;
    if (c == closeChar) {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return n - 1;
}

/// Schreibt den Rumpf einer Schleife ab `i` (nach dem Kopf/`(...)` bzw. nach
/// `do`). Nur geschweifte Rumpfe werden instrumentiert - ein Rumpf ohne `{}`
/// wird unveraendert durchgereicht (siehe Dateikommentar, "bewusst nicht
/// abgedeckt"), verschachtelte Schleifen darin werden trotzdem erkannt, weil
/// die Kontrolle danach an den regulaeren Zeichen-fuer-Zeichen-Durchlauf
/// zurueckgeht.
int _writeBody(String source, int i, StringBuffer out) {
  i = _skipWhitespaceAndComments(source, i, out);
  if (i < source.length && source[i] == '{') {
    final closeBrace = _matchDelimiter(source, i, '{', '}');
    out.write('{ __stepGuard();');
    // Rekursiv statt der rohen Teilzeichenkette: sonst wuerden verschachtelte
    // Schleifen innerhalb dieses geschweiften Rumpfs nie instrumentiert, weil
    // sie hier direkt kopiert und nicht mehr vom Zeichen-fuer-Zeichen-
    // Durchlauf in [_instrumentLoops] gesehen wuerden.
    out.write(_instrumentLoops(source.substring(i + 1, closeBrace)));
    out.write('}');
    return closeBrace + 1;
  }
  return i;
}
