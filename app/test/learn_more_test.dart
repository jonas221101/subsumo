// Welle 5: "Weitere Karten lernen" muss das Tageslimit bewusst ueberschreiten
// (extra=true), sonst liefert der Server nach dem Limit keine neuen Karten.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/state.dart';

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

Map<String, dynamic> _card(String slug) =>
    {'slug': slug, 'type': 'definition', 'front': 'F', 'back': 'B', 'state': 'new'};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('learnMoreCards fragt mit extra=true, normales Laden ohne', () async {
    final extraFlags = <String?>[];
    final client = MockClient((r) async {
      if (r.url.path == '/v1/cards/due') {
        extraFlags.add(r.url.queryParameters['extra']);
        return _json(r.url.queryParameters['extra'] == 'true' ? [_card('neu')] : []);
      }
      return _json({'accepted': 1});
    });
    final app = AppState(api: ApiClient(client: client)..setToken('t'));
    await app.loadDueCards();
    expect(app.dueCards, isEmpty);
    await app.learnMoreCards();
    expect(extraFlags, [null, 'true']);
    expect(app.dueCards.map((c) => c['slug']), ['neu']);
  });
}
