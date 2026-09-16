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
}
