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

  group('SubsumoTypography heroLarge/heroSmall (SUB-228)', () {
    testWidgets('heroLarge/heroSmall nutzen Fraunces statt Subsumo', (tester) async {
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));
      final typography = Theme.of(context).extension<SubsumoTypography>()!;

      expect(typography.heroLarge.fontFamily, 'Fraunces');
      expect(typography.heroLarge.fontSize, TypeScale.heroLarge);
      expect(typography.heroSmall.fontFamily, 'Fraunces');
      expect(typography.heroSmall.fontSize, TypeScale.heroSmall);
    });

    testWidgets('displayLarge/displayMedium bleiben bei Subsumo (Wortmarke unveraendert)',
        (tester) async {
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));
      final typography = Theme.of(context).extension<SubsumoTypography>()!;

      expect(typography.displayLarge.fontFamily, 'Subsumo');
      expect(typography.displayMedium.fontFamily, 'Subsumo');
    });
  });

  group('SubsumoColors Marketing-Rollen (SUB-228)', () {
    testWidgets('accentWash ist accent bei reduzierter Deckkraft', (tester) async {
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));
      final colors = Theme.of(context).extension<SubsumoColors>()!;

      expect(colors.accentWash.a, closeTo(0.08, 0.001));
      expect(colors.accentWash.withValues(alpha: colors.accent.a), colors.accent);
    });

    testWidgets('Rechtsgebiets-Akzente sind drei unterscheidbare, feste Farben',
        (tester) async {
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));
      final colors = Theme.of(context).extension<SubsumoColors>()!;

      final tones = {
        colors.legalAreaZivilrecht,
        colors.legalAreaStrafrecht,
        colors.legalAreaOeffentlichesRecht,
      };
      expect(tones, hasLength(3));
    });

    testWidgets('Hero-Verlauf ist unabhaengig von Light/Dark identisch (Marken-Band)',
        (tester) async {
      final lightScheme = SubsumoColors.forBrightness(Brightness.light);
      final darkScheme = SubsumoColors.forBrightness(Brightness.dark);

      expect(lightScheme.heroGradientStart, darkScheme.heroGradientStart);
      expect(lightScheme.heroGradientEnd, darkScheme.heroGradientEnd);
    });
  });

  group('SubsumoSection (SUB-228/SUB-240)', () {
    testWidgets('buildTheme(dark) rendert SubsumoSection/Hero-Text ohne Absturz',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Builder(
            builder: (context) {
              final typography = Theme.of(context).extension<SubsumoTypography>()!;
              return Scaffold(
                body: SubsumoSection(
                  background: SubsumoSectionBackground.heroGradient,
                  child: Text('Subsumo', style: typography.heroLarge.copyWith(color: Colors.white)),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Subsumo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('begrenzt den Inhalt intern ueber ReadableWidth', (tester) async {
      await tester.pumpWidget(
        _host(const SubsumoSection(child: Text('Sektion'))),
      );

      expect(find.text('Sektion'), findsOneWidget);
      expect(find.byType(ReadableWidth), findsOneWidget);
    });

    testWidgets('heroGradient nutzt einen Verlauf aus brand700/brand900', (tester) async {
      await tester.pumpWidget(
        _host(
          const SubsumoSection(
            background: SubsumoSectionBackground.heroGradient,
            child: Text('Hero'),
          ),
        ),
      );

      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      expect(
        (decoration.gradient as LinearGradient).colors,
        [SubsumoPalette.brand700, SubsumoPalette.brand900],
      );
    });

    testWidgets('brandDark rendert eine deckende brand900-Flaeche', (tester) async {
      await tester.pumpWidget(
        _host(
          const SubsumoSection(
            background: SubsumoSectionBackground.brandDark,
            child: Text('Footer'),
          ),
        ),
      );

      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, SubsumoPalette.brand900);
    });

    testWidgets('maxContentWidth wird an ReadableWidth durchgereicht', (tester) async {
      await tester.pumpWidget(
        _host(const SubsumoSection(maxContentWidth: 1100, child: Text('Breit'))),
      );

      final readable = tester.widget<ReadableWidth>(find.byType(ReadableWidth));
      expect(readable.maxWidth, 1100);
    });
  });
}
