// Welle-3-Korrekturen: Karten-Tab nach "Fertig", Platzhalter, Ergebnisanzeige,
// Themen-Gruppierung, Antwort-Darstellung.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/design/design.dart';
import 'package:subsumo/pages/dashboard_page.dart';
import 'package:subsumo/pages/gutachten_page.dart';
import 'package:subsumo/pages/review_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

Map<String, dynamic> _card(String slug) =>
    {'slug': slug, 'type': 'definition', 'front': 'F $slug', 'back': 'B $slug', 'state': 'new'};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Karten-Tab nach "Fertig fuer heute"', () {
    // Server liefert (noch) dieselben Karten, obwohl sie bewertet wurden.
    AppState build() {
      final client = MockClient((r) async {
        if (r.url.path == '/v1/cards/due') return _json([_card('a'), _card('b')]);
        if (r.url.path == '/v1/learn/coverage' || r.url.path.endsWith('coverage')) {
          return _json({'topics': [], 'by_area': {}, 'weighted_coverage': 0});
        }
        return _json({'accepted': 1});
      });
      return AppState(api: ApiClient(client: client)..setToken('t'));
    }

    test('bewertete Karten kehren nicht in den Stapel zurueck', () async {
      final app = build();
      await app.loadDueCards();
      await app.rateTopCard(3);
      await app.rateTopCard(3);
      expect(app.sessionDone, isTrue);
      await app.loadDueCards();
      expect(app.dueCards, isEmpty);
      expect(app.sessionDone, isTrue);
    });

    test('Nochmal-Karten duerfen wiederkommen', () async {
      final app = build();
      await app.loadDueCards();
      await app.rateTopCard(1);
      await app.loadDueCards();
      expect(app.dueCards.map((c) => c['slug']), contains('a'));
    });

    testWidgets('Karten-Tab zeigt Fertig-Zustand, nicht "1 von 2"', (tester) async {
      final app = build();
      await app.loadDueCards();
      await app.rateTopCard(3);
      await app.rateTopCard(3);
      await tester.pumpWidget(AppScope(
        notifier: app,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(body: ReviewPage(focusMode: false, onToggleFocusMode: () {})),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Fertig für heute.'), findsOneWidget);
      expect(find.textContaining('1 von'), findsNothing);
    });
  });

  group('Platzhalter', () {
    test('rechtmaessig-Fragen', () {
      expect(
        gutachtenPlatzhalter(area: 'oeffentliches-recht', question: 'Ist der Beschluss rechtmäßig?'),
        'Der Beschluss ist rechtmäßig, wenn ...',
      );
      expect(
        gutachtenPlatzhalter(area: 'oeffentliches-recht', question: 'Ist das rechtmäßig?'),
        'Die Maßnahme ist rechtmäßig, wenn ...',
      );
      expect(
        gutachtenPlatzhalter(area: 'oeffentliches-recht', question: 'Hat die Klage Erfolg?'),
        'Die Klage hat Erfolg, wenn sie zulässig und begründet ist.',
      );
    });
    test('Zivilrecht ohne Anspruch', () {
      expect(
        gutachtenPlatzhalter(area: 'zivilrecht', question: 'Hat K Eigentum erworben?'),
        'K könnte Eigentum ... erworben haben.',
      );
      expect(
        gutachtenPlatzhalter(area: 'zivilrecht', question: 'Ist der Vertrag wirksam?'),
        'Fraglich ist, ob ...',
      );
    });
  });

  testWidgets('Ergebnis ohne evaluation zeigt verstaendlichen Hinweis', (tester) async {
    // _ResultView ist privat; ueber GutachtenPage mit Submit-Antwort ohne evaluation.
    final client = MockClient((r) async {
      if (r.url.path.contains('/analyze')) return _json({'score': 78, 'findings': [], 'counts': {}});
      if (r.url.path.contains('/submit')) return _json({'submission_id': 1});
      if (r.url.path.contains('/cases/')) {
        return _json({
          'slug': 'x', 'topic_slug': 't', 'area': 'zivilrecht', 'title': 'Fall', 'difficulty': 1,
          'minutes': 10, 'facts': 'V und K.', 'question': 'Kann V von K Zahlung verlangen?', 'steps': [],
        });
      }
      return _json({});
    });
    final app = AppState(api: ApiClient(client: client)..setToken('t'))
      ..user = {'pro_active': true, 'ai_review_consent_at': '2026-01-01'};
    await tester.pumpWidget(AppScope(
      notifier: app,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const GutachtenPage(caseSlug: 'x', caseTitle: 'Fall', area: 'zivilrecht'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'V könnte gegen K einen Anspruch haben. ' * 3);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    final btn = find.widgetWithText(SubsumoButton, 'Abgeben und bewerten lassen');
    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pumpAndSettle();
    expect(find.textContaining('keine Punktbewertung'), findsOneWidget);
  });

  test('groupTopics: Schwerpunkt zuerst, Semester aufsteigend', () {
    final topics = [
      {'slug': 'z2', 'area': 'zivilrecht'},
      {'slug': 's1', 'area': 'strafrecht'},
      {'slug': 'z1', 'area': 'zivilrecht'},
    ];
    final g = groupTopics(
      topics,
      schwerpunkte: ['strafrecht'],
      kursDecks: [
        {'semester_default': 1, 'topics': [{'slug': 'z1'}]},
        {'semester_default': 3, 'topics': [{'slug': 'z2'}]},
      ],
    );
    expect(g.map((e) => e.$1), ['strafrecht', 'zivilrecht']);
    expect(g[1].$2.map((t) => t['slug']), ['z1', 'z2']);
  });

  testWidgets('CardAnswerText zeigt Absaetze und Aufzaehlungen, kuerzt nichts', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CardAnswerText('Erster Satz\nzweite Zeile.\n\n- Punkt eins\n- Punkt zwei'),
      ),
    ));
    expect(find.text('Erster Satz zweite Zeile.'), findsOneWidget);
    expect(find.text('Punkt eins'), findsOneWidget);
    expect(find.text('Punkt zwei'), findsOneWidget);
  });
}
