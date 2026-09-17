// Belegt SUB-161 (SUB-153: Sichtbare Offline-Statusanzeige): der App-weite
// "offline"-Hinweis im AppBar erscheint zuverlaessig, wenn eines der beiden
// bestehenden Fehlschlag-Signale aus state.dart gesetzt ist, und bleibt sonst
// unsichtbar (kein staendig sichtbares Element ohne echten Grund).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/design/design.dart';
import 'package:subsumo/main.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

const _coverage = {
  'weighted_coverage': 0.5,
  'by_area': <String, double>{},
  'topics': <Map<String, Object?>>[],
};

Future<AppState> _pumpHomeShell(WidgetTester tester, {required AppState state}) async {
  await tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const HomeShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AppState buildState() {
    final client = MockClient((request) async => http.Response(
          jsonEncode(_coverage),
          200,
          headers: {'content-type': 'application/json'},
        ));
    return AppState(api: ApiClient(client: client))
      ..user = {'pro_active': true, 'pro_until': null, 'cancel_at_period_end': false};
  }

  testWidgets('ohne Fehlschlag-Signal ist kein offline-Hinweis sichtbar', (tester) async {
    await _pumpHomeShell(tester, state: buildState());

    expect(find.widgetWithText(SubsumoChip, 'offline'), findsNothing);
  });

  testWidgets('dueCardsFromCache zeigt den offline-Hinweis im AppBar', (tester) async {
    final state = buildState()..dueCardsFromCache = true;
    await _pumpHomeShell(tester, state: state);

    expect(find.widgetWithText(SubsumoChip, 'offline'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('ein wartendes Outbox-Review zeigt den offline-Hinweis im AppBar', (tester) async {
    final state = buildState()
      ..outbox.add(
        PendingReview(
          clientId: 'c1',
          cardSlug: 'bgb-985',
          rating: 3,
          reviewedAt: DateTime(2026, 1, 1),
        ),
      );
    await _pumpHomeShell(tester, state: state);

    expect(find.widgetWithText(SubsumoChip, 'offline'), findsOneWidget);
  });
}
