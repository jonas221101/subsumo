import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Vorspann-Label ueber einem Titel oder Block ("HEUTE", "SACHVERHALT",
/// "DEFINITION · 12 OFFEN"): klein, gesperrt, in Versalien. Ersetzt die
/// bisher pro Screen frei gesetzten `bodySmall`-Ueberschriften durch eine
/// wiedererkennbare Form - das Gegenstueck zur Kolumnentitel-Zeile in
/// einem gesetzten Kommentar.
///
/// Farbe ist bewusst immer `onSurfaceVariant` (bzw. explizit uebergeben fuer
/// dunkle Flaechen) - ein Eyebrow ist Orientierung, kein Signal.
class SubsumoEyebrow extends StatelessWidget {
  const SubsumoEyebrow(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.extension<SubsumoTypography>()!.eyebrow;
    return Text(
      text.toUpperCase(),
      style: style.copyWith(color: color ?? theme.colorScheme.onSurfaceVariant),
    );
  }
}
