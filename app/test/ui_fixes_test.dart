// Belegt die UI-Korrekturen aus den Nutzertests (Beta-Simulation): Fall-Screen
// lesbar/scrollbar, Platzhalter je Rechtsgebiet, Feedback-Button in gepushten
// Screens, Tastaturhinweise nur am Desktop, "Fertig fuer heute", deutsche
// Lokalisierung, Titelumbruch, Suchfeld mit Clear-Button, Themenzeilen.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/main.dart';
import 'package:subsumo/pages/beta_feedback.dart';
import 'package:subsumo/pages/dashboard_page.dart';
import 'package:subsumo/pages/fit_title.dart';
import 'package:subsumo/pages/gutachten_page.dart';
import 'package:subsumo/pages/review_page.dart';
import 'package:subsumo/pages/schemata_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Widget _app(AppState state, Widget home) => AppScope(
      notifier: state,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Platzhalter im Loesungsfeld', () {
    test('Zivilrecht nimmt Parteikuerzel aus der Fallfrage', () {
      expect(
        gutachtenPlatzhalter(area: 'zivilrecht', question: 'Kann V von K Zahlung verlangen?'),
        'V könnte gegen K einen Anspruch auf ... aus § ... haben.',
      );
    });
    test('Zivilrecht ohne erkennbare Parteien bleibt neutral', () {
      expect(gutachtenPlatzhalter(area: 'zivilrecht', question: 'Besteht ein Anspruch?'),
          isNot(contains('A könnte')));
    });
    test('Strafrecht', () {
      expect(
        gutachtenPlatzhalter(area: 'strafrecht', question: 'Wie hat sich T strafbar gemacht?'),
        'T könnte sich wegen ... gemäß § ... strafbar gemacht haben.',
      );
      expect(gutachtenPlatzhalter(area: 'strafrecht'), contains('strafbar gemacht haben'));
    });
    test('Oeffentliches Recht', () {
      expect(gutachtenPlatzhalter(area: 'oeffentliches-recht', question: 'Hat die Klage Erfolg?'),
          'Die Klage hat Erfolg, wenn sie zulässig und begründet ist.');
      expect(
        gutachtenPlatzhalter(area: 'oeffentliches-recht', question: 'Ist das Gesetz verfassungsgemäß?'),
        startsWith('Das Gesetz ist verfassungsgemäß'),
      );
    });
  });

  group('Fall-Screen', () {
    final facts = List.generate(60, (i) => 'Satz $i des langen Sachverhalts.').join(' ');
    MockClient client() => MockClient((request) async {
          if (request.url.path == '/v1/cases/sr-lang') {
            return _json({
              'slug': 'sr-lang',
              'title': 'Langer Fall',
              'area': 'strafrecht',
              'facts': facts,
              'question': 'Wie hat sich T strafbar gemacht?',
            });
          }
          if (request.url.path == '/v1/public/config') return _json({});
          return _json({}, 404);
        });

    for (final size in [const Size(390, 800), const Size(1280, 800)]) {
      testWidgets('Sachverhalt vollstaendig, Fallfrage erreichbar, Platzhalter strafrechtlich (${size.width.toInt()}px)',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final state = AppState(api: ApiClient(client: client())..setToken('t'));
        await tester.pumpWidget(_app(
            state, const GutachtenPage(caseSlug: 'sr-lang', caseTitle: 'Langer Fall')));
        await tester.pumpAndSettle();

        // Kein abgeschnittener Text: der ganze Sachverhalt ist im Widgetbaum
        // und die Fallfrage nach Scrollen sichtbar.
        expect(find.textContaining('Satz 59 des langen Sachverhalts.'), findsOneWidget);
        await tester.ensureVisible(find.text('Wie hat sich T strafbar gemacht?'));
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.text('Wie hat sich T strafbar gemacht?'));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(find.byType(Scrollable), findsWidgets);

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.decoration!.hintText, 'T könnte sich wegen ... gemäß § ... strafbar gemacht haben.');
      });
    }

    testWidgets('Ergebnis-Panel ist scrollbar', (tester) async {
      tester.view.physicalSize = const Size(1280, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = MockClient((request) async {
        if (request.url.path == '/v1/cases/sr-lang') {
          return _json({'slug': 'sr-lang', 'title': 'x', 'facts': 'f', 'question': 'q'});
        }
        if (request.url.path == '/v1/public/config') return _json({});
        if (request.url.path.endsWith('/submit')) {
          return _json({
            'evaluation': {
              'points': 9,
              'note': 'gut',
              'summary': 'Zusammenfassung',
              'disclaimer': 'Lernhilfe, keine Rechtsberatung.',
              'checkpoints': [
                for (var i = 0; i < 12; i++) {'label': 'Punkt $i', 'hit': i.isEven, 'evidence': 'e', 'comment': 'c'},
              ],
            },
          }, 201);
        }
        return _json({'score': 50, 'findings': [], 'counts': {}});
      });
      final state = AppState(api: ApiClient(client: c)..setToken('t'));
      await tester.pumpWidget(_app(state, const GutachtenPage(caseSlug: 'sr-lang', caseTitle: 'x')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'T ' * 40);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Abgeben und bewerten lassen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abgeben und bewerten lassen'));
      await tester.pumpAndSettle();
      final disclaimer = find.text('Lernhilfe, keine Rechtsberatung.');
      await tester.ensureVisible(disclaimer);
      await tester.pumpAndSettle();
      expect(tester.getRect(disclaimer).bottom, lessThanOrEqualTo(500));
    });
  });

  group('Beta-Feedback-Button', () {
    testWidgets('ohne Beta-Modus unsichtbar', (tester) async {
      await tester.pumpWidget(_app(AppState(), Scaffold(appBar: AppBar(actions: const [BetaFeedbackAction(screen: 'x')]))));
      expect(find.byIcon(Icons.rate_review_outlined), findsNothing);
    });
    testWidgets('mit force sichtbar und oeffnet den Dialog mit Bereich', (tester) async {
      await tester.pumpWidget(_app(
          AppState(),
          Scaffold(appBar: AppBar(actions: const [BetaFeedbackAction(screen: 'Fall: Test', force: true)]))));
      await tester.tap(find.byIcon(Icons.rate_review_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Bereich: Fall: Test'), findsOneWidget);
    });
  });

  group('Karten-Screen', () {
    const card = {'slug': 'c1', 'front': 'Frage?', 'back': 'Antwort.', 'type': 'definition'};

    Future<AppState> pump(WidgetTester tester, Size size, {TargetPlatform? platform, List<Map<String, dynamic>>? due}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var reviewed = false;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/cards/due') {
          // Nach einer Bewertung liefert der Server eine neue Karte (bewertete kommen nicht zurueck).
          return _json(due ?? [reviewed ? {...card, 'slug': 'c2'} : card]);
        }
        if (request.url.path.startsWith('/v1/reviews')) {
          reviewed = true;
          return _json({});
        }
        return _json({}, 404);
      });
      final state = AppState(api: ApiClient(client: client)..setToken('t'));
      await tester.pumpWidget(_app(state, Scaffold(body: ReviewPage(focusMode: false, onToggleFocusMode: () {}))));
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('Desktop zeigt Tastaturhinweis, schmaler Screen nicht', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await pump(tester, const Size(1000, 800));
        expect(find.text('Leertaste deckt auf.'), findsOneWidget);
        await pump(tester, const Size(390, 800));
        expect(find.text('Leertaste deckt auf.'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Touch-Plattform blendet Tastaturhinweis auch bei breitem Fenster aus', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pump(tester, const Size(1000, 800));
        expect(find.text('Leertaste deckt auf.'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('lange Antwort ist scrollbar und zeigt Mehr-Hinweis', (tester) async {
      final long = {...card, 'back': List.generate(80, (i) => 'Zeile $i der langen Antwort.').join('\n\n')};
      await pump(tester, const Size(1000, 600), due: [long]);
      await tester.tap(find.text('Antwort zeigen'));
      await tester.pumpAndSettle();
      expect(find.byType(Scrollbar), findsWidgets);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -20000));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      expect(find.text('Gut'), findsOneWidget);
    });

    testWidgets('nach dem Stapel: "Fertig fuer heute" statt stillem Neustart; Weitere Karten auf Wunsch',
        (tester) async {
      final state = await pump(tester, const Size(1000, 800));
      await tester.tap(find.text('Antwort zeigen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gut'));
      await tester.pumpAndSettle();
      expect(state.sessionDone, isTrue);
      expect(find.text('Fertig für heute.'), findsOneWidget);
      expect(find.text('Weitere Karten lernen'), findsOneWidget);
      expect(find.textContaining('1 von'), findsNothing);

      await tester.tap(find.text('Weitere Karten lernen'));
      await tester.pumpAndSettle();
      expect(state.sessionDone, isFalse);
      expect(find.text('Frage?'), findsOneWidget);
    });

    test('reflowCardText fuegt harte Zeilenumbrueche mitten im Satz zusammen', () {
      expect(reflowCardText('der Täter\nhält es für möglich.\n\nZweiter Absatz\n- Punkt'),
          'der Täter hält es für möglich.\n\nZweiter Absatz\n- Punkt');
    });
  });

  testWidgets('MaterialApp ist deutsch lokalisiert (Datepicker)', (tester) async {
    await tester.pumpWidget(SubsumoApp(state: AppState(), initialLocation: '/preise'));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(Scaffold).first);
    expect(Localizations.localeOf(ctx).languageCode, 'de');
    expect(MaterialLocalizations.of(ctx).cancelButtonLabel, 'Abbrechen');
  });

  group('Titel', () {
    testWidgets('FitTitle verkleinert statt mitten im Wort umzubrechen', (tester) async {
      await tester.pumpWidget(_app(
        AppState(),
        const Scaffold(
          body: SizedBox(
            width: 420,
            child: FitTitle('Wohnungseinbruchdiebstahl', style: TextStyle(fontSize: 20)),
          ),
        ),
      ));
      final text = tester.widget<Text>(find.text('Wohnungseinbruchdiebstahl'));
      expect(text.style!.fontSize, lessThan(20));
      // Genau eine Zeile, also kein Zeichenumbruch.
      expect(tester.getSize(find.text('Wohnungseinbruchdiebstahl')).height, lessThan(40));
    });
  });

  testWidgets('Schemata-Suche: Clear-Button leert Feld und Filter', (tester) async {
    final client = MockClient((request) async => _json([
          {'title': 'Anfechtung', 'area': 'zivilrecht', 'norms': ['§ 119'], 'steps': [], 'stand': '2026', 'sources': []},
          {'title': 'Diebstahl', 'area': 'strafrecht', 'norms': ['§ 242'], 'steps': [], 'stand': '2026', 'sources': []},
        ]));
    final state = AppState(api: ApiClient(client: client)..setToken('t'));
    await tester.pumpWidget(_app(state, const Scaffold(body: SchemataPage())));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.clear), findsNothing);

    await tester.enterText(find.byType(TextField), 'Dieb');
    await tester.pumpAndSettle();
    expect(find.text('Anfechtung'), findsNothing);
    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.text('Anfechtung'), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsNothing);
  });

  testWidgets('Heute: Tap auf eine Themenzeile startet Karten dieses Themas', (tester) async {
    String? topicParam;
    final client = MockClient((request) async {
      if (request.url.path == '/v1/cards/due') {
        topicParam = request.url.queryParameters['topic'];
        return _json([]);
      }
      return _json({
        'weighted_coverage': 0.1,
        'by_area': {'zivilrecht': 0.1},
        'topics': [
          {
            'slug': 'zr-at-anfechtung',
            'title': 'Anfechtung',
            'mastery': 0.0,
            'cards_total': 4,
            'cards_mature': 0,
            'cards_started': 0,
            'relevance': 3,
          },
        ],
      });
    });
    final state = AppState(api: ApiClient(client: client)..setToken('t'))
      ..user = {'pro_active': true, 'pro_until': null, 'cancel_at_period_end': false};
    await tester.pumpWidget(_app(state, const Scaffold(body: DashboardPage())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Anfechtung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anfechtung'));
    await tester.pumpAndSettle();
    expect(find.text('Deck: Anfechtung'), findsOneWidget);
    expect(topicParam, 'zr-at-anfechtung');
  });
}
