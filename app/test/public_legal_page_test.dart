// Belegt SUB-111: die Rechtstexte-Routen (/rechtliches/:slug) rendern den
// tatsaechlichen Inhalt der jeweiligen docs/legal/*.md-Datei (SUB-85) - nicht
// mehr den Platzhaltertext aus dem SUB-108-Geruest. Der Footer verlinkt alle
// fuenf Rechtstexte konsistent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/main.dart';
import 'package:subsumo/state.dart';

void main() {
  testWidgets('/rechtliches/impressum rendert den Inhalt aus docs/legal/01-impressum.md', (
    tester,
  ) async {
    final state = AppState(api: ApiClient());

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/rechtliches/impressum'));
    await tester.pumpAndSettle();

    expect(find.text('Impressum (Entwurf)'), findsOneWidget);
    expect(find.textContaining('Angaben gemäß § 5 Digitale-Dienste-Gesetz'), findsOneWidget);
    // Platzhalter aus SUB-85 bleiben unveraendert, siehe Abnahme SUB-111.
    expect(find.textContaining('[Platzhalter'), findsWidgets);
  });

  testWidgets('unbekannter Rechtstexte-Slug zeigt Fallback statt Absturz', (tester) async {
    final state = AppState(api: ApiClient());

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/rechtliches/unbekannt'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unbekannter Rechtstext'), findsOneWidget);
  });

  testWidgets('Footer auf der Landing Page verlinkt alle fuenf Rechtstexte', (tester) async {
    final state = AppState(api: ApiClient());

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/'));
    await tester.pumpAndSettle();

    for (final label in ['Impressum', 'AGB', 'Datenschutzerklaerung', 'Widerrufsbelehrung', 'Cookie-Hinweis']) {
      expect(find.widgetWithText(TextButton, label), findsOneWidget);
    }
  });

  testWidgets('Footer auf der Preisseite verlinkt alle fuenf Rechtstexte', (tester) async {
    final state = AppState(api: ApiClient());

    await tester.pumpWidget(SubsumoApp(state: state, initialLocation: '/preise'));
    await tester.pumpAndSettle();

    for (final label in ['Impressum', 'AGB', 'Datenschutzerklaerung', 'Widerrufsbelehrung', 'Cookie-Hinweis']) {
      expect(find.widgetWithText(TextButton, label), findsOneWidget);
    }
  });
}
