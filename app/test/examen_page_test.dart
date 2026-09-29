// Examen-Reiter (docs/32-examensvorbereitung.md): Onboarding ohne Profil,
// Cockpit mit Profil. Kein echtes Netz - MockClient liefert die JSON-Antworten
// von /v1/examen/*.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/design/design.dart';
import 'package:subsumo/pages/examen_page.dart';
import 'package:subsumo/pages/lernprofil_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

const _bundeslaender = [
  {
    'code': 'BY',
    'name': 'Bayern',
    'klausuren': {
      'anzahl': 6,
      'verteilung': {'zivilrecht': 3, 'strafrecht': 1, 'oeffentliches-recht': 2},
    },
    'pruefstatus': 'in-pruefung',
  },
  {
    'code': 'NW',
    'name': 'Nordrhein-Westfalen',
    'klausuren': {
      'anzahl': 7,
      'verteilung': {'zivilrecht': 3, 'strafrecht': 2, 'oeffentliches-recht': 2},
    },
    'pruefstatus': 'in-pruefung',
  },
];

const _universitaeten = [
  {'slug': 'lmu-muenchen', 'name': 'LMU', 'kurzname': 'LMU Muenchen', 'bundesland': 'BY'},
  {'slug': 'uni-koeln', 'name': 'Koeln', 'kurzname': 'Uni Koeln', 'bundesland': 'NW'},
];

Map<String, dynamic> _reife({double gesamt = 0.0, Object? technik}) => {
      'gesamt': gesamt,
      'formel': '0.50 x wissen + 0.50 x anwendung',
      'komponenten': {
        'wissen': {'label': 'Wissen', 'value': gesamt, 'detail': 'Kartenreife.'},
        'landesrecht': {'label': 'Landesrecht', 'value': null, 'detail': 'Ohne Bundesland nicht messbar.'},
        'anwendung': {'label': 'Anwendung', 'value': 0.0, 'detail': '0 von 60 Faellen.'},
        'technik': {'label': 'Gutachtentechnik', 'value': technik, 'detail': 'Noch keine Abgabe.'},
        'klausurpraxis': {'label': 'Klausurpraxis', 'value': 0.0, 'detail': '0 Klausuren.'},
      },
      'by_area': {
        'zivilrecht': {'coverage': gesamt, 'gewicht': 0.5, 'klausuren': 3},
        'strafrecht': {'coverage': 0.0, 'gewicht': 0.167, 'klausuren': 1},
        'oeffentliches-recht': {'coverage': 0.0, 'gewicht': 0.333, 'klausuren': 2},
      },
    };

const _deck = {
  'slug': 'zr-bgb-at',
  'title': 'BGB Allgemeiner Teil',
  'area': 'zivilrecht',
  'semester_default': 1,
  'examenskurs': false,
  'beschreibung': 'Rechtsgeschaeftslehre.',
  'klausurformat': {'typ': 'Anfaengerklausur', 'minuten': 120},
  'topic_count': 2,
  'landesrecht_kategorien': <String>[],
  'lernziele': ['Vertragsschluss pruefen'],
  'fehlende_themen': <String>[],
  'landesrecht_fehlt': <String>[],
  'topics': [
    {
      'slug': 'zr-bgb-at',
      'title': 'BGB AT',
      'area': 'zivilrecht',
      'relevance': 5,
      'bundesland': null,
      'cards_total': 8,
      'cards_started': 2,
      'cards_mature': 1,
      'cards_due': 2,
      'mastery': 0.125,
    },
  ],
  'schemata': [
    {'slug': 'zr-schema-433', 'title': 'Anspruch aus § 433 BGB', 'topic_slug': 'zr-bgb-at'},
  ],
  'cases': [
    {'slug': 'zr-fall-sonderpreis', 'title': 'Der Sonderpreis', 'topic_slug': 'zr-bgb-at', 'difficulty': 2, 'minutes': 45},
  ],
  'cards_total': 8,
  'cards_mature': 1,
  'cards_started': 2,
  'cards_due': 2,
  'mastery': 0.125,
};

const _lernprofilLeer = {
  'eingerichtet': false,
  'persona': 'einstieg',
  'persona_label': 'Einstieg: Karten und Schemata zuerst',
  'themen_fokus': <String>[],
  'themen_pausiert': <String>[],
  'eigene_decks': <Map<String, Object?>>[],
  'schwerpunkte': <String>[],
  'sicherheitsniveau': 'standard',
  'neue_karten_pro_tag': 10,
};

