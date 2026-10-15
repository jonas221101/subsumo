// Testwelle 4: Schemata-Kopfzeile, interne Texte, Strukturfehler-Labels.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/pages/examen_page.dart';
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

    await tester.tap(find.text('§ 433 Abs. 2 BGB'));
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
}
