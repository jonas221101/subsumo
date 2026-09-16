// Deckt das Fehlerformat der Free-Tier-Limits ab (docs/20-release-g2-bezahlstrecke.md
// B2): 402/403-Antworten mit `upgrade_required` muessen als solche erkennbar
// sein, egal ob das Flag flach im Body oder (FastAPI-typisch) im `detail`-
// Objekt steckt. B2 selbst ist noch nicht gebaut - dieser Test legt das
// Vertragsformat fest, gegen das der Client (F1) bereits arbeitet.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:subsumo/api.dart';

http.Response _json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('ApiException.upgradeRequired', () {
    test('erkennt upgrade_required im detail-Objekt (FastAPI-Standardform)', () async {
      final client = MockClient((request) async => _json({
            'detail': {
              'upgrade_required': true,
              'message': 'Wochenlimit erreicht. Reset am 2026-09-22.',
            },
          }, 403));
      final api = ApiClient(client: client)..setToken('t');

      await expectLater(
        () => api.analyze('lang genug fuer die Analyse, mindestens vierzig Zeichen'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.upgradeRequired, 'upgradeRequired', isTrue)
              .having((e) => e.message, 'message', contains('Wochenlimit')),
        ),
      );
    });

    test('erkennt upgrade_required flach im Body', () async {
      final client = MockClient((request) async => _json({
            'detail': 'Fall nur mit Pro verfuegbar',
            'upgrade_required': true,
          }, 402));
      final api = ApiClient(client: client)..setToken('t');

      await expectLater(
        () => api.caseDetail('zr-dritter-fall'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.upgradeRequired, 'upgradeRequired', isTrue)
              .having((e) => e.message, 'message', 'Fall nur mit Pro verfuegbar'),
        ),
      );
    });

    test('generischer Fehler ohne upgrade_required bleibt unmarkiert', () async {
      final client = MockClient((request) async => _json({'detail': 'Fall nicht gefunden'}, 404));
      final api = ApiClient(client: client)..setToken('t');

      await expectLater(
        () => api.caseDetail('unbekannt'),
        throwsA(
          isA<ApiException>().having((e) => e.upgradeRequired, 'upgradeRequired', isFalse),
        ),
      );
    });
  });

  group('ApiClient.cancelSubscription (F3, docs/20-release-g2-bezahlstrecke.md B5)', () {
    test('liefert den Server-mode unveraendert', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/billing/cancel');
        return _json({'mode': 'immediate_refund'}, 200);
      });
      final api = ApiClient(client: client)..setToken('t');

      final result = await api.cancelSubscription();

      expect(result['mode'], 'immediate_refund');
    });

    test('409 ohne aktives Abo wird als ApiException durchgereicht', () async {
      final client = MockClient((request) async => _json({'detail': 'no_active_subscription'}, 409));
      final api = ApiClient(client: client)..setToken('t');

      await expectLater(
        () => api.cancelSubscription(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });

  group('ApiClient.createCheckoutSession (F2, docs/20-release-g2-bezahlstrecke.md B3)', () {
    test('sendet den gewaehlten Plan und liefert die checkout_url', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/billing/checkout-session');
        expect(jsonDecode(request.body), {'plan': 'yearly'});
        return _json({'checkout_url': 'https://checkout.stripe.com/session/abc'}, 200);
      });
      final api = ApiClient(client: client)..setToken('t');

      final url = await api.createCheckoutSession('yearly');

      expect(url, 'https://checkout.stripe.com/session/abc');
    });

    test('Serverfehler wird als ApiException durchgereicht', () async {
      final client = MockClient((request) async => _json({'detail': 'stripe_unreachable'}, 502));
      final api = ApiClient(client: client)..setToken('t');

      await expectLater(
        () => api.createCheckoutSession('monthly'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 502)),
      );
    });
  });

  group('ApiClient.exportAccountData (Art. 15 DSGVO, SUB-84/SUB-103)', () {
    test('liefert den Server-Body unveraendert', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/account/export');
        return _json({
          'account': {'email': 'a@example.com'},
          'user_cards': [],
          'reviews': [],
          'submissions': [],
        }, 200);
      });
      final api = ApiClient(client: client)..setToken('t');

      final result = await api.exportAccountData();

      expect(result['account'], {'email': 'a@example.com'});
    });
  });

  group('ApiClient.deleteAccount (Art. 17 DSGVO, SUB-84/SUB-103)', () {
    test('sendet Passwort und confirm:true', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/account/delete');
        expect(jsonDecode(request.body), {'password': 'geheim123', 'confirm': true});
        return _json({}, 200);
      });
      final api = ApiClient(client: client)..setToken('t');

      await api.deleteAccount('geheim123');
    });

    test('400 (fehlende Bestaetigung) wird als ApiException durchgereicht', () async {
      final client = MockClient((request) async => _json({'detail': 'confirm_required'}, 400));
      final api = ApiClient(client: client)..setToken('t');

      await expectLater(
        () => api.deleteAccount('geheim123'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400)),
      );
    });

    test('401 (falsches Passwort) wird als ApiException durchgereicht', () async {
      final client = MockClient((request) async => _json({'detail': 'invalid_password'}, 401));
      final api = ApiClient(client: client)..setToken('t');

      await expectLater(
        () => api.deleteAccount('falsch'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });
}
