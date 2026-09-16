// F3 (docs/20-release-g2-bezahlstrecke.md Abschnitt 4): Kuendigungs-UI.
// Deckt die Zustandsmatrix als automatisierten Widget-Test ab statt als
// manuellen Screenshot (kein Display in der Ausfuehrungsumgebung verfuegbar).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/design/design.dart';
import 'package:subsumo/pages/account_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

http.Response _json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Future<AppState> _pumpAccountPage(
  WidgetTester tester, {
  required Map<String, dynamic> user,
  http.Client? client,
}) async {
  final state = AppState(api: ApiClient(client: client ?? MockClient((_) async => _json({}, 404))))
    ..user = user;

  await tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const AccountPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('Free-Zustand zeigt keinen Kuendigen-Button, sondern eine Pro-CTA', (tester) async {
    await _pumpAccountPage(
      tester,
      user: {'email': 'frei@example.com', 'pro_active': false, 'cancel_at_period_end': false},
    );

    expect(find.text('Kein aktives Pro-Abo.'), findsOneWidget);
    expect(find.widgetWithText(SubsumoButton, 'Kuendigen'), findsNothing);
    expect(find.widgetWithText(SubsumoButton, 'Pro werden'), findsOneWidget);
  });

  testWidgets('Pro-Zustand (aktiv, nicht gekuendigt) zeigt den Kuendigen-Button', (tester) async {
    await _pumpAccountPage(
      tester,
      user: {
        'email': 'pro@example.com',
        'pro_active': true,
        'pro_until': '2026-10-15T00:00:00Z',
        'cancel_at_period_end': false,
      },
    );

    expect(find.text('Plan: Pro'), findsOneWidget);
    expect(find.textContaining('15.10.2026'), findsOneWidget);
    expect(find.widgetWithText(SubsumoButton, 'Kuendigen'), findsOneWidget);
  });

  testWidgets('Bereits gekuendigt zeigt Enddatum statt des Buttons', (tester) async {
    await _pumpAccountPage(
      tester,
      user: {
        'email': 'gekuendigt@example.com',
        'pro_active': true,
        'pro_until': '2026-10-15T00:00:00Z',
        'cancel_at_period_end': true,
      },
    );

    expect(find.textContaining('bereits gekuendigt'), findsOneWidget);
    expect(find.widgetWithText(SubsumoButton, 'Kuendigen'), findsNothing);
  });

  testWidgets('Kuendigen: Bestaetigungsdialog + period_end-Ergebnis nach Erfolg', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/billing/cancel') {
        return _json({'mode': 'period_end'}, 200);
      }
      if (request.url.path == '/v1/auth/me') {
        return _json({
          'email': 'pro@example.com',
          'pro_active': true,
          'pro_until': '2026-10-15T00:00:00Z',
          'cancel_at_period_end': true,
        }, 200);
      }
      return _json({}, 404);
    });
    final state = await _pumpAccountPage(
      tester,
      user: {
        'email': 'pro@example.com',
        'pro_active': true,
        'pro_until': '2026-10-15T00:00:00Z',
        'cancel_at_period_end': false,
      },
      client: client,
    );

    await tester.tap(find.widgetWithText(SubsumoButton, 'Kuendigen'));
    await tester.pumpAndSettle();

    // Bestaetigungsdialog erscheint vor dem eigentlichen Aufruf.
    expect(find.text('Abo kuendigen?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Kuendigen'));
    await tester.pumpAndSettle();

    expect(
      find.text('Gekuendigt: dein Zugriff bleibt bis zum Ende der aktuellen Abrechnungsperiode bestehen.'),
      findsOneWidget,
    );
    // State-Refresh ohne App-Neustart (F1-Gekuendigt-Zustand uebernommen).
    expect(state.cancelAtPeriodEnd, isTrue);
  });

  testWidgets('Kuendigen: Widerrufsfall zeigt die Rueckerstattungs-Meldung', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/billing/cancel') {
        return _json({'mode': 'immediate_refund'}, 200);
      }
      if (request.url.path == '/v1/auth/me') {
        return _json({
          'email': 'pro@example.com',
          'pro_active': false,
          'cancel_at_period_end': false,
        }, 200);
      }
      return _json({}, 404);
    });
    await _pumpAccountPage(
      tester,
      user: {'email': 'pro@example.com', 'pro_active': true, 'cancel_at_period_end': false},
      client: client,
    );

    await tester.tap(find.widgetWithText(SubsumoButton, 'Kuendigen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Kuendigen'));
    await tester.pumpAndSettle();

    expect(
      find.text('Widerrufen: dein Abo wurde sofort beendet, die Zahlung wird vollstaendig erstattet.'),
      findsOneWidget,
    );
  });

  testWidgets('Abbrechen im Dialog loest keinen Aufruf aus', (tester) async {
    var called = false;
    final client = MockClient((request) async {
      if (request.url.path == '/v1/billing/cancel') called = true;
      return _json({}, 404);
    });
    await _pumpAccountPage(
      tester,
      user: {'email': 'pro@example.com', 'pro_active': true, 'cancel_at_period_end': false},
      client: client,
    );

    await tester.tap(find.widgetWithText(SubsumoButton, 'Kuendigen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.widgetWithText(SubsumoButton, 'Kuendigen'), findsOneWidget);
  });

  testWidgets('409 (kein aktives Abo) zeigt eine verstaendliche Meldung statt Fehlertext',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/billing/cancel') {
        return _json({'detail': 'no_active_subscription'}, 409);
      }
      return _json({}, 404);
    });
    await _pumpAccountPage(
      tester,
      user: {'email': 'pro@example.com', 'pro_active': true, 'cancel_at_period_end': false},
      client: client,
    );

    await tester.tap(find.widgetWithText(SubsumoButton, 'Kuendigen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Kuendigen'));
    await tester.pumpAndSettle();

    expect(find.text('Es ist aktuell kein aktives Abo hinterlegt.'), findsOneWidget);
    expect(find.text('no_active_subscription'), findsNothing);
  });

  group('Datenexport (Art. 15 DSGVO, SUB-84/SUB-103)', () {
    testWidgets('ruft den Endpunkt auf und bietet das Ergebnis zum Kopieren an', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      final client = MockClient((request) async {
        if (request.url.path == '/v1/account/export') {
          return _json({
            'account': {'email': 'frei@example.com'},
            'user_cards': [],
          }, 200);
        }
        return _json({}, 404);
      });
      await _pumpAccountPage(
        tester,
        user: {'email': 'frei@example.com', 'pro_active': false, 'cancel_at_period_end': false},
        client: client,
      );

      await tester.tap(find.widgetWithText(SubsumoButton, 'Meine Daten exportieren'));
      await tester.pumpAndSettle();

      expect(find.text('Deine Daten (Art. 15 DSGVO)'), findsOneWidget);
      // Nicht nur `frei@example.com`: das steht auch in der "Angemeldet als"-
      // Karte im Hintergrund. Die JSON-Anfuehrungszeichen grenzen auf den
      // Dialog-Inhalt ein.
      expect(find.textContaining('"frei@example.com"'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Kopieren'));
      await tester.pumpAndSettle();

      expect(find.text('In Zwischenablage kopiert.'), findsOneWidget);
      final setDataCall = calls.singleWhere((c) => c.method == 'Clipboard.setData');
      expect((setDataCall.arguments as Map)['text'], contains('frei@example.com'));
    });

    testWidgets('Serverfehler zeigt eine Fehlermeldung statt eines Dialogs', (tester) async {
      final client = MockClient((request) async => _json({'detail': 'export_failed'}, 500));
      await _pumpAccountPage(
        tester,
        user: {'email': 'frei@example.com', 'pro_active': false, 'cancel_at_period_end': false},
        client: client,
      );

      await tester.tap(find.widgetWithText(SubsumoButton, 'Meine Daten exportieren'));
      await tester.pumpAndSettle();

      expect(find.text('export_failed'), findsOneWidget);
      expect(find.text('Deine Daten (Art. 15 DSGVO)'), findsNothing);
    });
  });

  group('Kontoloeschung (Art. 17 DSGVO, SUB-84/SUB-103)', () {
    testWidgets('Abbrechen im Warn-Dialog loest keinen Aufruf aus', (tester) async {
      var called = false;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/account/delete') called = true;
        return _json({}, 404);
      });
      await _pumpAccountPage(
        tester,
        user: {'email': 'frei@example.com', 'pro_active': false, 'cancel_at_period_end': false},
        client: client,
      );

      await tester.tap(find.widgetWithText(SubsumoButton, 'Konto loeschen'));
      await tester.pumpAndSettle();
      expect(find.text('Konto unwiderruflich loeschen?'), findsOneWidget);

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.text('Passwort bestaetigen'), findsNothing);
    });

    testWidgets('Erfolg sendet Passwort+confirm:true und meldet lokal ab', (tester) async {
      Map<String, dynamic>? sentBody;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/account/delete') {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({}, 200);
        }
        return _json({}, 404);
      });
      final state = await _pumpAccountPage(
        tester,
        user: {'email': 'frei@example.com', 'pro_active': false, 'cancel_at_period_end': false},
        client: client,
      );

      await tester.tap(find.widgetWithText(SubsumoButton, 'Konto loeschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
      await tester.pumpAndSettle();

      expect(find.text('Passwort bestaetigen'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'geheim123');
      await tester.tap(find.widgetWithText(FilledButton, 'Konto endgueltig loeschen'));
      await tester.pumpAndSettle();

      expect(sentBody, {'password': 'geheim123', 'confirm': true});
      // Token/Nutzer lokal verworfen (F1-Login-Screen erscheint danach ueber
      // `_Root` in main.dart - hier direkt am State geprueft).
      expect(state.isAuthenticated, isFalse);
      expect(state.user, isNull);
    });

    testWidgets('401 (falsches Passwort) zeigt eine verstaendliche Meldung', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path == '/v1/account/delete') {
          return _json({'detail': 'invalid_password'}, 401);
        }
        return _json({}, 404);
      });
      await _pumpAccountPage(
        tester,
        user: {'email': 'frei@example.com', 'pro_active': false, 'cancel_at_period_end': false},
        client: client,
      );

      await tester.tap(find.widgetWithText(SubsumoButton, 'Konto loeschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'falsch');
      await tester.tap(find.widgetWithText(FilledButton, 'Konto endgueltig loeschen'));
      await tester.pumpAndSettle();

      expect(find.text('Passwort ist falsch.'), findsOneWidget);
      expect(find.text('invalid_password'), findsNothing);
    });

    testWidgets('400 (fehlende Bestaetigung) zeigt eine verstaendliche Meldung', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path == '/v1/account/delete') {
          return _json({'detail': 'confirm_required'}, 400);
        }
        return _json({}, 404);
      });
      await _pumpAccountPage(
        tester,
        user: {'email': 'frei@example.com', 'pro_active': false, 'cancel_at_period_end': false},
        client: client,
      );

      await tester.tap(find.widgetWithText(SubsumoButton, 'Konto loeschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'geheim123');
      await tester.tap(find.widgetWithText(FilledButton, 'Konto endgueltig loeschen'));
      await tester.pumpAndSettle();

      expect(find.text('Bestaetigung fehlt. Bitte erneut versuchen.'), findsOneWidget);
    });

    testWidgets('leeres Passwort wird clientseitig abgefangen', (tester) async {
      var called = false;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/account/delete') called = true;
        return _json({}, 404);
      });
      await _pumpAccountPage(
        tester,
        user: {'email': 'frei@example.com', 'pro_active': false, 'cancel_at_period_end': false},
        client: client,
      );

      await tester.tap(find.widgetWithText(SubsumoButton, 'Konto loeschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Konto endgueltig loeschen'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.text('Bitte Passwort eingeben'), findsOneWidget);
    });
  });
}
