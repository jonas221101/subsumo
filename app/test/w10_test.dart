import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/design/design.dart';
import 'package:subsumo/pages/account_page.dart';
import 'package:subsumo/pages/examen_page.dart';
import 'package:subsumo/pages/gutachten_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/text_schutz.dart';
import 'package:subsumo/theme.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Normzitate bekommen geschuetzte Leerzeichen', () {
    expect(normUmbruchschutz('nach § 123 Abs. 2 BGB'), 'nach § 123 Abs. 2 BGB');
    expect(normUmbruchschutz('§§ 139, 140 BGB'), '§§ 139, 140 BGB');
    expect(normUmbruchschutz('Art. 11a PAG'), 'Art. 11a PAG');
    expect(normUmbruchschutz('S. aber unten'), 'S. aber unten');
  });

  test('Reife-Formel wird lesbar', () {
    expect(
      reifeGewichtung('0.41 x wissen + 0.12 x landesrecht + 0.29 x anwendung + 0.18 x klausurpraxis'),
      'Gewichtung: Wissen 41 %, Landesrecht 12 %, Anwendung 29 %, Klausurpraxis 18 %.',
    );
    expect(reifeGewichtung(''), '');
  });

  testWidgets('Fall am Handy: Abgabe-Button sichtbar ohne Scrollen, Ergebnis wird angezeigt',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var submitted = false;
    final client = MockClient((r) async {
      if (r.url.path == '/v1/cases/zr-x') {
        return _json({'slug': 'zr-x', 'title': 'Fall', 'facts': 'S' * 900, 'question': 'Anspruch?'});
      }
      if (r.url.path == '/v1/cases/zr-x/submit') {
        submitted = true;
        return _json({
          'points': 11.0,
          'note': 'vollbefriedigend',
          'summary': 'ok',
          'pruefpunkte': [],
        }, 201);
      }
      return _json({}, 404);
    });
    final state = AppState(api: ApiClient(client: client)..setToken('t'));
    await tester.pumpWidget(AppScope(
      notifier: state,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const GutachtenPage(caseSlug: 'zr-x', caseTitle: 'Fall'),
      ),
    ));
    await tester.pumpAndSettle();
    // Langer Sachverhalt: der Editor liegt unterhalb, der Button bleibt sichtbar.
    expect(tester.getRect(find.text('Abgeben und bewerten lassen')).bottom, lessThanOrEqualTo(844));
    await tester.scrollUntilVisible(find.byType(TextField), 300, scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField), 'A hat gegen B einen Anspruch. ' * 4);
    await tester.pump(const Duration(seconds: 1));
    final button = find.text('Abgeben und bewerten lassen');
    expect(button, findsOneWidget);
    final rect = tester.getRect(button);
    expect(rect.bottom, lessThanOrEqualTo(844));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(submitted, isTrue);
  });

  testWidgets('Lernprofil: Bestaetigung erscheint nach dem Ruecksprung ins Konto', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = MockClient((r) async {
      switch (r.url.path) {
        case '/v1/examen/cockpit':
          return _json({'lernprofil': {'semester': 3}, 'themen': [], 'profil': {}});
        case '/v1/examen/bundeslaender':
          return _json([{'code': 'BY', 'name': 'Bayern'}]);
        case '/v1/examen/universitaeten':
          return _json([]);
        case '/v1/me/lernprofil':
          return _json({...jsonDecode(r.body) as Map, 'eingerichtet': true});
        case '/v1/auth/me':
          return _json({'id': 1, 'email': 'a@b.de'});
      }
      return _json({}, 404);
    });
    final state = AppState(api: ApiClient(client: client)..setToken('t'));
    await tester.pumpWidget(AppScope(
      notifier: state,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const AccountPage()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lernprofil'));
    await tester.pumpAndSettle();
    final speichern = find.widgetWithText(SubsumoButton, 'Speichern');
    await tester.scrollUntilVisible(speichern, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(speichern);
    await tester.pumpAndSettle();
    expect(find.byType(AccountPage), findsOneWidget);
    expect(find.text('Gespeichert: Bundesland, Universität und Lernprofil.'), findsOneWidget);
  });
}
