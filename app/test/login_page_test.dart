// Belegt, dass das Login-Redesign (SUB-37) die Designsystem-Komponenten
// nutzt statt eigener TextFormField/Button-Rohwidgets.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/design/design.dart';
import 'package:subsumo/pages/login_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Login nutzt SubsumoTextField und SubsumoButton', (tester) async {
    final state = AppState(api: ApiClient());

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SubsumoTextField), findsNWidgets(2));
    expect(find.byType(SubsumoButton), findsNWidgets(2));
    expect(find.text('Anmelden'), findsOneWidget);
  });

  testWidgets('Login zeigt Fehler ueber SubsumoFeedbackBlock', (tester) async {
    final state = AppState(api: ApiClient())..error = 'Login fehlgeschlagen';

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SubsumoFeedbackBlock), findsOneWidget);
  });
}
