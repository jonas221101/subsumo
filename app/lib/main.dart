import 'package:flutter/material.dart';

import 'pages/cases_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/login_page.dart';
import 'pages/review_page.dart';
import 'pages/schemata_page.dart';
import 'state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SubsumoApp(state: AppState()..restoreSession()));
}

class SubsumoApp extends StatelessWidget {
  const SubsumoApp({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: state,
      child: MaterialApp(
        title: 'Subsumo',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return app.isAuthenticated && app.user != null
        ? const HomeShell()
        : const LoginPage();
  }
}

/// Navigationsgeruest. Auf schmalen Geraeten unten, ab Tablet-Breite als
/// seitliche Leiste - dasselbe Layout traegt Handy, Tablet, Windows und Web.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.insights_outlined, label: 'Fortschritt'),
    (icon: Icons.style_outlined, label: 'Karten'),
    (icon: Icons.account_tree_outlined, label: 'Schemata'),
    (icon: Icons.gavel_outlined, label: 'Faelle'),
  ];

  Widget get _page => switch (_index) {
        0 => const DashboardPage(),
        1 => const ReviewPage(),
        2 => const SchemataPage(),
        _ => const CasesPage(),
      };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final breit = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(_destinations[_index].label),
        actions: [
          if (app.outbox.isNotEmpty)
            IconButton(
              tooltip: '${app.outbox.length} Bewertung(en) nicht synchronisiert',
              icon: const Icon(Icons.cloud_upload_outlined),
              onPressed: app.flushOutbox,
            ),
          IconButton(
            tooltip: 'Abmelden',
            icon: const Icon(Icons.logout),
            onPressed: app.signOut,
          ),
        ],
      ),
      body: Row(
        children: [
          if (breit)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
          Expanded(child: _page),
        ],
      ),
      bottomNavigationBar: breit
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
    );
  }
}
