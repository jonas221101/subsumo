import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../design/design.dart';
import '../state.dart';
import '../theme.dart';
import 'checkout_page.dart';

/// F3 (docs/20-release-g2-bezahlstrecke.md Abschnitt 4): Konto-/Einstellungsseite.
/// Existierte vorher nicht - `HomeShell` (main.dart) verlinkt ueber die AppBar
/// hierher.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _busy = false;
  String? _error;
  String? _resultMessage;

  bool _exportBusy = false;
  String? _exportError;
  bool _deleteBusy = false;
  String? _deleteError;

  Future<void> _confirmAndCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abo kuendigen?'),
        content: const Text(
          'Dein Zugriff bleibt in der Regel bis zum Ende der aktuellen '
          'Abrechnungsperiode bestehen. Liegt der Kauf noch keine 14 Tage '
          'zurueck, greift stattdessen das Widerrufsrecht: sofortige '
          'Kuendigung mit voller Rueckerstattung.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kuendigen'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _cancel();
  }

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _error = null;
      _resultMessage = null;
    });
    final app = AppScope.of(context);
    try {
      final result = await app.api.cancelSubscription();
      await app.refreshUser();
      if (!mounted) return;
      final mode = result['mode'] as String?;
      setState(() {
        _resultMessage = mode == 'immediate_refund'
            ? 'Widerrufen: dein Abo wurde sofort beendet, die Zahlung wird '
                'vollstaendig erstattet.'
            : 'Gekuendigt: dein Zugriff bleibt bis zum Ende der aktuellen '
                'Abrechnungsperiode bestehen.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // 409 = kein aktives Abo (siehe B5) - eine verstaendliche Meldung
        // statt des technischen Fehlertexts vom Server.
        _error = e.statusCode == 409
            ? 'Es ist aktuell kein aktives Abo hinterlegt.'
            : e.message;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _error = 'Server nicht erreichbar. Bitte spaeter erneut versuchen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- SUB-103 (Art. 15/17 DSGVO, siehe SUB-84) -----------------------------

  Future<void> _exportData() async {
    setState(() {
      _exportBusy = true;
      _exportError = null;
    });
    final app = AppScope.of(context);
    try {
      final data = await app.api.exportAccountData();
      if (!mounted) return;
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      await _showExportDialog(pretty);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _exportError = e.message);
    } on Exception {
      if (!mounted) return;
      setState(() => _exportError = 'Server nicht erreichbar. Bitte spaeter erneut versuchen.');
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  /// Zeigt den Export als Text zum Pruefen/Kopieren an, statt einen
  /// Datei-Download auszuloesen: die App hat (noch) keine Plattform-Ordner
  /// (nur Web ist bislang eingerichtet), ein zusaetzliches Share-/Datei-Paket
  /// waere ungetestetes Terrain quer über alle Zielplattformen. Kopieren in
  /// die Zwischenablage deckt "speichern/teilen" ab, ohne diese Abhaengigkeit.
  Future<void> _showExportDialog(String pretty) async {
    var copied = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Deine Daten (Art. 15 DSGVO)'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: SelectableText(pretty, style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          actions: [
            if (copied)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                child: Text(
                  'In Zwischenablage kopiert.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: pretty));
                setDialogState(() => copied = true);
              },
              child: const Text('Kopieren'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Schliessen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konto unwiderruflich loeschen?'),
        content: const Text(
          'Dein Konto sowie alle gespeicherten Karten, Bewertungen und '
          'Einreichungen werden endgueltig geloescht. Das kann nicht '
          'rueckgaengig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Weiter'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final password = await _askPassword();
    if (password == null || !mounted) return;

    await _deleteAccount(password);
  }

  Future<String?> _askPassword() => showDialog<String>(
        context: context,
        builder: (context) => const _PasswordPromptDialog(),
      );

  Future<void> _deleteAccount(String password) async {
    setState(() {
      _deleteBusy = true;
      _deleteError = null;
    });
    final app = AppScope.of(context);
    try {
      await app.api.deleteAccount(password);
      await app.signOut();
      if (!mounted) return;
      // Springt zur Wurzel-Route zurueck (Login-Screen, siehe main.dart
      // `_Root`) statt nur den Dialog zu schliessen - das Konto existiert ab
      // hier serverseitig nicht mehr, `AccountPage`/`HomeShell` sind gestapelte
      // Navigator-Routen oberhalb dieser Route.
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _deleteError = switch (e.statusCode) {
          400 => 'Bestaetigung fehlt. Bitte erneut versuchen.',
          401 => 'Passwort ist falsch.',
          _ => e.message,
        };
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _deleteError = 'Server nicht erreichbar. Bitte spaeter erneut versuchen.');
    }
    if (mounted) setState(() => _deleteBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Konto')),
      body: ReadableWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SubsumoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Angemeldet als', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      app.user?['email'] as String? ?? '',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.lg),
              // Steht bewusst ausserhalb von [_SubscriptionCard]: nach einer
              // Widerrufs-Kuendigung (mode: immediate_refund) wird proActive
              // sofort false, wodurch die Karte auf die Free-Ansicht wechselt -
              // die Erfolgsmeldung muss diesen Zustandswechsel ueberleben.
              if (_resultMessage != null) ...[
                SubsumoFeedbackBlock(message: _resultMessage!, severity: FeedbackSeverity.positive),
                const SizedBox(height: Spacing.lg),
              ],
              _SubscriptionCard(
                app: app,
                busy: _busy,
                error: _error,
                onCancel: _confirmAndCancel,
              ),
              const SizedBox(height: Spacing.lg),
              _PrivacyCard(
                exportBusy: _exportBusy,
                exportError: _exportError,
                deleteBusy: _deleteBusy,
                deleteError: _deleteError,
                onExport: _exportData,
                onDelete: _confirmAndDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.app,
    required this.busy,
    required this.error,
    required this.onCancel,
  });

  final AppState app;
  final bool busy;
  final String? error;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!app.proActive) {
      return SubsumoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Abo', style: theme.textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            const SubsumoFeedbackBlock(
              message: 'Kein aktives Pro-Abo.',
              severity: FeedbackSeverity.neutral,
            ),
            const SizedBox(height: Spacing.md),
            SubsumoButton.primary(
              label: 'Pro werden',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CheckoutPage()),
              ),
            ),
          ],
        ),
      );
    }

    final until = app.proUntil;
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Abo', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          Text('Plan: Pro', style: theme.textTheme.bodyMedium),
          const SizedBox(height: Spacing.xs),
          Text(
            until != null ? 'Naechste Abrechnung/Zugriff bis: ${_formatDate(until)}' : 'Laeuft unbefristet',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: Spacing.md),
          if (app.cancelAtPeriodEnd) ...[
            SubsumoFeedbackBlock(
              message: 'Abo bereits gekuendigt, Zugriff bis '
                  '${until != null ? _formatDate(until) : 'Ende der Abrechnungsperiode'}.',
              severity: FeedbackSeverity.hint,
            ),
          ] else ...[
            SubsumoButton.secondary(
              label: busy ? 'Bitte warten ...' : 'Kuendigen',
              onPressed: busy ? null : onCancel,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: Spacing.sm),
            SubsumoFeedbackBlock(message: error!, severity: FeedbackSeverity.negative),
          ],
        ],
      ),
    );
  }
}

