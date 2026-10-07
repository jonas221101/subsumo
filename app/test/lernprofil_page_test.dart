// Lernprofil-Seite (docs/33-individualisierung.md): rendert alle Stellschrauben,
// schickt beim Speichern das komplette Profil per PUT und schliesst sich.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/design/design.dart';
import 'package:subsumo/pages/lernprofil_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

const _themen = [
  {'slug': 'zr-bgb-at', 'title': 'BGB AT', 'area': 'zivilrecht', 'bundesland': null},
  {'slug': 'sr-bt-betrug', 'title': 'Betrug', 'area': 'strafrecht', 'bundesland': null},
];

// Fachgebiete der Fachrichtung (docs/34) - bei Jura die drei Rechtsgebiete.
const _areas = [
  {'slug': 'zivilrecht', 'title': 'Zivilrecht', 'kurz': 'ZR'},
  {'slug': 'strafrecht', 'title': 'Strafrecht', 'kurz': 'SR'},
  {'slug': 'oeffentliches-recht', 'title': 'Öffentliches Recht', 'kurz': 'ÖR'},
];

const _profil = {
  'semester': 3,
  'ziel': 'semesterklausur',
  'zielnote': null,
  'schwerpunkte': ['strafrecht'],
  'ruhetage': [6],
  'klausur_wochentag': 5,
  'wochenklausur': true,
  'neue_karten_pro_tag': 10,
  'sicherheitsniveau': 'standard',
  'themen_fokus': ['sr-bt-betrug'],
  'themen_pausiert': <String>[],
  'eigene_decks': [
    {'slug': 'mein-irrtum', 'title': 'Irrtuemer', 'topic_slugs': ['zr-bgb-at']},
  ],
  'eingerichtet': true,
  'persona': 'aufbau',
  'persona_label': 'Aufbau: Faelle und Gutachtentechnik',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<List<http.Request>> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/v1/me/lernprofil') {
        return _json({..._profil, ...jsonDecode(request.body) as Map});
      }
      if (request.url.path == '/v1/examen/cockpit') return _json({'profil': {}});
      return _json({'detail': 'nicht gemockt'}, 404);
    });
    final state = AppState(api: ApiClient(client: client));

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: SubsumoButton.primary(
                  label: 'oeffnen',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => const LernprofilPage(
                        profil: _profil,
                        themen: _themen,
                        areas: _areas,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('oeffnen'));
    await tester.pumpAndSettle();
    return requests;
  }

  testWidgets('zeigt Profilwerte und speichert das komplette Profil per PUT', (tester) async {
    final requests = await pump(tester);

    expect(find.text('Lernprofil'), findsOneWidget);
    expect(find.text('3. Semester'), findsOneWidget);
    expect(find.text('Neue Karten pro Tag: 10'), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    expect(find.text('Irrtuemer'), findsOneWidget);
    // Schwerpunkt-Chips und Themen-Abschnitte kommen aus `areas`, nicht aus
    // einer festen Jura-Liste: je Fachgebiet ein Chip und ein Abschnitt.
    expect(find.text('Öffentliches Recht'), findsNWidgets(2));
    expect(find.text('Zivilrecht'), findsNWidgets(2));

    // Ziel umschalten und Sicherheitsniveau auf "sicher" stellen.
    await tester.tap(find.text('Examen'));
    await tester.pump();
    await tester.tap(find.text('Sicher'));
    await tester.pump();

    await tester.tap(find.widgetWithText(SubsumoButton, 'Lernprofil speichern'));
    await tester.pumpAndSettle();

    final put = requests.singleWhere(
      (r) => r.method == 'PUT' && r.url.path == '/v1/me/lernprofil',
    );
    final body = jsonDecode(put.body) as Map<String, dynamic>;
    expect(body['ziel'], 'examen');
    expect(body['sicherheitsniveau'], 'sicher');
    expect(body['semester'], 3);
    expect(body['schwerpunkte'], ['strafrecht']);
    expect(body['themen_fokus'], ['sr-bt-betrug']);
    expect((body['eigene_decks'] as List).single['slug'], 'mein-irrtum');
    // Cockpit wird nach dem Speichern neu geladen, die Seite schliesst sich.
    expect(requests.any((r) => r.url.path == '/v1/examen/cockpit'), isTrue);
    expect(find.byType(LernprofilPage), findsNothing);
  });

  testWidgets('Fokus und Pause schliessen sich je Thema aus', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Strafrecht').last);
    await tester.pumpAndSettle();
    // Betrug ist im Fokus; Pause druecken nimmt den Fokus weg.
    await tester.tap(find.byTooltip('Pause: Betrug'));
    await tester.pump();
    IconButton button(String tooltip) => tester.widget<IconButton>(
          find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton)),
        );
    final fokus = button('Fokus: Betrug');
    final pause = button('Pause: Betrug');
    expect(fokus.isSelected, isFalse);
    expect(pause.isSelected, isTrue);
  });

  test('slugify erzeugt server-kompatible Deck-Slugs', () {
    expect(slugify('Mein BGB AT (Klausur)'), 'mein-bgb-at-klausur');
    expect(slugify('Ärger & Öl'), 'aerger-oel');
    expect(slugify('!!!'), 'deck');
  });
}
