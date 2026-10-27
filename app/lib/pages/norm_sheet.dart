import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../design/design.dart';
import '../state.dart';

const String kGiiStartUrl = 'https://www.gesetze-im-internet.de/';

/// Kuerzt eine lange Norm-Beschriftung fuer Chips/Links: schneidet bei
/// Doppelpunkt oder oeffnender Klammer ab und begrenzt auf [max] Zeichen
/// (mit Ellipse). Der volle Text bleibt im Dialog-Titel.
String kurzeNormBeschriftung(String zitat, {int max = 40}) {
  var text = zitat.trim();
  final cut = RegExp(r'[:(]').firstMatch(text);
  if (cut != null && cut.start > 3) text = text.substring(0, cut.start).trim();
  if (text.length > max) text = '${text.substring(0, max - 1).trimRight()}…';
  return text;
}

/// Beschriftung des Quellen-Links je nach Domain.
String quellenLinkLabel(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (host.contains('eur-lex')) return 'Bei EUR-Lex öffnen';
  if (host.isNotEmpty && !host.contains('gesetze-im-internet')) {
    return 'Im Landesrechtsportal öffnen';
  }
  return 'Bei gesetze-im-internet.de öffnen';
}

/// Oeffnet den Gesetzestext zu [zitat]: Bottom-Sheet auf schmalen Schirmen,
/// Dialog auf breiten. Nur fuer strukturierte `norms`-Felder gedacht, nicht
/// fuer Freitext.
Future<void> showNormText(BuildContext context, String zitat) {
  final api = AppScope.of(context).api;
  final wide = MediaQuery.sizeOf(context).width >= 720;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
          child: NormTextView(api: api, zitat: zitat),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (context) => NormTextView(api: api, zitat: zitat),
  );
}

/// Dezent unterstrichene, antippbare Normangabe (Fliesstext-Stil).
class NormLink extends StatelessWidget {
  const NormLink(this.zitat, {this.style, super.key});

  final String zitat;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Normtext anzeigen: $zitat',
      child: InkWell(
        onTap: () => showNormText(context, zitat),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            kurzeNormBeschriftung(zitat),
            style: (style ?? theme.textTheme.bodySmall)?.copyWith(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inhalt von Sheet/Dialog: laedt den Normtext und zeigt ihn mit
/// hervorgehobenem Absatz.
class NormTextView extends StatefulWidget {
  const NormTextView({required this.api, required this.zitat, super.key});

  final ApiClient api;
  final String zitat;

  @override
  State<NormTextView> createState() => _NormTextViewState();
}

class _NormTextViewState extends State<NormTextView> {
  late Future<Map<String, dynamic>> _future = widget.api.normText(widget.zitat);

  void _retry() => setState(() => _future = widget.api.normText(widget.zitat));

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: Spacing.md),
                Text(widget.zitat),
              ],
            ),
          );
        }
        if (snap.hasError) return _buildError(context, snap.error!);
        return _buildText(context, snap.data!);
      },
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    final theme = Theme.of(context);
    final notFound = error is ApiException && error.statusCode == 404;
    String url = kGiiStartUrl;
    String? apiMessage;
    if (error is ApiException) {
      url = error.detail?['quelle_url'] as String? ?? kGiiStartUrl;
      // Differenzierte Meldung des Backends (EU-Recht, Landesrecht ...).
      final m = error.detail?['message'];
      if (m is String && m.trim().isNotEmpty) apiMessage = m;
    }
    return Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(context, widget.zitat, theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.md),
          Text(
            apiMessage ??
                (notFound
                ? 'Für diese Norm ist kein Text hinterlegt – Landesrecht oder nicht erfasst.'
                : 'Der Normtext konnte gerade nicht geladen werden.'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            children: [
              if (!notFound)
                TextButton(onPressed: _retry, child: const Text('Erneut versuchen')),
              TextButton.icon(
                onPressed: () => _open(url),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(quellenLinkLabel(url)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Titelzeile mit sichtbarem Schliessen-Button oben rechts.
  Widget _titleRow(BuildContext context, String title, TextStyle? style) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Text(title, style: style),
            ),
          ),
          IconButton(
            tooltip: 'Schließen',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      );

  Widget _buildText(BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final absatz = data['absatz'] as String?;
    final titel = data['titel'] as String? ?? '';
    final lines = (data['text'] as String? ?? '').split('\n');
    final marker = absatz == null ? null : '($absatz)';
    // Hervorhebung nur, wenn der Text den Absatz wirklich ausweist.
    final hasMarker = marker != null && lines.any((l) => l.startsWith('$marker '));
    final url = data['quelle_url'] as String? ?? kGiiStartUrl;

    // Absatz-Zeilen: alles bis zum naechsten "(n)" gehoert zum Absatz.
    final highlighted = <bool>[];
    var inside = false;
    for (final l in lines) {
      if (RegExp(r'^\(\d+[a-z]?\) ').hasMatch(l)) inside = l.startsWith('$marker ');
      highlighted.add(hasMarker && inside);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.sm, Spacing.xl, Spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(
            context,
            widget.zitat.length > 40 ? widget.zitat : '${data['norm']} ${data['gesetz']}',
            theme.textTheme.titleLarge,
          ),
          if (titel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text(titel,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          const SizedBox(height: Spacing.md),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < lines.length; i++)
                    Container(
                      key: highlighted[i] ? const ValueKey('norm-absatz-hervorgehoben') : null,
                      margin: const EdgeInsets.only(bottom: Spacing.xs),
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm, vertical: Spacing.xs),
                      decoration: highlighted[i]
                          ? BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            )
                          : null,
                      child: Text(lines[i], style: theme.textTheme.bodyMedium),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          TextButton.icon(
            onPressed: () => _open(url),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(quellenLinkLabel(url)),
          ),
        ],
      ),
    );
  }
}
