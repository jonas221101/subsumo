import 'dart:math';

import 'package:flutter/material.dart';

/// Titeltext, der nie mitten im Wort umbricht: Zeilenumbrueche nur zwischen
/// Woertern; passt das laengste Wort nicht in die Breite, wird die Schrift
/// verkleinert (bis [minScale]) statt das Wort an beliebiger Stelle zu
/// trennen ("Wohnun/gseinbruchdiebstahl"). Erst unterhalb von [minScale]
/// bleibt es beim Umbruch bzw. bei der Ellipse.
class FitTitle extends StatelessWidget {
  const FitTitle(this.text, {required this.style, this.maxLines = 3, this.minScale = 0.7, super.key});

  final String text;
  final TextStyle style;
  final int maxLines;
  final double minScale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var effective = style;
        final available = constraints.maxWidth;
        if (available.isFinite) {
          final fontSize = style.fontSize ?? 16;
          var widest = 0.0;
          for (final word in text.split(RegExp(r'\s+'))) {
            final painter = TextPainter(
              text: TextSpan(text: word, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            widest = max(widest, painter.width);
            painter.dispose();
          }
          if (widest > available && widest > 0) {
            // Kleine Reserve, damit Rundung das Wort nicht doch umbrechen laesst.
            final scale = max(minScale, available / widest * 0.97);
            effective = style.copyWith(fontSize: fontSize * scale);
          }
        }
        return Text(text, style: effective, maxLines: maxLines, overflow: TextOverflow.ellipsis);
      },
    );
  }
}
