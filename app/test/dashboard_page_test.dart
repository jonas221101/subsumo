// Belegt, dass das Beispiel-Screen fuer das Designsystem (docs/11-designsystem.md)
// tatsaechlich die Komponenten nutzt und die fruehere Ampel-Faerbung des
// Lernstands verschwunden ist.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/design/design.dart';
import 'package:subsumo/pages/dashboard_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

const _coverage = {
  'weighted_coverage': 0.62,
  'by_area': {'zivilrecht': 0.7, 'strafrecht': 0.3},
  'topics': [
    {
      'title': 'Anspruch aus § 433 BGB',
      'mastery': 0.05,
      'cards_total': 10,
      'cards_mature': 0,
      'cards_started': 1,
      'relevance': 5,
    },
    {
      'title': 'Eigentumsherausgabe § 985 BGB',
      'mastery': 0.9,
      'cards_total': 8,
      'cards_mature': 7,
      'cards_started': 8,
      'relevance': 4,
    },
  ],
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Dashboard nutzt SubsumoCard/SubsumoProgressMeter und zeigt keine Ampelfarben',
      (tester) async {
    final client = MockClient((request) async => http.Response(
          jsonEncode(_coverage),
          200,
          headers: {'content-type': 'application/json'},
        ));
    // pro_active: true haelt den F1-Pro-Status-Banner hier aussen vor - dieser
    // Test prueft ausschliesslich die Kartenansicht selbst, das Banner hat
    // eine eigene Testgruppe weiter unten.
    final state = AppState(api: ApiClient(client: client))
      ..user = {'pro_active': true, 'pro_until': null, 'cancel_at_period_end': false};

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: DashboardPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SubsumoCard), findsOneWidget);
    expect(find.byType(SubsumoProgressMeter), findsWidgets);
    expect(find.text('62 %'), findsOneWidget);

    // Frueher: CircleAvatar mit rot/gelb/gruen je nach Lernstand. Der
    // Ersatz ist ein neutrales, wertunabhaengiges Icon.
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byIcon(Icons.menu_book_outlined), findsNWidgets(2));
  });

  // F1 (docs/20-release-g2-bezahlstrecke.md Abschnitt 4): Free-, Pro- und
  // Gekuendigt-Zustand je einmal - das Manuelle-Test-Screenshot-Kriterium
  // ist damit als automatisierter Widget-Test statt als Screenshot geprueft
  // (kein Display in der Ausfuehrungsumgebung verfuegbar).
  group('Pro-Status-Banner (F1)', () {
    Future<AppState> pumpDashboard(
      WidgetTester tester, {
      required bool proActive,
      required bool cancelAtPeriodEnd,
      String? proUntil,
    }) async {
      final client = MockClient((request) async {
        if (request.url.path == '/v1/progress/coverage') {
          return http.Response(
            jsonEncode(_coverage),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final state = AppState(api: ApiClient(client: client))
        ..user = {
          'pro_active': proActive,
          'pro_until': proUntil,
          'cancel_at_period_end': cancelAtPeriodEnd,
        };

      await tester.pumpWidget(
        AppScope(
          notifier: state,
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const Scaffold(body: DashboardPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('Free-Zustand zeigt eine Pro-Werbung mit Call-to-Action', (tester) async {
      await pumpDashboard(tester, proActive: false, cancelAtPeriodEnd: false);

      expect(find.text('Mit Pro lernst du unbegrenzt in allen Rechtsgebieten.'), findsOneWidget);
      expect(find.widgetWithText(SubsumoButton, 'Pro werden'), findsOneWidget);
      expect(find.textContaining('Abo gekuendigt'), findsNothing);
    });

    testWidgets('Pro-Zustand (aktiv, nicht gekuendigt) zeigt keinen Banner', (tester) async {
      await pumpDashboard(tester, proActive: true, cancelAtPeriodEnd: false);

      expect(find.text('Mit Pro lernst du unbegrenzt in allen Rechtsgebieten.'), findsNothing);
      expect(find.textContaining('Abo gekuendigt'), findsNothing);
    });

    testWidgets('Gekuendigt-Zustand zeigt einen persistenten Hinweis mit Enddatum',
        (tester) async {
      await pumpDashboard(
        tester,
        proActive: true,
        cancelAtPeriodEnd: true,
        proUntil: '2026-10-15T00:00:00Z',
      );

      expect(find.text('Abo gekuendigt, Zugriff bis 15.10.2026.'), findsOneWidget);
      // Hat Vorrang vor der allgemeinen Pro-Werbung.
      expect(find.text('Mit Pro lernst du unbegrenzt in allen Rechtsgebieten.'), findsNothing);
    });
  });
}