/// SUB-103 (Art. 15/17 DSGVO, siehe SUB-84): Datenexport und Kontoloeschung.
class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.exportBusy,
    required this.exportError,
    required this.deleteBusy,
    required this.deleteError,
    required this.onExport,
    required this.onDelete,
  });

  final bool exportBusy;
  final String? exportError;
  final bool deleteBusy;
  final String? deleteError;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SubsumoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Datenschutz', style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          SubsumoButton.secondary(
            label: exportBusy ? 'Bitte warten ...' : 'Meine Daten exportieren',
            onPressed: exportBusy ? null : onExport,
          ),
          if (exportError != null) ...[
            const SizedBox(height: Spacing.sm),
            SubsumoFeedbackBlock(message: exportError!, severity: FeedbackSeverity.negative),
          ],
          const SizedBox(height: Spacing.md),
          SubsumoButton.secondary(
            label: deleteBusy ? 'Bitte warten ...' : 'Konto loeschen',
            onPressed: deleteBusy ? null : onDelete,
          ),
          if (deleteError != null) ...[
            const SizedBox(height: Spacing.sm),
            SubsumoFeedbackBlock(message: deleteError!, severity: FeedbackSeverity.negative),
          ],
        ],
      ),
    );
  }
}

/// Eigenes [StatefulWidget] statt eines Controllers, der lokal in der
/// aufrufenden Methode erzeugt und nach `await showDialog(...)` sofort wieder
/// disposed wird: der Dialog spielt beim Schliessen noch eine Austritts-
/// animation ab, waehrend der der `TextFormField` den Controller weiter
/// braucht - ein sofortiges `dispose()` danach wirft "used after being
/// disposed". Als eigenes Widget uebernimmt Flutter das Timing selbst richtig.
class _PasswordPromptDialog extends StatefulWidget {
  const _PasswordPromptDialog();

  @override
  State<_PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<_PasswordPromptDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Passwort bestaetigen'),
      content: Form(
        key: _formKey,
        child: SubsumoTextField(
          label: 'Passwort',
          controller: _controller,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          validator: (v) => (v == null || v.isEmpty) ? 'Bitte Passwort eingeben' : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Konto endgueltig loeschen'),
        ),
      ],
    );
  }
}

/// Wie in dashboard_page.dart: bewusst ohne [DateTime.toLocal], damit ein
/// Abrechnungsende um Mitternacht UTC nicht je nach Zeitzone des Geraets auf
/// den Vor- oder Folgetag rutscht.
String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
