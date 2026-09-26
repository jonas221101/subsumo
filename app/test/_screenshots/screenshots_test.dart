// Rendert die App-Screens mit echten Schriften und echten Inhalten als PNG -
// fuer Design-Reviews ohne laufendes Fenster. Kein Regressionstest: laeuft
// nur, wenn SUBSUMO_SCREENSHOTS auf ein Verzeichnis mit den JSON-Fixtures
// zeigt, und schreibt nach test/_screenshots/goldens/ (nicht eingecheckt).
//
//   $env:SUBSUMO_SCREENSHOTS = "C:\...\data"
//   flutter test test/_screenshots --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/main.dart';
import 'package:subsumo/pages/gutachten_page.dart';
import 'package:subsumo/pages/login_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

final _dir = Platform.environment['SUBSUMO_SCREENSHOTS'];

dynamic _fixture(String name) => jsonDecode(File('$_dir/$name.json').readAsStringSync());

Future<void> _loadFonts() async {
  for (final (family, asset) in [
    ('Subsumo', 'assets/fonts/DejaVuSans.ttf'),
    ('Fraunces', 'assets/fonts/Fraunces-Variable.ttf'),
  ]) {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }
  // Icon-Schrift aus dem Flutter-SDK, damit Icons nicht als Kaestchen
  // erscheinen (nur fuer die Screenshots relevant).
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? r'C:\srclutter';
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final bytes = icons.readAsBytesSync();
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

AppState _state() {
  final client = MockClient((request) async {
    final path = request.url.path;
    Object body;
    if (path == '/v1/progress/coverage') {
      body = _fixture('coverage');
    } else if (path == '/v1/cards/due') {
      body = _fixture('due');
    } else if (path == '/v1/content/schemata') {
      body = _fixture('schemata');
    } else if (path == '/v1/content/cases') {
      body = _fixture('cases');
    } else if (path.startsWith('/v1/cases/')) {
      body = _fixture('case');
    } else if (path == '/v1/auth/me') {
      body = _fixture('me');
    } else if (path == '/v1/public/config') {
      body = {'paywall_enabled': false, 'ai_correction_enabled': false};
    } else if (path == '/v1/reviews/batch') {
      body = {'accepted': 1};
    } else {
      return http.Response('{}', 404);
    }
    return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  });
  return AppState(api: ApiClient(client: client)..setToken('t'))
    ..user = (_fixture('me') as Map).cast<String, dynamic>();
}

Future<void> _pump(WidgetTester tester, Widget home, {Size size = const Size(1280, 800), Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppScope(
      notifier: _state(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(brightness),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  final skip = _dir == null;

  testWidgets('heute', (tester) async {
    await _pump(tester, const HomeShell());
    await _shot(tester, '01-heute');
  }, skip: skip);

  testWidgets('heute dark', (tester) async {
    await _pump(tester, const HomeShell(), brightness: Brightness.dark);
    await _shot(tester, '02-heute-dark');
  }, skip: skip);

  testWidgets('karten', (tester) async {
    await _pump(tester, const HomeShell());
    await tester.tap(find.byIcon(Icons.style_outlined));
    await tester.pumpAndSettle();
    await _shot(tester, '03-karten-frage');
    await tester.tap(find.text('Antwort zeigen'));
    await tester.pumpAndSettle();
    await _shot(tester, '04-karten-antwort');
  }, skip: skip);

  testWidgets('schemata', (tester) async {
    await _pump(tester, const HomeShell());
    await tester.tap(find.byIcon(Icons.account_tree_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    await _shot(tester, '05-schemata');
  }, skip: skip);

  testWidgets('faelle', (tester) async {
    await _pump(tester, const HomeShell());
    await tester.tap(find.byIcon(Icons.gavel_outlined).last);
    await tester.pumpAndSettle();
    await _shot(tester, '06-faelle');
  }, skip: skip);

  testWidgets('gutachten', (tester) async {
    final c = (_fixture('case') as Map).cast<String, dynamic>();
    await _pump(tester, GutachtenPage(caseSlug: c['slug'] as String, caseTitle: c['title'] as String));
    await tester.enterText(
      find.byType(TextField),
      'A könnte gegen B einen Anspruch auf Herausgabe aus § 985 BGB haben. '
      'Dazu müsste A Eigentümer und B Besitzer ohne Recht zum Besitz sein.',
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await _shot(tester, '07-gutachten');
  }, skip: skip);

  testWidgets('login', (tester) async {
    await _pump(tester, const LoginPage());
    await _shot(tester, '08-login');
  }, skip: skip);

  testWidgets('mobil', (tester) async {
    await _pump(tester, const HomeShell(), size: const Size(390, 844));
    await _shot(tester, '09-mobil-heute');
    await tester.tap(find.byIcon(Icons.style_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antwort zeigen'));
    await tester.pumpAndSettle();
    await _shot(tester, '10-mobil-karten');
  }, skip: skip);
}
