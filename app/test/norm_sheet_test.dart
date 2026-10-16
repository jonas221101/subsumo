// Feedback Test-Zugang: "Wenn ich auf den Artikel drücke, soll er bitte auch
// angezeigt werden." Tipp auf eine Normangabe oeffnet den Gesetzestext.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/pages/norm_sheet.dart';
import 'package:subsumo/pages/review_page.dart';
import 'package:subsumo/pages/schemata_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

http.Response _normResponse(http.Request r, {List<Map<String, dynamic>>? due}) {
  final path = r.url.path;
  if (path.endsWith('/v1/normen')) {
    final zitat = r.url.queryParameters['zitat']!;
    if (zitat.contains('LStVG')) {
      return http.Response(
          jsonEncode({
            'detail': {
              'message': 'Für diese Norm ist kein Text hinterlegt.',
              'quelle_url': 'https://www.gesetze-im-internet.de/',
            }
          }),
          404,
          headers: _json);
    }
    return http.Response(
        jsonEncode({
          'gesetz': 'BGB',
          'norm': '§ 433',
          'titel': 'Vertragstypische Pflichten beim Kaufvertrag',
          'text': '(1) Durch den Kaufvertrag wird der Verkäufer verpflichtet.\n'
              '(2) Der Käufer ist verpflichtet, den Kaufpreis zu zahlen.',
          'absatz': '2',
          'satz': null,
          'quelle_url': 'https://www.gesetze-im-internet.de/bgb/__433.html',
        }),
        200,
        headers: _json);
  }
  return http.Response(jsonEncode(due ?? []), 200, headers: _json);
}

Future<void> _pump(WidgetTester tester, Widget home,
    {List<Map<String, dynamic>>? due, Size size = const Size(420, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final client = MockClient((r) async => _normResponse(r, due: due));
  final state = AppState(api: ApiClient(client: client)..setToken('t'));
  if (due != null && home is ReviewPage) state.dueCards = due;
  await tester.pumpWidget(AppScope(
    notifier: state,
    child: MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: home),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final card = {
    'front': 'Was regelt der Kaufvertrag?',
    'back': 'Pflichten von Käufer und Verkäufer.',
    'norms': ['§ 433 Abs. 2 BGB', 'Art. 7 Abs. 2 LStVG'],
  };

  Future<void> reveal(WidgetTester tester) async {
    await tester.tap(find.text('Antwort zeigen'));
    await tester.pumpAndSettle();
  }

  testWidgets('Karten-Chip oeffnet Bottom-Sheet mit Normtext und markiertem Absatz',
      (tester) async {
    await _pump(
        tester, ReviewPage(focusMode: false, onToggleFocusMode: () {}),
        due: [card]);
    await reveal(tester);

    await tester.tap(find.text('§ 433 Abs. 2 BGB'));
    await tester.pumpAndSettle();

    expect(find.text('§ 433 BGB'), findsOneWidget);
    expect(find.text('Vertragstypische Pflichten beim Kaufvertrag'), findsOneWidget);
    expect(find.textContaining('(2) Der Käufer'), findsOneWidget);
    expect(find.byKey(const ValueKey('norm-absatz-hervorgehoben')), findsOneWidget);
    expect(find.text('Bei gesetze-im-internet.de öffnen'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('Auf breiten Schirmen erscheint ein Dialog', (tester) async {
    await _pump(
        tester, ReviewPage(focusMode: false, onToggleFocusMode: () {}),
        due: [card], size: const Size(1200, 900));
    await reveal(tester);

    await tester.tap(find.text('§ 433 Abs. 2 BGB'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.textContaining('(2) Der Käufer'), findsOneWidget);
  });

  testWidgets('Unbekannte Norm (Landesrecht): Hinweis und Link', (tester) async {
    await _pump(
        tester, ReviewPage(focusMode: false, onToggleFocusMode: () {}),
        due: [card]);
    await reveal(tester);

    await tester.tap(find.text('Art. 7 Abs. 2 LStVG'));
    await tester.pumpAndSettle();

    expect(find.text('Für diese Norm ist kein Text hinterlegt.'),
        findsOneWidget);
    expect(find.text('Bei gesetze-im-internet.de öffnen'), findsOneWidget);
    expect(find.byKey(const ValueKey('norm-absatz-hervorgehoben')), findsNothing);
  });

  testWidgets('Normdialog hat einen Schliessen-Button', (tester) async {
    await _pump(
        tester, ReviewPage(focusMode: false, onToggleFocusMode: () {}),
        due: [card]);
    await reveal(tester);
    await tester.tap(find.text('§ 433 Abs. 2 BGB'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(2) Der Käufer'), findsOneWidget);
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(2) Der Käufer'), findsNothing);
  });

  test('Linkbeschriftung je Domain und Kuerzung langer Normen', () {
    expect(quellenLinkLabel('https://eur-lex.europa.eu/eli/reg/2016/679'), 'Bei EUR-Lex öffnen');
    expect(quellenLinkLabel('https://recht.nrw.de/lmi/x'), 'Im Landesrechtsportal öffnen');
    expect(quellenLinkLabel('https://www.gesetze-im-internet.de/bgb/'), 'Bei gesetze-im-internet.de öffnen');
    expect(kurzeNormBeschriftung('§ 433 Abs. 2 BGB'), '§ 433 Abs. 2 BGB');
    expect(kurzeNormBeschriftung('Art. 6 DSGVO: Rechtmäßigkeit der Verarbeitung'), 'Art. 6 DSGVO');
    final lang = kurzeNormBeschriftung('Allgemeines Gleichbehandlungsgesetz Abschnitt 3 Unterabschnitt 2 Paragraph');
    expect(lang.length, 40);
    expect(lang, endsWith('…'));
  });

  testWidgets('Schemata: Normangabe ist nach dem Aufklappen antippbar', (tester) async {
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/v1/normen')) return _normResponse(r);
      return http.Response(
          jsonEncode([
            {
              'slug': 's1',
              'title': 'Kaufpreisanspruch',
              'area': 'zivilrecht',
              'norms': ['§ 433 Abs. 2 BGB'],
              'steps': <Map<String, dynamic>>[],
              'stand': '2026',
              'sources': <String>[],
            }
          ]),
          200,
          headers: _json);
    });
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final state = AppState(api: ApiClient(client: client)..setToken('t'));
    await tester.pumpWidget(AppScope(
      notifier: state,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(body: SchemataPage()),
      ),
    ));
    await tester.pumpAndSettle();

    // Im Kopf nur Text; Tippen klappt das Schema auf.
    await tester.tap(find.text('§ 433 Abs. 2 BGB'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(2) Der Käufer'), findsNothing);
    // Im aufgeklappten Inhalt ist die Norm ein Link.
    await tester.tap(find.byType(NormLink));
    await tester.pumpAndSettle();

    expect(find.textContaining('(2) Der Käufer'), findsOneWidget);
  });
}