Map<String, dynamic> _cockpitOhneProfil() => {
      'lernprofil': _lernprofilLeer,
      'naechster_schritt': {
        'kind': 'profil',
        'titel': 'Lernprofil einrichten',
        'begruendung': 'Drei Minuten fuer passendere Empfehlungen.',
        'action': {'type': 'profil'},
      },
      'semesterstoff': null,
      'themen': [
        {'slug': 'zr-bgb-at', 'title': 'BGB AT', 'area': 'zivilrecht', 'bundesland': null},
      ],
      'eigene_decks': <Map<String, Object?>>[],
      'profil': {
        'bundesland': null,
        'universitaet': null,
        'exam_date': null,
        'daily_minutes': 90,
        'vollstaendig': false,
      },
      'phase': null,
      'examensreife': _reife(),
      'bundesland': null,
      'kurs_decks': [_deck],
      'landesrecht_deck': {'topics': <Map<String, Object?>>[], 'cards_total': 0, 'cards_mature': 0, 'cards_due': 0},
      'schwachstellen': {
        'themen': <Map<String, Object?>>[],
        'strukturfehler': <Map<String, Object?>>[],
        'abgaben': 0,
        'technik_tipp': null,
      },
      'naechste_klausur': {
        'datum': '2026-10-03',
        'vorschlag': {
          'slug': 'sr-fall-notwehr-schlagstock',
          'title': 'Der Schlagstock',
          'area': 'strafrecht',
          'topic_slug': 'sr-notwehr-32',
          'difficulty': 3,
          'minutes': 120,
          'begruendung': 'Schwaechstes Rechtsgebiet.',
        },
      },
      'checkliste': <Map<String, Object?>>[],
      'plan': <Map<String, Object?>>[],
    };

