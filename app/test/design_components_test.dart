import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subsumo/design/design.dart';
import 'package:subsumo/theme.dart';

Widget _host(Widget child) => MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: child),
    );

void main() {
  group('SubsumoButton', () {
    testWidgets('primary loest onPressed aus und zeigt das Label', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _host(SubsumoButton.primary(label: 'Abgeben', onPressed: () => tapped = true)),
      );

      expect(find.text('Abgeben'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(tapped, isTrue);
    });

    testWidgets('secondary rendert als OutlinedButton, tertiary als TextButton',
        (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              SubsumoButton.secondary(label: 'Erneut versuchen', onPressed: () {}),
              SubsumoButton.tertiary(label: 'Konto erstellen', onPressed: () {}),
            ],
          ),
        ),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('onPressed == null deaktiviert den Button', (tester) async {
      await tester.pumpWidget(_host(const SubsumoButton.primary(label: 'x', onPressed: null)));
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('SubsumoProgressMeter', () {
    testWidgets('zeigt Prozentwert und Label', (tester) async {
      await tester.pumpWidget(
        _host(const SubsumoProgressMeter(value: 0.62, label: 'Zivilrecht')),
      );

      expect(find.text('Zivilrecht'), findsOneWidget);
      expect(find.text('62 %'), findsOneWidget);
    });

    testWidgets('nutzt fuer jeden Wert dieselbe Fuellfarbe - keine Ampel', (tester) async {
      Color colorFor(double value) {
        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        return (indicator.valueColor as AlwaysStoppedAnimation<Color>).value;
      }

      await tester.pumpWidget(_host(const SubsumoProgressMeter(value: 0.1)));
      final lowColor = colorFor(0.1);

      await tester.pumpWidget(_host(const SubsumoProgressMeter(value: 0.95)));
      final highColor = colorFor(0.95);

      expect(lowColor, equals(highColor));
    });

    testWidgets('hat ein Screenreader-Label mit dem Prozentwert', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const SubsumoProgressMeter(value: 0.5, label: 'Strafrecht')),
      );

      expect(
        find.bySemanticsLabel('Strafrecht: 50 Prozent'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('SubsumoChip', () {
    testWidgets('filter meldet Auswahl ueber onSelected', (tester) async {
      bool? selected;
      await tester.pumpWidget(
        _host(
          SubsumoChip.filter(
            label: 'Zivilrecht',
            selected: false,
            onSelected: (v) => selected = v,
          ),
        ),
      );

      await tester.tap(find.byType(FilterChip));
      expect(selected, isTrue);
    });

    testWidgets('action loest onPressed aus', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _host(SubsumoChip.action(label: '§ 985 BGB', onPressed: () => tapped = true)),
      );

      await tester.tap(find.byType(ActionChip));
      expect(tapped, isTrue);
    });

    testWidgets('ohne Callback ist es ein reiner Info-Chip', (tester) async {
      await tester.pumpWidget(_host(const SubsumoChip(label: 'offline')));
      expect(find.byType(Chip), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
    });
  });

  group('SubsumoFeedbackBlock', () {
    testWidgets('zeigt Nachricht und optionales Detail', (tester) async {
      await tester.pumpWidget(
        _host(
          const SubsumoFeedbackBlock(
            message: 'Obersatz fehlt',
            detail: 'Beginne mit "A koennte gegen B einen Anspruch haben."',
            severity: FeedbackSeverity.negative,
          ),
        ),
      );

      expect(find.text('Obersatz fehlt'), findsOneWidget);
      expect(find.textContaining('Beginne mit'), findsOneWidget);
    });

    testWidgets('negative Schwere nutzt die Fehlerfarbe des Themes', (tester) async {
      await tester.pumpWidget(
        _host(
          const SubsumoFeedbackBlock(message: 'x', severity: FeedbackSeverity.negative),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      final context = tester.element(find.byType(SubsumoFeedbackBlock));
      expect(icon.color, Theme.of(context).colorScheme.error);
    });
  });

  group('SubsumoTextField', () {
    testWidgets('zeigt Label und validiert', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _host(
          Form(
            key: formKey,
            child: SubsumoTextField(
              label: 'E-Mail',
              validator: (v) => (v == null || !v.contains('@')) ? 'Bitte E-Mail eingeben' : null,
            ),
          ),
        ),
      );

      expect(find.text('E-Mail'), findsOneWidget);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Bitte E-Mail eingeben'), findsOneWidget);
    });
  });

  group('SubsumoCard', () {
    testWidgets('rendert Kindinhalt innerhalb einer Card', (tester) async {
      await tester.pumpWidget(_host(const SubsumoCard(child: Text('Inhalt'))));
      expect(find.text('Inhalt'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });
  });
}
