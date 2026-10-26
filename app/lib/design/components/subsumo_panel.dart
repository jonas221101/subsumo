import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Flaeche mit Haarlinie fuer inhaltliche Bloecke, die keine [Card] sein
/// sollen: Listenzeilen, Kennzahl-Kacheln, Seitenleisten-Boxen. Gleiche
/// Optik wie [SubsumoCard] (Haarlinie, Radius, Papierflaeche), aber ohne
/// Material-Card-Semantik - und damit auch ohne die impliziten
/// InkWell-/Clip-Kosten einer Card in langen Listen.
///
/// [tone] waehlt zwischen der hellen Karten-Flaeche (Standard) und der
/// abgesetzten Seitenleisten-Flaeche (`surfaceContainerHigh`) - beides
/// bestehende Rollen, keine neue Farbe.
class SubsumoPanel extends StatelessWidget {
  const SubsumoPanel({
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.tone = SubsumoPanelTone.card,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final SubsumoPanelTone tone;

  /// Optional anklickbar (z. B. Fall-Zeile). Der Ink-Effekt bleibt innerhalb
  /// des Radius.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      SubsumoPanelTone.card => scheme.surface,
      SubsumoPanelTone.raised => scheme.surfaceContainerHigh,
      SubsumoPanelTone.brand => scheme.primaryContainer,
    };
    final radius = BorderRadius.circular(Radii.md);

    final body = Padding(padding: padding, child: child);
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

enum SubsumoPanelTone { card, raised, brand }
