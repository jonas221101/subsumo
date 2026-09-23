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
import 'package:subsumo/design/design.dart';
import 'package:subsumo/main.dart';
import 'package:subsumo/pages/public/subsumo_brand_motif.dart';
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
    // Erste Frage ist initial aufgeklappt (Brief Abschnitt 3.8).
    expect(
      find.textContaining('Eine KI-gestützte Korrektur ist nicht Teil des aktuellen Angebots'),
      findsOneWidget,
    );
    // Die uebrigen Fragen sind eingeklappt - Akkordeon zuerst aufklappen.
    await tester.ensureVisible(find.text('Wie viele Karten gibt es wirklich?'));
    await tester.tap(find.text('Wie viele Karten gibt es wirklich?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Zum Start 180 geprüfte Karten'), findsOneWidget);

    await tester.ensureVisible(find.text('Kann ich kündigen?'));
    await tester.tap(find.text('Kann ich kündigen?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ja, jederzeit zum Ende der laufenden Laufzeit'), findsOneWidget);
    // 9. Footer (gemeinsame Komponente, siehe public_legal_page_test.dart)
    expect(find.widgetWithText(TextButton, 'Impressum'), findsOneWidget);
  });

  testWidgets('Sekundaerer CTA "Preise ansehen" verlinkt auf /preise', (tester) async {
    final state = AppState(api: _clientWithTopics(const []));

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Preise ansehen'));
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

  // SUB-241 Abnahmekriterium 3: Mehrspalten-Sektionen bei zwei
  // Fensterbreiten (400/1200 logische Pixel) auf das 800px-Breakpoint-
  // Verhalten geprueft (docs/25 Abschnitt 3/8.2).
  group('800px-Breakpoint (SUB-241)', () {
    testWidgets('<800px (400): Hero-Motiv entfaellt, Schritte/Rechtsgebiete/Preise gestapelt', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(400, 4200);
      tester.view.devicePixelRatio = 1;
      final state = AppState(api: _clientWithTopics(const []));

      await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/'));
      await tester.pumpAndSettle();

      // 1. Hero: Motiv entfaellt unter 800px (Brief Abschnitt 3.1).
      expect(find.byType(SubsumoBrandMotif), findsNothing);
      // 4. Wie es funktioniert: nummeriert gestapelt statt Pfeil-Verbindern.
      expect(find.byIcon(Icons.arrow_forward_outlined), findsNothing);
      // 6. Die drei Rechtsgebiete: gestapeltes Wrap-Verhalten zusaetzlich
      // zum immer vorhandenen Footer-Wrap (keine Themenbeispiele geladen,
      // also kein Chip-eigenes Wrap im Weg).
      expect(find.byType(Wrap), findsNWidgets(2));
      // 7. Preis-Teaser: Pro-Karte liegt unterhalb der Free-Karte.
      final freeY = tester.getTopLeft(find.text('Free')).dy;
      final proY = tester.getTopLeft(find.text('Pro (Gründerpreis)')).dy;
      expect(proY, greaterThan(freeY));
    });

    testWidgets('>=800px (1200): Hero-Motiv sichtbar, Schritte/Rechtsgebiete/Preise mehrspaltig', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      final state = AppState(api: _clientWithTopics(const []));

      await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/'));
      await tester.pumpAndSettle();

      // 1. Hero: Motiv sichtbar ab 800px.
      expect(find.byType(SubsumoBrandMotif), findsOneWidget);
      // 4. Wie es funktioniert: zwei Pfeil-Verbinder zwischen drei Schritten.
      expect(find.byIcon(Icons.arrow_forward_outlined), findsNWidgets(2));
      // 6. Die drei Rechtsgebiete: feste 3-Spalten-Reihe - nur noch der
      // immer vorhandene Footer-Wrap bleibt uebrig.
      expect(find.byType(Wrap), findsOneWidget);
      // 7. Preis-Teaser: Free-/Pro-Karte liegen nebeneinander (gleiche Zeile).
      final freeY = tester.getTopLeft(find.text('Free')).dy;
      final proY = tester.getTopLeft(find.text('Pro (Gründerpreis)')).dy;
      expect(proY, closeTo(freeY, 4));
    });
  });

  testWidgets('Rechtsgebiets-Akzente sind kategorisch fest pro Gebiet, nicht wertabhaengig', (
    tester,
  ) async {
    final state = AppState(api: _clientWithTopics(const []));

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Die drei Rechtsgebiete'));
    final colors = Theme.of(context).extension<SubsumoColors>()!;

    // Die drei schmalen Farbakzente (Hoehe 4) stehen in fester Dokument-
    // Reihenfolge Zivilrecht/Strafrecht/Oeffentliches Recht - unabhaengig
    // vom Breakpoint-Layout (Reihe oder Wrap), siehe _RechtsgebieteSection.
    final stripeColors = [
      for (final c in tester.widgetList<Container>(find.byType(Container)))
        if (c.decoration is BoxDecoration && c.constraints?.maxHeight == 4)
          if ((c.decoration! as BoxDecoration).color case final color?) color,
    ];
    expect(stripeColors, [
      colors.legalAreaZivilrecht,
      colors.legalAreaStrafrecht,
      colors.legalAreaOeffentlichesRecht,
    ]);
    expect(
      {colors.legalAreaZivilrecht, colors.legalAreaStrafrecht, colors.legalAreaOeffentlichesRecht},
      hasLength(3),
    );
  });
}
