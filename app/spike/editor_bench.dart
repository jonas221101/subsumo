// Spike (M1, blockierend): Texteditor-Qualitaet fuer den 5-Stunden-
// Klausur-Simulator auf Flutter Web. Siehe docs/07-spike-web-editor.md fuer
// die Auswertung. Kein Teil der App - eigenstaendiger Messaufbau.
//
// Baut ein TextField mit einem realistischen Klausurtext (~5.500 Woerter,
// die Laenge eines langen Examensgutachtens) vor, tippt darauf 400 Zeichen
// hintereinander (wie ein fluessig schreibender Nutzer) und misst pro
// Tastendruck die Zeit bis zum naechsten fertigen Frame.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:web/web.dart' as web;

void main() => runApp(const BenchApp());

String _loremGutachten(int words) {
  const bausteine = [
    'A könnte gegen B einen Anspruch auf Schadensersatz aus § 823 Abs. 1 BGB haben.',
    'Dazu müsste B eine Rechtsgutsverletzung durch eine Handlung verursacht haben.',
    'Eine Eigentumsverletzung ist jede Einwirkung auf die Sachsubstanz oder die',
    'Beeinträchtigung der bestimmungsgemäßen Verwendbarkeit einer Sache.',
    'Hier hat B die Sache des A beschädigt, indem er sie fallen ließ.',
    'Fraglich ist, ob B dabei rechtswidrig und schuldhaft gehandelt hat.',
    'Mithin liegt eine tatbestandsmäßige Rechtsgutsverletzung vor.',
    'Weiterhin könnte ein Anspruch aus § 280 Abs. 1 BGB in Betracht kommen.',
    'Vorliegend ist zwischen den Parteien ein Schuldverhältnis entstanden.',
    'Somit hat A gegen B einen Anspruch auf Ersatz des entstandenen Schadens.',
  ];
  final rnd = Random(42);
  final out = StringBuffer();
  var count = 0;
  while (count < words) {
    final satz = bausteine[rnd.nextInt(bausteine.length)];
    out.write(satz);
    out.write(' ');
    count += satz.split(' ').length;
  }
  return out.toString();
}

class BenchApp extends StatelessWidget {
  const BenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ThemeData(fontFamily: ...) reicht nicht: Material2021-TextThemes tragen
    // 'Roboto' fest im TextStyle, .apply() ist der dokumentierte Weg, das zu
    // ueberschreiben - sonst faellt CanvasKit auf den Google-Fonts-Webfetch
    // zurueck (Spike-Befund 3).
    final base = ThemeData.light();
    final theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'SpikeFont'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'SpikeFont'),
    );
    return MaterialApp(
      theme: theme,
      home: const BenchPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BenchPage extends StatefulWidget {
  const BenchPage({super.key});

  @override
  State<BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<BenchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final List<int> _frameMicros = [];
  bool _running = false;
  String _status = 'bereit';

  @override
  void initState() {
    super.initState();
    _controller.text = _loremGutachten(5500);
    // Bewusst am Ende einfuegen - der ungünstigste Fall: das gesamte
    // vorangegangene Layout muss beim Tippen erhalten/erweitert werden,
    // genau wie am Ende einer laufenden Klausur.
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  Future<void> _runBenchmark() async {
    setState(() {
      _running = true;
      _status = 'laeuft...';
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _focus.requestFocus();

    const zusatztext =
        ' Im Ergebnis ist festzuhalten, dass der Anspruch des A gegen B '
        'sowohl aus vertraglicher als auch aus deliktischer Grundlage '
        'besteht und in voller Hoehe durchsetzbar ist, da keine Einreden '
        'oder Einwendungen des B durchgreifen und die Verjaehrungsfrist '
        'noch nicht abgelaufen ist, sodass A den Anspruch klageweise ';
    _frameMicros.clear();

    for (var i = 0; i < zusatztext.length; i++) {
      final start = DateTime.now();
      final completer = Completer<void>();
      // addPostFrameCallback misst genau das, was ein Nutzer als
      // "Eingabe erscheint" wahrnimmt: den naechsten fertig gerasterten Frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!completer.isCompleted) completer.complete();
      });
      setState(() {
        final text = _controller.text;
        final pos = _controller.selection.baseOffset;
        _controller.text = text.substring(0, pos) +
            zusatztext[i] +
            text.substring(pos);
        _controller.selection = TextSelection.collapsed(offset: pos + 1);
      });
      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      _frameMicros.add(DateTime.now().difference(start).inMicroseconds);
      if (i % 25 == 0) {
        final soFarMs = DateTime.now().difference(start).inMilliseconds;
        // ignore: avoid_print
        print('BENCH_PROGRESS $i/${zusatztext.length} last=${soFarMs}ms');
      }
    }

    final ms = _frameMicros.map((u) => u / 1000).toList()..sort();
    final sum = ms.reduce((a, b) => a + b);
    final result = {
      'keystrokes': ms.length,
      'total_chars_in_document': _controller.text.length,
      'avg_ms': sum / ms.length,
      'p50_ms': ms[ms.length ~/ 2],
      'p95_ms': ms[(ms.length * 0.95).floor()],
      'max_ms': ms.last,
    };
    // In der Browser-Konsole ausgeben - von aussen (Playwright) auslesbar,
    // ohne dass die Bench-Seite selbst irgendeine Server-Anbindung braucht.
    // ignore: avoid_print
    print('BENCH_RESULT ${jsonEncode(result)}');
    web.console.log('BENCH_RESULT ${jsonEncode(result)}'.toJS);

    setState(() {
      _running = false;
      _status = 'fertig: ${result['avg_ms']!.toStringAsFixed(2)} ms/Tastendruck '
          '(p95 ${result['p95_ms']!.toStringAsFixed(2)} ms)';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Editor-Spike – $_status')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton(
                key: const Key('run-benchmark'),
                onPressed: _running ? null : _runBenchmark,
                child: const Text('Benchmark starten'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
        ),
      );
}