Map<String, dynamic> _cockpitMitProfil() => {
      ..._cockpitOhneProfil(),
      'lernprofil': {
        ..._lernprofilLeer,
        'eingerichtet': true,
        'semester': 4,
        'zielnote': 9,
        'schwerpunkte': ['strafrecht'],
        'persona': 'aufbau',
        'persona_label': 'Aufbau: Faelle und Gutachtentechnik',
        'themen_fokus': ['sr-bt-betrug'],
        'eigene_decks': [
          {'slug': 'mein-irrtum', 'title': 'Irrtuemer', 'topic_slugs': ['zr-bgb-at']},
        ],
      },
      'naechster_schritt': {
        'kind': 'fall',
        'titel': 'Fall zum Schwachpunkt: Der Trickbetrug',
        'begruendung': '3 verfehlte Pruefpunkte zu Betrug.',
        'action': {'type': 'case', 'slug': 'sr-fall-betrug', 'title': 'Der Trickbetrug', 'mode': 'uebung'},
      },
      'semesterstoff': {
        'semester': 4,
        'decks': ['zr-bgb-at'],
        'topics_total': 12,
        'cards_total': 90,
        'cards_mature': 27,
        'cards_due': 5,
        'mastery': 0.3,
      },
      'eigene_decks': [
        {
          'slug': 'mein-irrtum',
          'title': 'Irrtuemer',
          'eigenes': true,
          'topics': [
            {'slug': 'zr-bgb-at', 'title': 'BGB AT', 'area': 'zivilrecht', 'relevance': 5, 'bundesland': null, 'cards_total': 8, 'cards_started': 2, 'cards_mature': 1, 'cards_due': 2, 'mastery': 0.125},
          ],
          'cases': <Map<String, Object?>>[],
          'cards_total': 8,
          'cards_mature': 1,
          'cards_due': 2,
          'mastery': 0.125,
        },
      ],
      'profil': {
        'bundesland': {'code': 'BY', 'name': 'Bayern'},
        'universitaet': {'slug': 'lmu-muenchen', 'name': 'LMU', 'kurzname': 'LMU Muenchen'},
        'exam_date': '2027-03-01',
        'daily_minutes': 120,
        'vollstaendig': true,
      },
      'phase': {
        'exam_date': '2027-03-01',
        'tage_bis_examen': 150,
        'vorbereitungsbeginn': '2026-03-01',
        'phase': 'vertiefung',
        'fortschritt': 0.6,
        'phasen': [
          {'name': 'grundlagen', 'von': '2026-03-01', 'bis': '2026-09-18'},
          {'name': 'vertiefung', 'von': '2026-09-18', 'bis': '2027-01-06'},
          {'name': 'endspurt', 'von': '2027-01-06', 'bis': '2027-03-01'},
        ],
      },
      'examensreife': _reife(gesamt: 0.42, technik: 0.7),
      'bundesland': {
        'code': 'BY',
        'name': 'Bayern',
        'stand': '2026-09',
        'pruefstatus': 'in-pruefung',
        'pruefungsamt': {'name': 'LJPA', 'sitz': 'Muenchen'},
        'pruefungsordnung': 'JAPO',
        'klausuren': {
          'anzahl': 6,
          'dauer_minuten': 300,
          'verteilung': {'zivilrecht': 3, 'strafrecht': 1, 'oeffentliches-recht': 2},
        },
        'termine': ['Fruehjahr', 'Herbst'],
        'freiversuch': {'beschreibung': '§ 37 JAPO'},
        'abschichtung': {'moeglich': false, 'beschreibung': 'Keine Abschichtung.'},
        'notenverbesserung': {'beschreibung': '§ 15 JAPO'},
        'muendliche_pruefung': {'beschreibung': 'Pruefungsgespraech.'},
        'hilfsmittel': ['Schoenfelder', 'Ziegler/Tremml'],
        'landesrecht': {
          'schwerpunkte': ['Sicherheitsrecht (PAG, LStVG)'],
          'normenspiegel': {'polizei_generalklausel': 'Art. 11 Abs. 1 PAG'},
          'besonderheiten': ['Popularklage Art. 98 Satz 4 BV'],
        },
      },
      'landesrecht_deck': {
        'topics': [
          {
            'slug': 'by-polizei-ordnungsrecht',
            'title': 'Polizei- und Ordnungsrecht Bayern',
            'area': 'oeffentliches-recht',
            'relevance': 4,
            'bundesland': 'BY',
            'cards_total': 6,
            'cards_started': 0,
            'cards_mature': 0,
            'cards_due': 0,
            'mastery': 0.0,
          },
        ],
        'cards_total': 6,
        'cards_mature': 0,
        'cards_due': 0,
      },
      'schwachstellen': {
        'themen': [
          {'topic_slug': 'sr-bt-betrug', 'title': 'Betrug', 'verfehlte_pruefpunkte': 3, 'beispiele': ['Irrtum']},
        ],
        'strukturfehler': [
          {'code': 'urteilsstil', 'anzahl': 4},
        ],
        'abgaben': 2,
        'technik_tipp': {
          'code': 'urteilsstil',
          'anzahl': 4,
          'titel': 'Gutachten- statt Urteilsstil',
          'tipp': 'Erst die Frage, dann die Pruefung, dann das Ergebnis.',
        },
      },
      'checkliste': [
        {
          'monate_vor_examen': 6,
          'titel': 'Zugelassene Hilfsmittel besorgen',
          'detail': 'Gesetzessammlungen in der zugelassenen Ausgabe.',
          'jetzt_dran': true,
        },
      ],
      'plan': [
        {
          'date': '2026-09-28',
          'phase': 'vertiefung',
          'total_minutes': 120,
          'review_backlog': 0,
          'blocks': [
            {'kind': 'wiederholung', 'title': '40 faellige Karten', 'minutes': 14, 'topic_slug': '', 'area': ''},
            {'kind': 'fall', 'title': 'Fall & Wiederholung: BGB AT', 'minutes': 60, 'topic_slug': 'zr-bgb-at', 'area': 'zivilrecht'},
          ],
        },
      ],
    };

