import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';

/// Anmeldung/Registrierung. Ab 800px zweigeteilt: links die Markenflaeche
/// (Hero-Verlauf, Serifen-Claim), rechts das Formular. Darunter einspaltig
/// mit der Wortmarke ueber dem Formular. Der Claim ist sachlich - keine
/// Superlative, keine KI-Werbung (docs/21 Abschnitt 1).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _register = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await AppScope.of(context).signIn(
      _email.text.trim(),
      _password.text,
      register: _register,
    );
  }

  @override
  Widget build(BuildContext context) {
    final breit = MediaQuery.sizeOf(context).width >= 800;
    final form = _buildForm(context, showWordmark: !breit);

    return Scaffold(
      body: breit
          ? Row(
              children: [
                const Expanded(flex: 5, child: _BrandPane()),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SingleChildScrollView(
                      child: ReadableWidth(
                        maxWidth: 420,
                        child: Padding(padding: const EdgeInsets.all(Spacing.xxl), child: form),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: SingleChildScrollView(
                child: ReadableWidth(
                  maxWidth: 420,
                  child: Padding(padding: const EdgeInsets.all(Spacing.xl), child: form),
                ),
              ),
            ),
    );
  }

  Widget _buildForm(BuildContext context, {required bool showWordmark}) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final typography = theme.extension<SubsumoTypography>()!;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showWordmark) ...[
            const SubsumoWordmark(large: true, accent: true),
            const SizedBox(height: Spacing.xxl),
          ],
          SubsumoEyebrow(_register ? 'Neues Konto' : 'Willkommen zurück'),
          const SizedBox(height: Spacing.sm),
          Text(_register ? 'Konto erstellen' : 'Melde dich an', style: typography.headingLarge),
          const SizedBox(height: Spacing.xs),
          Text(
            'Jura lernen vom ersten Semester bis zum Examen.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.xl),
          SubsumoTextField(
            label: 'E-Mail',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (v) => (v == null || !v.contains('@')) ? 'Bitte E-Mail eingeben' : null,
          ),
          const SizedBox(height: Spacing.md),
          SubsumoTextField(
            label: 'Passwort',
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            validator: (v) => (v == null || v.length < 8) ? 'Mindestens 8 Zeichen' : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (app.error != null) ...[
            const SizedBox(height: Spacing.md),
            SubsumoFeedbackBlock(
              message: app.error!,
              severity: FeedbackSeverity.negative,
            ),
          ],
          const SizedBox(height: Spacing.xl),
          SubsumoButton.primary(
            label: app.loading ? 'Bitte warten ...' : (_register ? 'Konto erstellen' : 'Anmelden'),
            onPressed: app.loading ? null : _submit,
          ),
          SubsumoButton.tertiary(
            label: _register ? 'Ich habe schon ein Konto' : 'Neu hier? Konto erstellen',
            onPressed: () => setState(() => _register = !_register),
          ),
        ],
      ),
    );
  }
}

/// Linke Markenflaeche des Desktop-Logins. Nutzt denselben Hero-Verlauf wie
/// die Landingpage ([SubsumoColors.heroGradientStart/End]) - eine Marke,
/// eine Flaeche. Text durchgehend weiss (gegen brand900 geprueft, docs/11
/// Abschnitt 5).
class _BrandPane extends StatelessWidget {
  const _BrandPane();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<SubsumoColors>()!;
    final typography = theme.extension<SubsumoTypography>()!;
    const white = Colors.white;
    final muted = white.withValues(alpha: 0.72);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.heroGradientStart, colors.heroGradientEnd],
        ),
      ),
      // Scrollbar, sobald das Fenster niedriger ist als der Inhalt (z. B.
      // 600px hohes Fenster) - sonst laeuft die Flaeche ueber statt zu
      // scrollen.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Theme(
                    data: theme.copyWith(colorScheme: theme.colorScheme.copyWith(primary: white)),
                    child: const SubsumoWordmark(accent: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gutachten schreiben lernt man nur durch Schreiben.',
                          style: typography.heroSmall.copyWith(color: white),
                        ),
                        const SizedBox(height: Spacing.xl),
                        for (final line in const [
                          'Karteikarten mit Spaced Repetition, gezählt wird nur, was sitzt.',
                          'Schemata in echter Gliederung, vom Obersatz bis zum Ergebnis.',
                          'Fälle mit Erwartungshorizont, jeder Abzug nachvollziehbar.',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: Spacing.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 9),
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                                  ),
                                ),
                                const SizedBox(width: Spacing.md),
                                Expanded(
                                  child: Text(line, style: theme.textTheme.bodyLarge?.copyWith(color: muted)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    'Lernhilfe, keine Rechtsberatung.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
