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
        if (available.isFinite && available > 0) {
          // Passt der Titel auch umgebrochen nicht in [maxLines], Schrift
          // schrittweise bis [minScale] verkleinern, statt zu kuerzen.
          final base = effective.fontSize ?? 16;
          final floor = (style.fontSize ?? 16) * minScale;
          var size = base;
          while (true) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: effective.copyWith(fontSize: size)),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: maxLines,
            )..layout(maxWidth: available);
            final exceeds = painter.didExceedMaxLines;
            painter.dispose();
            if (!exceeds || size <= floor) break;
            size = max(floor, size - 1);
          }
          if (size != base) effective = effective.copyWith(fontSize: size);
        }
        return Text(text, style: effective, maxLines: maxLines, overflow: TextOverflow.ellipsis);
      },
    );
  }
}
