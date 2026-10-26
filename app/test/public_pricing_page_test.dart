// Belegt SUB-110: /preise zeigt Variante A (mit Kauf) wenn `paywall_enabled`
// vom oeffentlichen Feature-Flag-Endpoint (SUB-107, GET /v1/public/config)
// true liefert, sonst Variante B (Pro fuer alle Konten inklusive) - fuer beide Flag-Zustaende
// und den Fehlerfall (Notausgang: faellt auf Variante B zurueck).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/design/design.dart';
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
    // Preiszelle der Tabelle; der Gründerpreis-Absatz nennt den Preis noch
    // einmal, deshalb gezielt auf die USt.-Zeile pruefen.
    expect(
      find.textContaining('3,99 €/Monat oder 39 €/Jahr (inkl. gesetzlicher USt.'),
      findsOneWidget,
    );
    expect(find.textContaining('Gründerpreis gilt für alle, die jetzt einsteigen'), findsOneWidget);
    expect(find.textContaining('aktuell für alle Konten inklusive'), findsNothing);
    expect(find.textContaining('180 Karten'), findsNothing);
  });

  testWidgets('paywall_enabled=false zeigt Variante B (Pro für alle Konten inklusive)', (
    tester,
  ) async {
    final state = AppState(api: _clientWithConfig({'paywall_enabled': false}));

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/preise'));
    await tester.pumpAndSettle();

    expect(find.text('Preise'), findsOneWidget);
    expect(find.text('Pro ist aktuell für alle Konten inklusive'), findsOneWidget);
    expect(find.text('Pro (aktuell für alle Konten inklusive)'), findsOneWidget);
    expect(find.text('Kostenlos registrieren und Preis sichern'), findsOneWidget);
    expect(find.textContaining('im vollen Pro-Umfang kostenlos'), findsOneWidget);
    expect(find.text('Pro (Gründerpreis)'), findsNothing);
    // Keine "gerade gestartet"/"kommt bald"-Rahmung mehr (26.09.2026).
    expect(find.textContaining('Early Access'), findsNothing);
    expect(find.textContaining('kommt bald'), findsNothing);
    expect(find.textContaining('noch nicht live'), findsNothing);
  });

  testWidgets('Netzfehler beim Laden des Flags fällt auf Variante B zurück', (tester) async {
    final state = AppState(api: _clientWithNetworkError());

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/preise'));
    await tester.pumpAndSettle();

    expect(find.text('Pro (aktuell für alle Konten inklusive)'), findsOneWidget);
  });

  // SUB-241: "gleiche SubsumoSection-Logik gilt" (docs/25 Abschnitt 3) auch
  // fuer die Preisseite - zwei inhaltliche Baender plus das Footer-Band aus
  // PublicScaffold, statt einer erzwungenen Einheitsspalte.
  testWidgets('Preisseite nutzt SubsumoSection-Bänder statt einer Einheitsspalte (beide Varianten)', (
    tester,
  ) async {
    final stateA = AppState(api: _clientWithConfig({'paywall_enabled': true}));
    await tester.pumpWidget(SubsumoApp(state: stateA, initialLocation: '/preise'));
    await tester.pumpAndSettle();
    expect(find.byType(SubsumoSection), findsNWidgets(3));

    final stateB = AppState(api: _clientWithConfig({'paywall_enabled': false}));
    await tester.pumpWidget(SubsumoApp(state: stateB, initialLocation: '/preise'));
    await tester.pumpAndSettle();
    expect(find.byType(SubsumoSection), findsNWidgets(3));
  });
}
