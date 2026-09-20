// Belegt SUB-160 (Fokussierter Lesemodus): der Umschalter zurueck zur
// Normalansicht muss unabhaengig vom Karten-Zustand erreichbar bleiben -
// insbesondere auch, wenn waehrend des Lesemodus die letzte faellige Karte
// bewertet wird und der Screen in den Leerzustand wechselt. Ohne diese
// Absicherung waere die Navigation dauerhaft ausgeblendet und die
// Rueckkehr aus dem Lesemodus blockiert.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/pages/review_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

Future<AppState> _pump(
  WidgetTester tester, {
  required List<Map<String, dynamic>> dueCards,
  required bool focusMode,
  required VoidCallback onToggleFocusMode,
}) async {
  final client = MockClient((request) async => http.Response(
        jsonEncode(dueCards),
        200,
        headers: {'content-type': 'application/json'},
      ));
  final state = AppState(api: ApiClient(client: client)..setToken('t'))..dueCards = dueCards;
  await tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: ReviewPage(focusMode: focusMode, onToggleFocusMode: onToggleFocusMode),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Umschalter ruft onToggleFocusMode auf und zeigt den passenden Zustand',
      (tester) async {
    var toggled = false;
    await _pump(
      tester,
      dueCards: const [
        {'front': 'Was regelt § 985 BGB?', 'back': 'Herausgabeanspruch des Eigentuemers.'},
      ],
      focusMode: false,
      onToggleFocusMode: () => toggled = true,
    );

    expect(find.byIcon(Icons.fullscreen_outlined), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen_exit_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.fullscreen_outlined));
    expect(toggled, isTrue);
  });

  testWidgets(
      'Umschalter bleibt im Leerzustand sichtbar - Rueckkehr aus dem Lesemodus jederzeit moeglich',
      (tester) async {
    await _pump(
      tester,
      dueCards: const [],
      focusMode: true,
      onToggleFocusMode: () {},
    );

    expect(find.text('Nichts faellig. Gut gemacht.'), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen_exit_outlined), findsOneWidget);
  });
}
