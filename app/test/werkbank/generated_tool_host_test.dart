import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subsumo/theme.dart';
import 'package:subsumo/werkbank/generated_tool_host.dart';
import 'package:subsumo/werkbank/tool_spec_labeling.dart';

const _badgeText = 'KI-Vorschlag · ungeprüft';

Map<String, dynamic> _toolSpec({Object? labeling = const {
  'is_suggestion': true,
  'badge_text': _badgeText,
}}) => {
      'schema': 'subsumo.werkbank.tool_spec.v2',
      if (labeling != null) 'labeling': labeling,
    };

Widget _host(Widget child) => MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: child),
    );

void main() {
  group('ToolSpecLabeling.fromToolSpecJson', () {
    test('liest is_suggestion/badge_text aus einem gueltigen Spec', () {
      final labeling = ToolSpecLabeling.fromToolSpecJson(_toolSpec());
      expect(labeling, isNotNull);
      expect(labeling!.badgeText, _badgeText);
    });

    test('fehlendes labeling -> null (fail-closed)', () {
      expect(ToolSpecLabeling.fromToolSpecJson(_toolSpec(labeling: null)), isNull);
    });

    test('is_suggestion != true -> null (fail-closed)', () {
      final spec = _toolSpec(labeling: {
        'is_suggestion': false,
        'badge_text': _badgeText,
      });
      expect(ToolSpecLabeling.fromToolSpecJson(spec), isNull);
    });

    test('fehlendes badge_text -> null (fail-closed)', () {
      final spec = _toolSpec(labeling: {'is_suggestion': true});
      expect(ToolSpecLabeling.fromToolSpecJson(spec), isNull);
    });

    test('leeres badge_text -> null (fail-closed)', () {
      final spec = _toolSpec(labeling: {'is_suggestion': true, 'badge_text': ''});
      expect(ToolSpecLabeling.fromToolSpecJson(spec), isNull);
    });
  });

  group('GeneratedToolBadge', () {
    testWidgets('zeigt den exakten Wortlaut aus dem Spec', (tester) async {
      final labeling = ToolSpecLabeling.fromToolSpecJson(_toolSpec())!;
      await tester.pumpWidget(_host(GeneratedToolBadge(labeling: labeling)));

      expect(find.text(_badgeText), findsOneWidget);
    });

    testWidgets('hat keinen Dismiss-Pfad (kein onDeleted, kein Icon-Button)',
        (tester) async {
      final labeling = ToolSpecLabeling.fromToolSpecJson(_toolSpec())!;
      await tester.pumpWidget(_host(GeneratedToolBadge(labeling: labeling)));

      final chip = tester.widget<Chip>(find.byType(Chip));
      expect(chip.onDeleted, isNull);
      expect(chip.deleteIcon, isNull);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(Dismissible), findsNothing);
    });
  });

  group('GeneratedToolHost', () {
    testWidgets('rendert Badge und Werkzeug-Inhalt bei gueltiger Kennzeichnung',
        (tester) async {
      await tester.pumpWidget(
        _host(
          GeneratedToolHost(
            toolSpec: _toolSpec(),
            toolContent: const Text('Werkzeug-Ausgabe'),
          ),
        ),
      );

      expect(find.text(_badgeText), findsOneWidget);
      expect(find.text('Werkzeug-Ausgabe'), findsOneWidget);
    });

    testWidgets('fail-closed: kein Werkzeug-Inhalt ohne gueltige Kennzeichnung',
        (tester) async {
      await tester.pumpWidget(
        _host(
          GeneratedToolHost(
            toolSpec: _toolSpec(labeling: null),
            toolContent: const Text('Werkzeug-Ausgabe'),
          ),
        ),
      );

      expect(find.text('Werkzeug-Ausgabe'), findsNothing);
      expect(find.text(_badgeText), findsNothing);
    });

    testWidgets('fail-closed bei is_suggestion != true', (tester) async {
      await tester.pumpWidget(
        _host(
          GeneratedToolHost(
            toolSpec: _toolSpec(labeling: {
              'is_suggestion': false,
              'badge_text': _badgeText,
            }),
            toolContent: const Text('Werkzeug-Ausgabe'),
          ),
        ),
      );

      expect(find.text('Werkzeug-Ausgabe'), findsNothing);
    });

    testWidgets('selbe Kennzeichnung nach erneutem Aufbau aus demselben Spec',
        (tester) async {
      final spec = _toolSpec();

      await tester.pumpWidget(
        _host(GeneratedToolHost(toolSpec: spec, toolContent: const SizedBox())),
      );
      expect(find.text(_badgeText), findsOneWidget);

      // Simuliert einen erneuten Aufruf/App-Neustart: frischer Widget-Baum,
      // dasselbe persistierte Artefakt - keine clientseitige Zwischenablage.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _host(GeneratedToolHost(toolSpec: spec, toolContent: const SizedBox())),
      );
      expect(find.text(_badgeText), findsOneWidget);
    });
  });
}
