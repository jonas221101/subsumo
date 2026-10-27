import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/pages/cases_page.dart';
import 'package:subsumo/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:subsumo/pages/landesbezug.dart';
import 'package:subsumo/theme.dart';
import 'package:subsumo/pages/public/public_legal_page.dart';

Widget _app(Widget page) => MaterialApp.router(
      theme: buildTheme(Brightness.light),
      routerConfig:
          GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => page)]),
    );

void main() {
  for (final slug in ['impressum', 'agb', 'datenschutz']) {
    testWidgets('Beta: /rechtliches/$slug zeigt ehrliche Testzugang-Seite',
        (tester) async {
      await tester
          .pumpWidget(_app(PublicLegalPage(slug: slug, betaMode: true)));
      await tester.pumpAndSettle();
      expect(find.text('Privater Testzugang'), findsOneWidget);
      expect(
          find.textContaining('geschlossener, nicht öffentlicher Testzugang'),
          findsOneWidget);
      expect(find.textContaining('Feedback-Button in der App'), findsOneWidget);
      expect(find.textContaining('Platzhalter'), findsNothing);
      expect(find.textContaining('docs/'), findsNothing);
      expect(find.textContaining('SUB-'), findsNothing);
      expect(find.textContaining('Gespeichert werden nur'),
          slug == 'datenschutz' ? findsOneWidget : findsNothing);
    });
  }

  for (final slug in [
    'impressum',
    'agb',
    'datenschutz',
    'widerruf',
    'cookies'
  ]) {
    testWidgets('Ohne Beta: $slug zeigt keine internen Verweise',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 20000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester
          .pumpWidget(_app(PublicLegalPage(slug: slug, betaMode: false)));
      await tester.pumpAndSettle();
      final texts = <String>[
        for (final w in tester.widgetList<RichText>(find.byType(RichText)))
          w.text.toPlainText(),
      ].join('\n');
      expect(texts, isNot(contains('docs/')));
      expect(RegExp(r'SUB-\d+').hasMatch(texts), isFalse);
      expect(texts, isNot(contains('Privater Testzugang')));
    });
  }

  test('Landesname-Mapping und Label', () {
    expect(bundeslandNamen, hasLength(16));
    expect(landesLabel('BW'), 'Baden-Württemberg');
    expect(landesLabel(null), isNull);
    expect(landesLabel(''), isNull);
  });

  test('Wortbasierte Suche', () {
    expect(suchRang('BW', 'Gebwald Fall im Wald'), isNull);
    expect(suchRang('BW', 'Fall BW Landesrecht'), 0);
    expect(suchRang('bade', 'Baden-Württemberg'), 1);
    expect(suchRang('Baden-Württemberg', 'Fall in Baden-Württemberg'), 0);
    expect(suchRang('landesrecht bw', landesSuchtext('BW')), 0);
    expect(suchRang('landesrecht', 'Ein Fall ohne'), isNull);
  });

  testWidgets('Faelle: Landeschip, Sortierhinweis, wortbasierte Suche',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = MockClient((r) async => http.Response(
        jsonEncode([
          {
            'slug': 'a',
            'title': 'Kaufrecht',
            'area': 'zivilrecht',
            'difficulty': 2,
            'minutes': 60,
            'facts': 'Gebwald Verkauf',
            'question': 'Anspruch?'
          },
          {
            'slug': 'b',
            'title': 'Polizeirecht',
            'area': 'oeffentliches-recht',
            'difficulty': 3,
            'minutes': 60,
            'bundesland': 'BW',
            'facts': 'Gefahr',
            'question': 'Rechtmäßig?'
          },
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    final state = AppState(api: ApiClient(client: client)..setToken('t'));
    await tester.pumpWidget(AppScope(
      notifier: state,
      child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: CasesPage())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Baden-Württemberg'), findsOneWidget);
    expect(find.textContaining('sortiert nach Schwierigkeit'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'BW');
    await tester.pumpAndSettle();
    expect(find.text('Polizeirecht'), findsOneWidget);
    expect(find.text('Kaufrecht'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Landesrecht');
    await tester.pumpAndSettle();
    expect(find.text('Polizeirecht'), findsOneWidget);
    expect(find.text('Kaufrecht'), findsNothing);
    await tester.enterText(find.byType(TextField), 'baden');
    await tester.pumpAndSettle();
    expect(find.text('Polizeirecht'), findsOneWidget);
  });
}
