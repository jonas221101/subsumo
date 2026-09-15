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
    final state = AppState(api: ApiClient(client: client));

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
}
