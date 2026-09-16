// Belegt SUB-108: /preise ist oeffentlich (ohne Session) direkt aufrufbar,
// statt zur LoginPage umzuleiten - waehrend /app weiterhin den bisherigen
// Login-Gate-Fluss zeigt.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/main.dart';
import 'package:subsumo/pages/login_page.dart';
import 'package:subsumo/state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('/preise rendert ohne Session, kein Redirect zur LoginPage', (tester) async {
    final state = AppState(api: ApiClient());
    expect(state.isAuthenticated, isFalse);

    await tester.pumpWidget(
      SubsumoApp(state: state, initialLocation: '/preise'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preise'), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('/app zeigt weiterhin die LoginPage ohne Session', (tester) async {
    final state = AppState(api: ApiClient());

    await tester.pumpWidget(
      SubsumoApp(state: state, initialLocation: '/app'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });
}
