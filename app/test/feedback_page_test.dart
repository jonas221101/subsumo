// Feedback-Seite (docs/35-geschlossene-testphase.md): Kategorie waehlen,
// Text schicken, Bestaetigung sehen, eigene Rueckmeldungen lesen.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/design/design.dart';
import 'package:subsumo/pages/feedback_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<List<http.Request>> pump(WidgetTester tester, {int sendStatus = 201}) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <http.Request>[];
    final gesendet = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/v1/feedback' && request.method == 'POST') {
        if (sendStatus != 201) return _json({'detail': 'Tageslimit erreicht'}, sendStatus);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        gesendet.insert(0, {
          'id': gesendet.length + 1,
          ...body,
          'created_at': '2026-10-14T10:00:00+00:00',
          'erledigt': false,
        });
        return _json(gesendet.first, 201);
      }
      if (request.url.path == '/v1/feedback/mine') return _json(gesendet);
      return _json({'detail': 'nicht gemockt'}, 404);
    });
    final state = AppState(api: ApiClient(client: client));
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const FeedbackPage(context: 'Karten'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return requests;
  }

  testWidgets('schickt Kategorie, Text, Kontext und Plattform und zeigt die Liste', (tester) async {
    final requests = await pump(tester);

    expect(find.text('Was ist dir aufgefallen?'), findsOneWidget);
    expect(find.text('Stelle in der App: Karten'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Inhalt'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Bei § 263 fehlt der Dreiecksbetrug.');
    await tester.tap(find.widgetWithText(SubsumoButton, 'Rückmeldung senden'));
    await tester.pumpAndSettle();

    final post = requests.singleWhere((r) => r.method == 'POST');
    final body = jsonDecode(post.body) as Map<String, dynamic>;
    expect(body['category'], 'inhalt');
    expect(body['message'], 'Bei § 263 fehlt der Dreiecksbetrug.');
    expect(body['context'], 'Karten');
    expect(body['platform'], isNotEmpty);
    expect(body['app_version'], kAppVersion);
    expect(find.text('Danke - deine Rückmeldung ist angekommen.'), findsOneWidget);
    // Eigene Rueckmeldung erscheint in der Liste, das Feld ist wieder leer.
    expect(find.byType(SubsumoEyebrow), findsNWidgets(2)); // Kopf + Liste
    expect(find.text('Bei § 263 fehlt der Dreiecksbetrug.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('leerer Text wird nicht gesendet, Serverfehler wird angezeigt', (tester) async {
    final requests = await pump(tester, sendStatus: 429);

    await tester.tap(find.widgetWithText(SubsumoButton, 'Rückmeldung senden'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte mindestens drei Zeichen'), findsOneWidget);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);

    await tester.enterText(find.byType(TextField), 'Noch ein Hinweis');
    await tester.tap(find.widgetWithText(SubsumoButton, 'Rückmeldung senden'));
    await tester.pumpAndSettle();
    expect(find.text('Tageslimit erreicht'), findsOneWidget);
  });
}