Future<AppState> _pump(WidgetTester tester, Map<String, dynamic> cockpit) async {
  // Der Examen-Reiter ist eine lange Liste; ein hoher Viewport baut alle
  // Karten auf, damit die Finder unten nicht am Lazy-Layout scheitern.
  tester.view.physicalSize = const Size(900, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final client = MockClient((request) async {
    switch (request.url.path) {
      case '/v1/examen/cockpit':
        return _json(cockpit);
      case '/v1/examen/bundeslaender':
        return _json(_bundeslaender);
      case '/v1/examen/universitaeten':
        return _json(_universitaeten);
      default:
        return _json({'detail': 'nicht gemockt: ${request.url.path}'}, 404);
    }
  });
  final state = AppState(api: ApiClient(client: client))
    ..user = {'pro_active': true, 'pro_until': null, 'cancel_at_period_end': false};

  await tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(body: ExamenPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ohne Profil steht das Onboarding mit Bundesland- und Uni-Auswahl oben',
      (tester) async {
    await _pump(tester, _cockpitOhneProfil());

    expect(find.text('Examensprofil einrichten'), findsOneWidget);
    expect(find.byKey(const ValueKey('bundesland')), findsOneWidget);
    expect(find.byKey(const ValueKey('universitaet')), findsOneWidget);
    expect(find.widgetWithText(SubsumoButton, 'Profil speichern'), findsOneWidget);
    // Naechster Schritt ohne Lernprofil: einrichten.
    expect(find.text('Lernprofil einrichten'), findsWidgets);
    expect(find.widgetWithText(SubsumoButton, 'Lernprofil einrichten'), findsOneWidget);
    expect(find.textContaining('Noch nicht eingerichtet'), findsOneWidget);
    // Ohne Examensdatum keine Phase, kein Tagesplan - aber der Katalog.
    expect(find.textContaining('Tage bis zum Examen'), findsNothing);
    expect(find.text('BGB Allgemeiner Teil'), findsOneWidget);
    expect(find.textContaining('Landesrecht: noch nicht messbar'), findsOneWidget);
  });

  testWidgets('mit Profil zeigt das Cockpit Reife, Phase, Plan, Klausur und Bundesland',
      (tester) async {
    await _pump(tester, _cockpitMitProfil());

    expect(find.text('Examensprofil einrichten'), findsNothing);
    expect(find.textContaining('Bayern  ·  LMU Muenchen  ·  Examen am 01.03.2027'), findsOneWidget);
    expect(find.text('150 Tage bis zum Examen'), findsOneWidget);
    expect(find.text('Phase: Vertiefung'), findsOneWidget);
    expect(find.text('42 %'), findsWidgets);
    // Eine Fortschrittsfarbe, keine Ampel: nur SubsumoProgressMeter, kein CircleAvatar.
    expect(find.byType(SubsumoProgressMeter), findsWidgets);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.textContaining('Heute  ·  120 min'), findsOneWidget);
    expect(find.text('Der Schlagstock'), findsOneWidget);
    expect(find.widgetWithText(SubsumoButton, 'Klausur schreiben'), findsOneWidget);
    expect(find.text('Landesrecht-Deck'), findsOneWidget);
    expect(find.text('Pruefung in Bayern'), findsOneWidget);
    expect(find.textContaining('6 Klausuren a 300 min'), findsOneWidget);
    expect(find.textContaining('Redaktionsstatus: in Pruefung'), findsWidgets);
    expect(find.text('Zugelassene Hilfsmittel besorgen'), findsOneWidget);
    // Individualisierung (docs/33): naechster Schritt, Lernprofil, Semesterstoff,
    // eigene Decks, Technik-Tipp.
    expect(find.text('Fall zum Schwachpunkt: Der Trickbetrug'), findsOneWidget);
    expect(find.widgetWithText(SubsumoButton, 'Fall bearbeiten'), findsOneWidget);
    expect(find.text('Aufbau: Faelle und Gutachtentechnik'), findsOneWidget);
    expect(find.textContaining('4. Semester  ·  Ziel 9 Punkte  ·  Schwerpunkt Strafrecht'),
        findsOneWidget);
    expect(find.textContaining('Bis 4. Semester  ·  27 von 90 Karten reif'), findsOneWidget);
    expect(find.text('Eigene Decks'), findsOneWidget);
    expect(find.text('Irrtuemer'), findsOneWidget);
    expect(find.text('Technik-Tipp: Gutachten- statt Urteilsstil'), findsOneWidget);
  });

  testWidgets('Lernprofil-Stift oeffnet die Lernprofil-Seite', (tester) async {
    await _pump(tester, _cockpitMitProfil());

    await tester.tap(find.byTooltip('Lernprofil bearbeiten'));
    await tester.pumpAndSettle();

    expect(find.byType(LernprofilPage), findsOneWidget);
    expect(find.text('4. Semester'), findsOneWidget);
  });

  testWidgets('Profil bearbeiten oeffnet den Editor mit vorbelegten Werten', (tester) async {
    await _pump(tester, _cockpitMitProfil());

    await tester.tap(find.byTooltip('Profil bearbeiten'));
    await tester.pumpAndSettle();

    expect(find.text('Examensprofil einrichten'), findsOneWidget);
    expect(find.text('Examen ab 01.03.2027'), findsOneWidget);
    expect(find.widgetWithText(SubsumoButton, 'Abbrechen'), findsOneWidget);
  });

  testWidgets('Deck-Detail zeigt Lernziele, Themen, Schemata und Faelle', (tester) async {
    await _pump(tester, _cockpitOhneProfil());

    await tester.tap(find.text('BGB Allgemeiner Teil'));
    await tester.pumpAndSettle();

    expect(find.byType(DeckDetailPage), findsOneWidget);
    expect(find.text('Vertragsschluss pruefen'), findsOneWidget);
    expect(find.text('Anspruch aus § 433 BGB'), findsOneWidget);
    expect(find.text('Der Sonderpreis'), findsOneWidget);
    expect(find.widgetWithText(SubsumoButton, 'Deck lernen (2 faellig)'), findsOneWidget);
  });
}
