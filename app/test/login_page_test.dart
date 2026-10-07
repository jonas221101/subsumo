// Belegt, dass das Login-Redesign (SUB-37) die Designsystem-Komponenten
// nutzt statt eigener TextFormField/Button-Rohwidgets - und dass die
// Registrierung die Fachrichtung des Build-Flavors mitschickt (docs/34).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  testWidgets('Login zeigt Fehler über SubsumoFeedbackBlock', (tester) async {
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

  testWidgets('Registrierung schickt die Fachrichtung des Build-Flavors mit', (tester) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final body = switch (request.url.path) {
        '/v1/auth/register' => {'access_token': 'tok', 'token_type': 'bearer'},
        '/v1/auth/me' => {'id': 1, 'email': 'neu@example.com', 'fachrichtung': 'jura'},
        _ => {'detail': 'nicht gemockt'},
      };
      return http.Response(
        jsonEncode(body),
        request.url.path == '/v1/auth/me' || request.url.path == '/v1/auth/register' ? 200 : 404,
        headers: {'content-type': 'application/json'},
      );
    });
    final state = AppState(api: ApiClient(client: client));

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

    await tester.tap(find.text('Neu hier? Konto erstellen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'neu@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'geheim123');
    await tester.tap(find.widgetWithText(SubsumoButton, 'Konto erstellen'));
    await tester.pumpAndSettle();

    final register = requests.singleWhere((r) => r.url.path == '/v1/auth/register');
    final body = jsonDecode(register.body) as Map<String, dynamic>;
    // Ohne --dart-define=SUBSUMO_FACH ist der Flavor `jura` (kFachrichtung).
    expect(kFachrichtung, 'jura');
    expect(body['fachrichtung'], 'jura');
    expect(body['email'], 'neu@example.com');
    expect(state.user?['fachrichtung'], 'jura');
  });
}
