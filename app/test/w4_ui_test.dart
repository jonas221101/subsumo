// Testwelle 4: Schemata-Kopfzeile, interne Texte, Strukturfehler-Labels.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/pages/norm_sheet.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/pages/account_page.dart';
import 'package:subsumo/pages/cases_page.dart';
import 'package:subsumo/pages/examen_page.dart';
import 'package:subsumo/pages/lernprofil_page.dart';
import 'package:subsumo/pages/login_page.dart';
import 'package:subsumo/pages/review_page.dart';
import 'package:subsumo/pages/schemata_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

const _hdr = {'content-type': 'application/json; charset=utf-8'};

Widget _app(AppState state, Widget home) => AppScope(
      notifier: state,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
    );

final _schema = {
  'slug': 's1',
  'title': 'Kaufpreisanspruch',
  'area': 'zivilrecht',
  'norms': ['§ 433 Abs. 2 BGB'],
  'steps': [
    {'label': 'Anspruch entstanden'}
  ],
  'stand': '2026',
  'sources': ['Eigenformulierung Redaktion', 'Palandt'],
};

MockClient _client() => MockClient((r) async {
      if (r.url.path.endsWith('/v1/normen')) {
        return http.Response(jsonEncode({'detail': {'message': 'x'}}), 404, headers: _hdr);
      }
      return http.Response(jsonEncode([_schema]), 200, headers: _hdr);
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Schema mit einer Norm: Titel und Chevron klappen auf, Norm oeffnet Dialog', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(api: ApiClient(client: _client())..setToken('t'));
    await tester.pumpWidget(_app(state, const Scaffold(body: SchemataPage())));
    await tester.pumpAndSettle();

    expect(find.text('Anspruch entstanden'), findsNothing);
    await tester.tap(find.text('Kaufpreisanspruch'));
    await tester.pumpAndSettle();
    expect(find.text('Anspruch entstanden'), findsOneWidget);
    expect(find.text('Stand: 2026  ·  Quellen: Palandt'), findsOneWidget);
    expect(find.textContaining('Eigenformulierung'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(find.text('Anspruch entstanden'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);

    // Die Norm im Kopf ist nur Text - Tippen klappt auf, statt den Dialog zu
    // oeffnen (Welle 5). Der Link sitzt im aufgeklappten Inhalt.
    await tester.tap(find.text('§ 433 Abs. 2 BGB'));
    await tester.pumpAndSettle();
    expect(find.text('Anspruch entstanden'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    await tester.tap(find.byType(NormLink));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('SchemaDetailPage zeigt das Schema aufgeklappt', (tester) async {
    final state = AppState(api: ApiClient(client: _client())..setToken('t'));
    await tester.pumpWidget(_app(state, const SchemaDetailPage(slug: 's1', title: 'Kaufpreisanspruch')));
    await tester.pumpAndSettle();
    expect(find.text('Anspruch entstanden'), findsOneWidget);
  });

  test('Strukturfehler-Labels', () {
    expect(strukturfehlerLabel({'code': 'x', 'label': 'Eigenes Label'}), 'Eigenes Label');
    expect(strukturfehlerLabel({'code': 'offener_obersatz'}), 'Obersatz ohne Ergebnis');
    expect(strukturfehlerLabel({'code': 'kein_ergebnis'}), 'Ergebnis fehlt');
    expect(strukturfehlerLabel({'code': 'neuer_fehler_code'}), 'Neuer fehler code');
  });

  group('Karten-UI', () {
    Future<AppState> pumpReview(WidgetTester tester, Size size, {List<Map<String, dynamic>>? due}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final card = {'slug': 'c1', 'type': 'definition', 'front': 'Frage?', 'back': 'Antwort.', 'norms': <String>[]};
      final client = MockClient((r) async {
        if (r.url.path.startsWith('/v1/reviews')) return http.Response('{}', 200, headers: _hdr);
        return http.Response(jsonEncode(due ?? [card]), 200, headers: _hdr);
      });
      final state = AppState(api: ApiClient(client: client)..setToken('t'));
      await tester.pumpWidget(_app(state, Scaffold(body: ReviewPage(focusMode: false, onToggleFocusMode: () {}))));
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('Touch-Zeiger blendet Tastaturhinweis auf breitem Tablet aus', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await pumpReview(tester, const Size(820, 1100));
        expect(find.text('Leertaste deckt auf.'), findsOneWidget);
        final g = await tester.startGesture(const Offset(400, 300), kind: PointerDeviceKind.touch);
        await g.up();
        await tester.pumpAndSettle();
        expect(find.text('Leertaste deckt auf.'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Antwort-zeigen-Button sitzt direkt unter der kompakten Karte', (tester) async {
      await pumpReview(tester, const Size(1400, 1100));
      final button = tester.getRect(find.text('Antwort zeigen'));
      expect(button.bottom, lessThan(500));
    });

    testWidgets('Bewertungsbuttons gleichwertig, Chevron scrollt weiter', (tester) async {
      final long = {
        'slug': 'c1',
        'type': 'definition',
        'front': 'Frage?',
        'back': List.generate(80, (i) => 'Zeile $i.').join('\n\n'),
        'norms': <String>[],
      };
      await pumpReview(tester, const Size(900, 600), due: [long]);
      await tester.tap(find.text('Antwort zeigen'));
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton), findsNothing);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scroll.position.pixels, 0);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(100));
    });

    testWidgets('Fertig-Seite: zentriert, ohne Lesemodus-Icon', (tester) async {
      final state = await pumpReview(tester, const Size(900, 800));
      expect(find.byIcon(Icons.fullscreen_outlined), findsOneWidget);
      await tester.tap(find.text('Antwort zeigen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gut'));
      await tester.pumpAndSettle();
      expect(state.sessionDone, isTrue);
      expect(find.text('Fertig für heute.'), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_outlined), findsNothing);
      final textCenter = tester.getCenter(find.text('Fertig für heute.')).dx;
      final buttonCenter = tester.getCenter(find.text('Weitere Karten lernen')).dx;
      expect((textCenter - buttonCenter).abs(), lessThan(2));
    });
  });

  group('Konto, Login, Profil', () {
    testWidgets('Konto: Rechtliches verlinkt, Beta ersetzt Abo-Block', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = AppState(api: ApiClient(client: MockClient((_) async => http.Response('{}', 404))))
        ..user = {'email': 'a@b.de', 'pro_active': true, 'cancel_at_period_end': false};
      await tester.pumpWidget(_app(state, const AccountPage(betaMode: true)));
      await tester.pumpAndSettle();
      expect(find.text('Testzugang – alle Funktionen freigeschaltet'), findsOneWidget);
      expect(find.text('Kündigen'), findsNothing);
      expect(find.text('Pro werden'), findsNothing);
      for (final t in ['Impressum', 'Datenschutzerklärung', 'AGB']) {
        expect(find.text(t), findsOneWidget);
      }

      // Leerer Code: Hinweis statt stiller Nicht-Reaktion.
      await tester.ensureVisible(find.text('Code einlösen'));
      await tester.tap(find.text('Code einlösen'));
      await tester.pumpAndSettle();
      expect(find.text('Bitte gib zuerst deinen Freischaltcode ein.'), findsOneWidget);
    });

    testWidgets('Login hat Rechtliches in der Fusszeile', (tester) async {
      await tester.pumpWidget(_app(AppState(api: ApiClient()), const LoginPage()));
      await tester.pumpAndSettle();
      expect(find.text('Impressum'), findsOneWidget);
      expect(find.text('AGB'), findsOneWidget);
    });

    testWidgets('Faelle: Hinweis ohne Bundesland, Suche leeren bei Nulltreffern', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = MockClient((r) async => http.Response(
          jsonEncode([
            {'slug': 'f1', 'title': 'Kaufrecht', 'area': 'zivilrecht', 'difficulty': 2, 'minutes': 60}
          ]),
          200,
          headers: _hdr));
      final state = AppState(api: ApiClient(client: client)..setToken('t'))
        ..examenCockpit = {'profil': {'bundesland': null}};
      await tester.pumpWidget(_app(state, const Scaffold(body: CasesPage())));
      await tester.pumpAndSettle();
      expect(find.textContaining('Landesrecht wird angezeigt, sobald du dein Bundesland einstellst'),
          findsOneWidget);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Neu laden'), findsNothing);
      await tester.tap(find.text('Suche leeren').last);
      await tester.pumpAndSettle();
      expect(find.text('Kaufrecht'), findsOneWidget);

    });

    testWidgets('Lernprofil: Abschnitt Bundesland & Universitaet, Deck-Dialog gruppiert', (tester) async {
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = MockClient((r) async {
        if (r.url.path.endsWith('/bundeslaender')) {
          return http.Response(jsonEncode([{'code': 'NW', 'name': 'Nordrhein-Westfalen'}]), 200, headers: _hdr);
        }
        if (r.url.path.endsWith('/universitaeten')) return http.Response('[]', 200, headers: _hdr);
        return http.Response('{}', 404);
      });
      final state = AppState(api: ApiClient(client: client)..setToken('t'))
        ..examenCockpit = {'profil': {'bundesland': null}};
      await tester.pumpWidget(_app(
        state,
        const LernprofilPage(profil: {}, themen: [
          {'slug': 'b', 'title': 'Zweites', 'area': 'strafrecht'},
          {'slug': 'a', 'title': 'Erstes', 'area': 'zivilrecht'},
          {'slug': 'c', 'title': 'Abc', 'area': 'zivilrecht'},
        ]),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Bundesland & Universität'), findsOneWidget);
      expect(find.text('Tagesbudget in Minuten'), findsNothing);
      expect(find.textContaining('FSRS'), findsNothing);
      expect(find.text('Wie sicher sollen Karten sitzen? Höher = häufigere Wiederholungen.'), findsOneWidget);

      await tester.tap(find.text('Neues Deck'));
      await tester.pumpAndSettle();
      final zivil = tester.getTopLeft(find.text('Zivilrecht').last).dy;
      final abc = tester.getTopLeft(find.text('Abc')).dy;
      final erstes = tester.getTopLeft(find.text('Erstes')).dy;
      final straf = tester.getTopLeft(find.text('Strafrecht').last).dy;
      expect(zivil, lessThan(abc));
      expect(abc, lessThan(erstes));
      expect(erstes, lessThan(straf));
    });
  });
}
