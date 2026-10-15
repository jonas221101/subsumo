import 'dart:math';

import 'package:flutter/material.dart';

/// Deckt die drei bisherigen Chip-Verwendungen einheitlich ab: reine
/// Information (Kartentyp, "offline"), auswaehlbarer Filter (Rechtsgebiet)
/// und Aktion (Norm oeffnen). Aussehen (Form, Farben) kommt aus
/// `Theme.of(context).chipTheme`.
class SubsumoChip extends StatelessWidget {
  const SubsumoChip({
    required this.label,
    this.icon,
    super.key,
  })  : selected = null,
        onSelected = null,
        onPressed = null;

  const SubsumoChip.filter({
    required this.label,
    required bool this.selected,
    required ValueChanged<bool> this.onSelected,
    this.icon,
    super.key,
  }) : onPressed = null;

  const SubsumoChip.action({
    required this.label,
    required VoidCallback this.onPressed,
    this.icon,
    super.key,
  })  : selected = null,
        onSelected = null;

  final String label;
  final IconData? icon;
  final bool? selected;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final avatar = icon == null ? null : Icon(icon, size: 16);
    // In einem Wrap/Row bekommt der Chip sonst unbegrenzte Breite: lange
    // Quellenangaben ("Art. 7 Abs. 2 LStVG (Sicherheitsbehoerden ...") wuerden
    // abgeschnitten. Mit Obergrenze bricht das Label stattdessen um.
    final maxWidth = max(120.0, MediaQuery.sizeOf(context).width - 72);
    final text = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(label, softWrap: true),
    );

    if (onSelected != null) {
      return FilterChip(
        label: text,
        avatar: avatar,
        selected: selected!,
        onSelected: onSelected,
      );
    }
    if (onPressed != null) {
      return ActionChip(label: text, avatar: avatar, onPressed: onPressed);
    }
    return Chip(label: text, avatar: avatar);
  }
}
