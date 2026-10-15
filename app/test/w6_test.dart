import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/design/design.dart';
import 'package:subsumo/pages/account_page.dart';
import 'package:subsumo/pages/gutachten_page.dart';
import 'package:subsumo/pages/landesbezug.dart';
import 'package:subsumo/pages/lernprofil_page.dart';
import 'package:subsumo/pages/public/public_legal_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Fall-Kopfzeile zeigt langen Titel bei 390 px ungekuerzt', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const titel = 'Aufrechnung und Scheckzahlung beim Werklohn';
    final client = MockClient((request) async {
      if (request.url.path == '/v1/cases/zr-lang') {
        return _json({'slug': 'zr-lang', 'title': titel, 'facts': 'x', 'question': 'y?'});
      }
      return _json({}, 404);
    });
    final state = AppState(api: ApiClient(client: client)..setToken('t'));
    await tester.pumpWidget(AppScope(
      notifier: state,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const GutachtenPage(caseSlug: 'zr-lang', caseTitle: titel),
      ),
    ));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.descendant(of: find.byType(AppBar), matching: find.text(titel)));
    final box = tester.renderObject<RenderBox>(find.descendant(of: find.byType(AppBar), matching: find.text(titel)));
    final painter = TextPainter(
      text: TextSpan(text: titel, style: text.style),
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: box.size.width);
    expect(painter.didExceedMaxLines, isFalse);
    expect(box.size.height, lessThanOrEqualTo(88));
    expect(tester.takeException(), isNull);
  });

  test('Laenderkuerzel-Aliasse in der Suche', () {
    expect(suchRang('NRW', landesSuchtext('NW')), 0);
    expect(suchRang('nw', landesSuchtext('NW')), 0);
    expect(suchRang('RLP', landesSuchtext('RP')), 0);
    expect(suchRang('LSA', landesSuchtext('ST')), 0);
    expect(suchRang('BY', landesSuchtext('BY')), 0);
    expect(suchRang('Bayern', landesSuchtext('BY')), 0);
    expect(suchRang('NRW', landesSuchtext('BY')), isNull);
  });

  testWidgets('Beta-Rechtsseite: Zurueck-Pfeil, kein Anmelden, kein Footer', (tester) async {
    for (final slug in ['impressum', 'agb', 'datenschutz']) {
      await tester.pumpWidget(MaterialApp.router(
        theme: buildTheme(Brightness.light),
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, __) => PublicLegalPage(slug: slug, betaMode: true)),
        ]),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('legal-back')), findsOneWidget);
      expect(find.text('Anmelden'), findsNothing);
      expect(find.text('Cookie-Hinweis'), findsNothing);
      expect(find.text('Privater Testzugang'), findsOneWidget);
    }
  });

  testWidgets('Konto-Kopfzeile ohne Lernprofil-Icon', (tester) async {
    final state = AppState(api: ApiClient(client: MockClient((_) async => _json({}, 404)))..setToken('t'));
    await tester.pumpWidget(AppScope(
      notifier: state,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const AccountPage()),
    ));
    await tester.pump();
    expect(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.tune_outlined)), findsNothing);
  });

  testWidgets('Lernprofil: ein Speichern sichert Bundesland/Uni und Profil', (tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = <http.Request>[];
    final client = MockClient((r) async {
      requests.add(r);
      switch (r.url.path) {
        case '/v1/examen/bundeslaender':
          return _json([{'code': 'NW', 'name': 'Nordrhein-Westfalen'}]);
        case '/v1/examen/universitaeten':
          return _json([]);
        case '/v1/me/lernprofil':
          return _json({...jsonDecode(r.body) as Map, 'eingerichtet': true});
        case '/v1/auth/me':
          return _json({'id': 1, 'email': 'a@b.de'});
        case '/v1/examen/cockpit':
          return _json({'profil': {}});
      }
      return _json({'profil': {}});
    });
    final state = AppState(api: ApiClient(client: client)..setToken('t'));
    await tester.pumpWidget(AppScope(
      notifier: state,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const LernprofilPage(profil: {'semester': 3}, themen: []),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SubsumoButton, 'Speichern'), findsOneWidget);
    expect(find.text('Lernprofil speichern'), findsNothing);
    await tester.tap(find.widgetWithText(SubsumoButton, 'Speichern'));
    await tester.pumpAndSettle();

    expect(requests.any((r) => r.method == 'PUT' && r.url.path == '/v1/me/lernprofil'), isTrue);
    // Ohne Aenderung an Bundesland/Uni wird dort nichts ueberschrieben.
    expect(requests.any((r) => r.method == 'PATCH'), isFalse);
  });

  testWidgets('Lernprofil: geaendertes Bundesland wird mit demselben Speichern gesichert', (tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = <http.Request>[];
    final client = MockClient((r) async {
      requests.add(r);
      switch (r.url.path) {
        case '/v1/examen/bundeslaender':
          return _json([{'code': 'NW', 'name': 'Nordrhein-Westfalen'}]);
        case '/v1/examen/universitaeten':
          return _json([]);
        case '/v1/me/lernprofil':
          return _json({...jsonDecode(r.body) as Map, 'eingerichtet': true});
        case '/v1/auth/me':
          return _json({'id': 1, 'email': 'a@b.de'});
      }
      return _json({'profil': {}});
    });
    final state = AppState(api: ApiClient(client: client)..setToken('t'));
    await tester.pumpWidget(AppScope(
      notifier: state,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const LernprofilPage(profil: {'semester': 3}, themen: []),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bundesland')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nordrhein-Westfalen').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SubsumoButton, 'Speichern'));
    await tester.pumpAndSettle();

    final patch = requests.singleWhere((r) => r.method == 'PATCH');
    expect(jsonDecode(patch.body)['bundesland'], 'NW');
    expect(requests.any((r) => r.method == 'PUT' && r.url.path == '/v1/me/lernprofil'), isTrue);
  });

  testWidgets('Lernprofil am Handy: Bundesland bleibt nach Scrollen zum Speichern erhalten',
      (tester) async {
    // Regression Welle 7: In einer ListView wurde der Bundesland-Editor beim
    // Scrollen verworfen und das Bundesland still nicht gespeichert.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = <http.Request>[];
    final client = MockClient((r) async {
      requests.add(r);
      switch (r.url.path) {
        case '/v1/examen/bundeslaender':
          return _json([{'code': 'NW', 'name': 'Nordrhein-Westfalen'}]);
        case '/v1/examen/universitaeten':
          return _json([]);
        case '/v1/me/lernprofil':
          return _json({...jsonDecode(r.body) as Map, 'eingerichtet': true});
        case '/v1/auth/me':
          return _json({'id': 1, 'email': 'a@b.de'});
      }
      return _json({'profil': {}});
    });
    final state = AppState(api: ApiClient(client: client)..setToken('t'));
    await tester.pumpWidget(AppScope(
      notifier: state,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const LernprofilPage(profil: {'semester': 3}, themen: []),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bundesland')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nordrhein-Westfalen').last);
    await tester.pumpAndSettle();
    final speichern = find.widgetWithText(SubsumoButton, 'Speichern');
    await tester.scrollUntilVisible(speichern, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(speichern);
    await tester.pumpAndSettle();

    final patch = requests.singleWhere((r) => r.method == 'PATCH');
    expect(jsonDecode(patch.body)['bundesland'], 'NW');
  });
}
