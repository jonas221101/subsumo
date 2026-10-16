// Entwurf-Autosave, veraltetes Ergebnis und Klausur-Countdown im Fall-Screen.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/pages/gutachten_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

final _text = 'Text zum Fall. ' * 10;

MockClient _client() => MockClient((request) async {
      if (request.url.path == '/v1/cases/f1') {
        return _json({'slug': 'f1', 'title': 'F', 'facts': 'f', 'question': 'q', 'minutes': 90});
      }
      if (request.url.path == '/v1/public/config') return _json({});
      if (request.url.path.endsWith('/submit')) {
        return _json({
          'evaluation': {
            'points': 9,
            'note': 'gut',
            'summary': 'Zusammenfassung',
            'disclaimer': 'd',
            'checkpoints': <Object>[],
          },
        }, 201);
      }
      return _json({'score': 50, 'findings': [], 'counts': {}});
    });

Widget _app(AppState state, Widget home) => AppScope(
      notifier: state,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Entwurf wird gespeichert, wiederhergestellt und nach Abgabe geloescht', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(api: ApiClient(client: _client())..setToken('t'));
    await tester.pumpWidget(_app(state, const GutachtenPage(caseSlug: 'f1', caseTitle: 'F')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), _text);
    await tester.pump(const Duration(milliseconds: 900));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('gutachten_entwurf_f1'), _text);

    // Neu oeffnen: Text kommt zurueck.
    await tester.pumpWidget(_app(state, const SizedBox()));
    await tester.pumpWidget(_app(state, const GutachtenPage(caseSlug: 'f1', caseTitle: 'F')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, _text);

    // Abgabe loescht den Entwurf; Aenderung danach markiert das Ergebnis veraltet.
    await tester.tap(find.text('Abgeben und bewerten lassen'));
    await tester.pumpAndSettle();
    expect(prefs.getString('gutachten_entwurf_f1'), isNull);
    expect(find.text('9 Punkte · gut'), findsOneWidget);
    expect(find.text('Ergebnis veraltet'), findsNothing);

    await tester.enterText(find.byType(TextField), '$_text mehr');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Ergebnis veraltet'), findsOneWidget);
    expect(find.text('9 Punkte · gut'), findsNothing);
    expect(find.text('Struktur'), findsOneWidget);
  });

  testWidgets('Zurueck-Pfeil behaelt den Entwurf und meldet es', (tester) async {
    final state = AppState(api: ApiClient(client: _client())..setToken('t'));
    await tester.pumpWidget(_app(
      state,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const GutachtenPage(caseSlug: 'f1', caseTitle: 'F'))),
            child: const Text('öffnen'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), _text);
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Entwurf gespeichert'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('gutachten_entwurf_f1'), _text);
  });

  testWidgets('Klausurmodus zeigt Countdown aus Fall-Minuten', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(api: ApiClient(client: _client())..setToken('t'));
    await tester.pumpWidget(
        _app(state, const GutachtenPage(caseSlug: 'f1', caseTitle: 'F', mode: 'klausur')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('klausur-timer')), findsOneWidget);
    expect(find.textContaining('Verbleibende Zeit: 01:29:'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
