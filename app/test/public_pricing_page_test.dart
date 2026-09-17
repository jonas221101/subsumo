// Belegt SUB-110: /preise zeigt Variante A (mit Kauf) wenn `paywall_enabled`
// vom oeffentlichen Feature-Flag-Endpoint (SUB-107, GET /v1/public/config)
// true liefert, sonst Variante B (Early Access) - fuer beide Flag-Zustaende
// und den Fehlerfall (Notausgang: faellt auf Variante B zurueck).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/main.dart';
import 'package:subsumo/state.dart';

ApiClient _clientWithConfig(Map<String, dynamic> config) {
  final mock = MockClient((request) async {
    if (request.url.path == '/v1/public/config') {
      return http.Response(jsonEncode(config), 200);
    }
    return http.Response('not found', 404);
  });
  return ApiClient(client: mock);
}

ApiClient _clientWithNetworkError() {
  final mock = MockClient((request) async => throw Exception('kein Netz'));
  return ApiClient(client: mock);
}

void main() {
  testWidgets('paywall_enabled=true zeigt Variante A (mit Kauf)', (tester) async {
    final state = AppState(api: _clientWithConfig({'paywall_enabled': true}));

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/preise'));
    await tester.pumpAndSettle();

    expect(find.text('Preise'), findsOneWidget);
    expect(find.text('Pro werden'), findsOneWidget);
    expect(find.text('Pro (Gründerpreis)'), findsOneWidget);
    expect(find.textContaining('3,99 €/Monat oder 39 €/Jahr'), findsOneWidget);
    expect(find.textContaining('Early Access'), findsNothing);
  });

  testWidgets('paywall_enabled=false zeigt Variante B (Early Access)', (tester) async {
    final state = AppState(api: _clientWithConfig({'paywall_enabled': false}));

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/preise'));
    await tester.pumpAndSettle();

    expect(find.text('Preise'), findsOneWidget);
    expect(find.textContaining('Early Access'), findsOneWidget);
    expect(find.text('Kostenlos registrieren und Preis sichern'), findsOneWidget);
    expect(find.textContaining('im vollen Pro-Umfang kostenlos'), findsOneWidget);
    expect(find.text('Pro (Gründerpreis)'), findsNothing);
  });

  testWidgets('Netzfehler beim Laden des Flags faellt auf Variante B zurueck', (tester) async {
    final state = AppState(api: _clientWithNetworkError());

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/preise'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Early Access'), findsOneWidget);
  });
}
