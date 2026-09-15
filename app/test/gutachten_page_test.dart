// F1 (docs/20-release-g2-bezahlstrecke.md Abschnitt 4): Limit-Antworten
// (402/403 mit upgrade_required, siehe B2) zeigen einen Upgrade-Hinweis statt
// eines generischen Fehlers oder Absturzes - auf Fallebene (blockiert die
// ganze Seite) und auf Analyseebene (blockiert nur das Strukturfeedback).
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

http.Response _json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

const _case = {
  'slug': 'zr-dritter-fall',
  'title': 'Dritter Fall',
  'facts': 'A verkauft B ein Fahrrad.',
  'question': 'Hat B einen Anspruch?',
};

Future<void> _pump(WidgetTester tester, AppState state, {String slug = 'zr-dritter-fall'}) async {
  await tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: GutachtenPage(caseSlug: slug, caseTitle: 'Dritter Fall'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Free-Limit auf den Fall zeigt einen Upgrade-Hinweis statt der Seite',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/cases/zr-dritter-fall') {
        return _json({
          'detail': {
            'upgrade_required': true,
            'message': 'Ab dem dritten Fall nur mit Pro.',
          },
        }, 403);
      }
      return _json({}, 404);
    });
    final state = AppState(api: ApiClient(client: client)..setToken('t'));

    await _pump(tester, state);

    expect(find.text('Dieser Fall ist mit Pro verfuegbar.'), findsOneWidget);
    expect(find.text('Ab dem dritten Fall nur mit Pro.'), findsOneWidget);
    // Kein Absturz, kein generischer Fehlertext, kein Editor.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Fall laedt normal, wenn kein Limit erreicht ist', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/cases/zr-dritter-fall') {
        return _json(_case, 200);
      }
      return _json({}, 404);
    });
    final state = AppState(api: ApiClient(client: client)..setToken('t'));

    await _pump(tester, state);

    expect(find.text('Dieser Fall ist mit Pro verfuegbar.'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('A verkauft B ein Fahrrad.'), findsOneWidget);
  });

  testWidgets(
    'Wochenlimit der Strukturanalyse zeigt einen Upgrade-Hinweis, blockiert aber nicht das Schreiben',
    (tester) async {
      final client = MockClient((request) async {
        if (request.url.path == '/v1/cases/zr-dritter-fall') {
          return _json(_case, 200);
        }
        if (request.url.path == '/v1/gutachten/analyze') {
          return _json({
            'detail': {
              'upgrade_required': true,
              'message': 'Diese Woche schon 3 Analysen genutzt. Reset am 2026-09-22.',
            },
          }, 402);
        }
        return _json({}, 404);
      });
      final state = AppState(api: ApiClient(client: client)..setToken('t'));

      await _pump(tester, state);
      await tester.enterText(
        find.byType(TextField),
        'A koennte gegen B einen Anspruch auf Kaufpreiszahlung aus § 433 II BGB haben.',
      );
      // Debounce (700ms) abwarten, bis der Analyse-Request feuert.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(
        find.text('Strukturfeedback ist diese Woche mit Free aufgebraucht.'),
        findsOneWidget,
      );
      expect(find.textContaining('Reset am 2026-09-22'), findsOneWidget);
      // Editor bleibt nutzbar - nur das Feedback ist gesperrt.
      expect(find.byType(TextField), findsOneWidget);
    },
  );
}
