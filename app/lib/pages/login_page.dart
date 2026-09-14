import 'package:flutter/material.dart';

import '../design/design.dart';
import '../state.dart';
import '../theme.dart';

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
    final app = AppScope.of(context);
    return Scaffold(
      body: ReadableWidth(
        maxWidth: 420,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Subsumo', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Jura lernen vom ersten Semester bis zum Examen.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Spacing.xl),
                SubsumoTextField(
                  label: 'E-Mail',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Bitte E-Mail eingeben' : null,
                ),
                const SizedBox(height: Spacing.md),
                SubsumoTextField(
                  label: 'Passwort',
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'Mindestens 8 Zeichen' : null,
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
                  label: app.loading
                      ? 'Bitte warten ...'
                      : (_register ? 'Konto erstellen' : 'Anmelden'),
                  onPressed: app.loading ? null : _submit,
                ),
                SubsumoButton.tertiary(
                  label: _register
                      ? 'Ich habe schon ein Konto'
                      : 'Neu hier? Konto erstellen',
                  onPressed: () => setState(() => _register = !_register),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
