// Belegt den Relaunch der App-Screens ("Kanzlei-Editorial"): Startseite mit
// Direkteinstieg, Tastaturbedienung im Lernmodus ohne Ampel-Farben auf den
// Bewertungen, juristische Gliederungsnummerierung in den Schemata und die
// neuen Designsystem-Bausteine.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/design/design.dart';
import 'package:subsumo/pages/dashboard_page.dart';
import 'package:subsumo/pages/review_page.dart';
import 'package:subsumo/pages/schemata_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

const _coverage = {
  'weighted_coverage': 0.4,
  'by_area': {'zivilrecht': 0.4},
  'topics': <Map<String, Object?>>[],
};

const _dueCards = [
  {'slug': 'bgb-985', 'type': 'definition', 'front': 'Was regelt § 985 BGB?', 'back': 'Herausgabeanspruch.'},
  {'slug': 'bgb-433', 'type': 'norm', 'front': 'Was regelt § 433 BGB?', 'back': 'Kaufvertrag.'},
];

Widget _wrap(AppState state, Widget child) => AppScope(
      notifier: state,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: child)),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Startseite "Heute"', () {
    testWidgets('zeigt die Zahl der fälligen Karten und der Direkteinstieg ruft onStartReview',
        (tester) async {
      final client = MockClient((request) async => _json(_coverage));
      final state = AppState(api: ApiClient(client: client))
        ..user = {'pro_active': true}
        ..dueCards = List.of(_dueCards);
      var started = false;

      await tester.pumpWidget(_wrap(state, DashboardPage(onStartReview: () => started = true)));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Karten warten auf dich.'), findsOneWidget);
      expect(find.byType(SubsumoPageHeader), findsOneWidget);
      // Relevanz als neutrale Punktreihe, kein wertabhaengiges Signal.
      expect(find.byType(CircleAvatar), findsNothing);

      await tester.tap(find.widgetWithText(SubsumoButton, 'Jetzt lernen'));
      expect(started, isTrue);
    });

    testWidgets('ohne fällige Karten bleibt der Ton sachlich', (tester) async {
      final client = MockClient((request) async => _json(_coverage));
      final state = AppState(api: ApiClient(client: client))..user = {'pro_active': true};

      await tester.pumpWidget(_wrap(state, const DashboardPage()));
      await tester.pumpAndSettle();

      expect(find.text('Keine Karte wartet. Du bist auf Stand.'), findsOneWidget);
      expect(find.widgetWithText(SubsumoButton, 'Karten ansehen'), findsOneWidget);
    });
  });

  group('Lernmodus', () {
    Future<AppState> pump(WidgetTester tester) async {
      final client = MockClient((request) async {
        if (request.url.path == '/v1/cards/due') return _json(_dueCards);
        return _json({'accepted': 1});
      });
      final state = AppState(api: ApiClient(client: client)..setToken('t'));
      await tester.pumpWidget(_wrap(state, ReviewPage(focusMode: false, onToggleFocusMode: () {})));
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('Leertaste deckt auf, Ziffer bewertet - Bewertungen ohne Ampelfarben',
        (tester) async {
      final state = await pump(tester);
      expect(find.text('Was regelt § 985 BGB?'), findsOneWidget);
      expect(find.text('Herausgabeanspruch.'), findsNothing);

      // Ziffern vor dem Aufdecken bewerten nichts.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pumpAndSettle();
      expect(state.dueCards.length, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('Herausgabeanspruch.'), findsOneWidget);

      // Genau eine gefuellte Schaltflaeche ("Gut"), drei Konturen - Gewicht
      // statt Farbe. Keine der vier nutzt error/positive/hint als Fuellung.
      final filled = tester.widgetList<FilledButton>(find.byType(FilledButton)).toList();
      expect(filled, hasLength(1));
      expect(find.widgetWithText(FilledButton, 'Gut'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNWidgets(3));
      for (final button in filled) {
        final bg = button.style?.backgroundColor?.resolve({});
        expect(bg, isNull, reason: 'Bewertungsbutton darf keine eigene Signalfarbe tragen');
      }

      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pumpAndSettle();
      expect(state.dueCards.length, 1);
      expect(find.text('Was regelt § 433 BGB?'), findsOneWidget);
      // Eyebrow setzt in Versalien.
      expect(find.textContaining('2 VON 2'), findsOneWidget);
    });
  });

  group('Schemata', () {
    test('Gliederungszeichen folgen der juristischen Konvention', () {
      expect(outlineNumeral(0, 0), 'I.');
      expect(outlineNumeral(0, 3), 'IV.');
      expect(outlineNumeral(1, 1), '2.');
      expect(outlineNumeral(2, 0), 'a)');
      expect(outlineNumeral(3, 1), 'bb)');
      expect(outlineNumeral(4, 0), '(1)');
    });

    test('vorhandene Gliederungszeichen im Text werden übernommen statt verdoppelt', () {
      expect(splitNumeral('I. Schutzbereich', depth: 0, index: 0), ('I.', 'Schutzbereich'));
      expect(splitNumeral('2. Sachlich: Beruf', depth: 1, index: 0), ('2.', 'Sachlich: Beruf'));
      expect(splitNumeral('aa) Enge Auslegung', depth: 3, index: 0), ('aa)', 'Enge Auslegung'));
      expect(splitNumeral('(2) Sonderfall', depth: 4, index: 0), ('(2)', 'Sonderfall'));
      expect(splitNumeral('Anspruch entstanden', depth: 0, index: 1), ('II.', 'Anspruch entstanden'));
      // Kein Zeichen: "Art. 12" oder "a.A." duerfen nicht als Gliederung gelten.
      expect(splitNumeral('Art. 12 GG', depth: 1, index: 0), ('1.', 'Art. 12 GG'));
    });

    testWidgets('Suche filtert nach Titel oder Norm', (tester) async {
      final client = MockClient((request) async => _json([
            {
              'title': 'Anspruch aus § 985 BGB',
              'area': 'zivilrecht',
              'norms': ['§ 985 BGB'],
              'steps': [
                {'label': 'Anspruch entstanden', 'children': [
                  {'label': 'Eigentum des Anspruchstellers'},
                ]},
              ],
              'stand': '2026-09',
              'sources': ['Palandt'],
            },
            {
              'title': 'Totschlag',
              'area': 'strafrecht',
              'norms': ['§ 212 StGB'],
              'steps': <Map<String, Object?>>[],
              'stand': '2026-09',
              'sources': <String>[],
            },
          ]));
      final state = AppState(api: ApiClient(client: client)..setToken('t'));
      await tester.pumpWidget(_wrap(state, const SchemataPage()));
      await tester.pumpAndSettle();

      expect(find.text('Anspruch aus § 985 BGB'), findsOneWidget);
      expect(find.text('Totschlag'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '212');
      await tester.pumpAndSettle();
      expect(find.text('Anspruch aus § 985 BGB'), findsNothing);
      expect(find.text('Totschlag'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anspruch aus § 985 BGB'));
      await tester.pumpAndSettle();
      expect(find.text('I.'), findsOneWidget);
      expect(find.text('1.'), findsOneWidget);
    });
  });

  group('Designsystem-Bausteine', () {
    testWidgets('SubsumoEyebrow setzt in Versalien, SubsumoDots ist wertunabhängig gefärbt',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(
          body: Column(children: [
            SubsumoEyebrow('Sachverhalt'),
            SubsumoDots(value: 1, label: 'Relevanz'),
            SubsumoDots(value: 5, label: 'Relevanz'),
          ]),
        ),
      ));

      expect(find.text('SACHVERHALT'), findsOneWidget);
      expect(find.bySemanticsLabel('Relevanz 1 von 5'), findsOneWidget);
      expect(find.bySemanticsLabel('Relevanz 5 von 5'), findsOneWidget);

      final scheme = buildColorScheme(Brightness.light);
      final filledDots = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle && d.color == scheme.primary)
          .length;
      expect(filledDots, 6, reason: '1 + 5 gefüllte Punkte, alle in primary');
    });

    testWidgets('SubsumoPanel ist anklickbar und trägt eine Haarlinie', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: SubsumoPanel(onTap: () => tapped = true, child: const Text('Zeile'))),
      ));
      await tester.tap(find.text('Zeile'));
      expect(tapped, isTrue);

      final material = tester.widget<Material>(find.ancestor(of: find.text('Zeile'), matching: find.byType(Material)).first);
      final shape = material.shape as RoundedRectangleBorder;
      expect(shape.side.color, buildColorScheme(Brightness.light).outlineVariant);
    });
  });
}
