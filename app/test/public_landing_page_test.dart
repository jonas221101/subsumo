// Belegt SUB-109: die Startseite (`/`) zeigt alle 9 Sektionen aus
// docs/21-landing-preisseite-launchtext.md Abschnitt 2.2 wortgleich
// (Fassung A, ohne KI-Korrektur - der Stichtagsentscheid SUB-135 steht noch
// aus), der sekundaere CTA verlinkt auf `/preise`, und die Themenbeispiele in
// Sektion 6 kommen vom oeffentlichen `GET /v1/content/topics`-Endpoint.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/main.dart';
import 'package:subsumo/state.dart';

ApiClient _clientWithTopics(List<Map<String, dynamic>> topics) {
  final mock = MockClient((request) async {
    if (request.url.path == '/v1/content/topics') {
      return http.Response(jsonEncode(topics), 200);
    }
    return http.Response('not found', 404);
  });
  return ApiClient(client: mock);
}

void main() {
  testWidgets('Startseite zeigt alle 9 Sektionen wortgleich aus docs/21 Abschnitt 2.2', (
    tester,
  ) async {
    final state = AppState(api: _clientWithTopics(const []));

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/'));
    await tester.pumpAndSettle();

    // 1. Hero
    expect(
      find.textContaining(
        'Karteikarten, Schemata und Fälle für dein Jurastudium — mit '
        'ehrlichem Feedback zum Aufbau deiner Gutachten.',
      ),
      findsOneWidget,
    );
    expect(find.text('Kostenlos starten'), findsOneWidget);
    // 2. Für wen
    expect(find.textContaining('Für Jurastudierende ab dem ersten Semester'), findsOneWidget);
    // 3. Was du heute bekommst
    expect(find.text('Was du heute bekommst'), findsOneWidget);
    expect(find.textContaining('automatischer Wiederholung (FSRS-Verfahren)'), findsOneWidget);
    expect(
      find.textContaining('Lernhilfe, keine Rechtsberatung, keine Note'),
      findsOneWidget,
    );
    // 4. Wie es funktioniert
    expect(find.text('Wie es funktioniert'), findsOneWidget);
    expect(find.textContaining('Konto anlegen, Rechtsgebiet wählen.'), findsOneWidget);
    // 5. Ehrlich ueber den Umfang
    expect(find.text('Ehrlich über den Umfang'), findsOneWidget);
    expect(find.textContaining('Deshalb der Gründerpreis'), findsOneWidget);
    // 6. Die drei Rechtsgebiete
    expect(find.text('Die drei Rechtsgebiete'), findsOneWidget);
    expect(find.textContaining('Zivilrecht · Strafrecht · Öffentliches Recht'), findsOneWidget);
    // 7. Preis-Teaser
    expect(find.textContaining('20 fällige Karten/Tag in einem Rechtsgebiet'), findsOneWidget);
    expect(find.text('Alle Preise ansehen'), findsOneWidget);
    // 8. FAQ (Fassung A - keine KI-Erwaehnung im Struktur-Check-Kontext)
    expect(find.text('FAQ'), findsOneWidget);
    expect(
      find.textContaining('Eine KI-gestützte Korrektur ist nicht Teil des aktuellen Angebots'),
      findsOneWidget,
    );
    expect(find.textContaining('Zum Start 180 geprüfte Karten'), findsOneWidget);
    expect(find.textContaining('Ja, jederzeit zum Ende der laufenden Laufzeit'), findsOneWidget);
    // 9. Footer (gemeinsame Komponente, siehe public_legal_page_test.dart)
    expect(find.widgetWithText(TextButton, 'Impressum'), findsOneWidget);
  });

  testWidgets('Sekundaerer CTA "Preise ansehen" verlinkt auf /preise', (tester) async {
    final state = AppState(api: _clientWithTopics(const []));

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preise ansehen'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    expect(GoRouterState.of(context).uri.path, '/preise');
    expect(find.text('Preise'), findsOneWidget);
  });

  testWidgets('Rechtsgebiete-Sektion zeigt Themenbeispiele aus GET /v1/content/topics', (
    tester,
  ) async {
    final state = AppState(
      api: _clientWithTopics(const [
        {'slug': 'zr-at-auslegung', 'area': 'zivilrecht', 'title': 'Auslegung', 'relevance': 5},
        {'slug': 'sr-bt-diebstahl', 'area': 'strafrecht', 'title': 'Diebstahl', 'relevance': 5},
      ]),
    );

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/'));
    await tester.pumpAndSettle();

    expect(find.text('Auslegung'), findsOneWidget);
    expect(find.text('Diebstahl'), findsOneWidget);
  });

  testWidgets('Fehler beim Laden der Themen zeigt Sektion ohne Themenbeispiele, kein Absturz', (
    tester,
  ) async {
    final mock = MockClient((request) async => throw Exception('kein Netz'));
    final state = AppState(api: ApiClient(client: mock));

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/'));
    await tester.pumpAndSettle();

    expect(find.text('Die drei Rechtsgebiete'), findsOneWidget);
    expect(find.text('Zivilrecht'), findsOneWidget);
  });
}
