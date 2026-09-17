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
import 'package:subsumo/design/design.dart';
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

  // SUB-134: Zustimmungsdialog vor der ersten Abgabe, solange die
  // KI-Korrektur aktiv ist (`ai_correction_enabled`) und keine Entscheidung
  // vorliegt.
  group('Zustimmungsdialog zur KI-Korrektur (SUB-134)', () {
    const gutachtenText =
        'A koennte gegen B einen Anspruch auf Kaufpreiszahlung aus § 433 II BGB haben.';

    MockClient clientWith({
      required bool aiCorrectionEnabled,
      Map<String, dynamic> submitResult = const {
        'evaluation': {
          'points': 8.0,
          'note': 'befriedigend',
          'summary': 'Ordentlich.',
          'checkpoints': [],
          'disclaimer': 'Lernhilfe, keine Rechtsberatung.',
          'engine': 'heuristik',
        },
      },
      void Function(http.Request request)? onRequest,
    }) {
      return MockClient((request) async {
        onRequest?.call(request);
        if (request.url.path == '/v1/cases/zr-dritter-fall') {
          return _json(_case, 200);
        }
        if (request.url.path == '/v1/public/config') {
          return _json(
            {'paywall_enabled': false, 'ai_correction_enabled': aiCorrectionEnabled},
            200,
          );
        }
        if (request.url.path == '/v1/gutachten/analyze') {
          // Der Submit-Button wertet die Textlaenge erst beim naechsten
          // Rebuild neu aus - das loest hier die Analyse-Antwort aus.
          return _json({'score': 60, 'findings': [], 'counts': {}}, 200);
        }
        if (request.url.path == '/v1/cases/zr-dritter-fall/submit') {
          return _json(submitResult, 201);
        }
        return _json({}, 404);
      });
    }

    testWidgets('erscheint bei aktivem Flag ohne vorherige Einwilligung', (tester) async {
      final client = clientWith(aiCorrectionEnabled: true);
      final state = AppState(api: ApiClient(client: client)..setToken('t'))
        ..user = {'id': 1, 'email': 'a@example.com'};

      await _pump(tester, state);
      await tester.enterText(find.byType(TextField), gutachtenText);
      // Debounce (700ms) abwarten: der Submit-Button wertet die Textlaenge
      // erst beim naechsten Rebuild neu aus, den die Analyse ausloest.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SubsumoButton, 'Abgeben und bewerten lassen'));
      await tester.pumpAndSettle();

      expect(find.text('KI-Korrektur nutzen?'), findsOneWidget);
      expect(find.text('Ablehnen'), findsOneWidget);
      expect(find.text('Zustimmen'), findsOneWidget);
    });

    testWidgets('erscheint nicht bei inaktivem Flag - Abgabe laeuft direkt durch', (tester) async {
      final client = clientWith(aiCorrectionEnabled: false);
      final state = AppState(api: ApiClient(client: client)..setToken('t'))
        ..user = {'id': 1, 'email': 'a@example.com'};

      await _pump(tester, state);
      await tester.enterText(find.byType(TextField), gutachtenText);
      // Debounce (700ms) abwarten: der Submit-Button wertet die Textlaenge
      // erst beim naechsten Rebuild neu aus, den die Analyse ausloest.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SubsumoButton, 'Abgeben und bewerten lassen'));
      await tester.pumpAndSettle();

      expect(find.text('KI-Korrektur nutzen?'), findsNothing);
      expect(find.textContaining('Punkte'), findsOneWidget);
      // Feature aus: keine Engine-Kennzeichnung im Ergebnis (unveraenderte
      // Oberflaeche gegenueber dem Stand vor SUB-134).
      expect(find.text('Heuristisch geprueft'), findsNothing);
      expect(find.text('KI-bewertet'), findsNothing);
    });

    testWidgets('Ablehnen fuehrt zu einer erfolgreichen, heuristischen Abgabe', (tester) async {
      var consentGranted = false;
      final client = clientWith(
        aiCorrectionEnabled: true,
        onRequest: (request) {
          if (request.url.path == '/v1/me/ai-consent') consentGranted = true;
        },
      );
      final state = AppState(api: ApiClient(client: client)..setToken('t'))
        ..user = {'id': 1, 'email': 'a@example.com'};

      await _pump(tester, state);
      await tester.enterText(find.byType(TextField), gutachtenText);
      // Debounce (700ms) abwarten: der Submit-Button wertet die Textlaenge
      // erst beim naechsten Rebuild neu aus, den die Analyse ausloest.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SubsumoButton, 'Abgeben und bewerten lassen'));
      await tester.pumpAndSettle();
      expect(find.text('KI-Korrektur nutzen?'), findsOneWidget);

      await tester.tap(find.text('Ablehnen'));
      await tester.pumpAndSettle();

      expect(find.text('KI-Korrektur nutzen?'), findsNothing);
      expect(find.textContaining('Punkte'), findsOneWidget);
      expect(find.text('Heuristisch geprueft'), findsOneWidget);
      expect(consentGranted, isFalse);
    });

    testWidgets('Zustimmen erteilt die Einwilligung und zeigt die KI-Kennzeichnung',
        (tester) async {
      var consentGranted = false;
      final client = clientWith(
        aiCorrectionEnabled: true,
        submitResult: const {
          'evaluation': {
            'points': 14.0,
            'note': 'gut',
            'summary': 'Sehr sauber begruendet.',
            'checkpoints': [],
            'disclaimer': 'Lernhilfe, keine Rechtsberatung.',
            'engine': 'llm:claude-sonnet-5',
          },
        },
        onRequest: (request) {
          if (request.url.path == '/v1/me/ai-consent') consentGranted = true;
        },
      );
      final state = AppState(api: ApiClient(client: client)..setToken('t'))
        ..user = {'id': 1, 'email': 'a@example.com'};

      await _pump(tester, state);
      await tester.enterText(find.byType(TextField), gutachtenText);
      // Debounce (700ms) abwarten: der Submit-Button wertet die Textlaenge
      // erst beim naechsten Rebuild neu aus, den die Analyse ausloest.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SubsumoButton, 'Abgeben und bewerten lassen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Zustimmen'));
      await tester.pumpAndSettle();

      expect(consentGranted, isTrue);
      expect(find.text('KI-bewertet'), findsOneWidget);
    });

    testWidgets('nach einer Ablehnung erscheint der Dialog bei der naechsten Seite nicht erneut',
        (tester) async {
      final client = clientWith(aiCorrectionEnabled: true);
      final state = AppState(api: ApiClient(client: client)..setToken('t'))
        ..user = {'id': 1, 'email': 'a@example.com'};
      await state.declineAiConsent();

      await _pump(tester, state);
      await tester.enterText(find.byType(TextField), gutachtenText);
      // Debounce (700ms) abwarten: der Submit-Button wertet die Textlaenge
      // erst beim naechsten Rebuild neu aus, den die Analyse ausloest.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SubsumoButton, 'Abgeben und bewerten lassen'));
      await tester.pumpAndSettle();

      expect(find.text('KI-Korrektur nutzen?'), findsNothing);
      expect(find.textContaining('Punkte'), findsOneWidget);
    });
  });
}
