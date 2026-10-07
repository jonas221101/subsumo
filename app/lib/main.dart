import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'design/design.dart';
import 'pages/account_page.dart';
import 'pages/cases_page.dart';
import 'pages/checkout_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/examen_page.dart';
import 'pages/login_page.dart';
import 'pages/public/public_landing_page.dart';
import 'pages/public/public_legal_page.dart';
import 'pages/public/public_pricing_page.dart';
import 'pages/review_page.dart';
import 'pages/schemata_page.dart';
import 'state.dart';
import 'theme.dart';

/// Werte, auf die F2 (Checkout-Rueckkehr, siehe docs/20-release-g2-bezahlstrecke.md)
/// reagiert. Jeder andere Wert (kein Rueckkehr-Link) zeigt keinen Hinweis.
const _handledCheckoutStatuses = {'success', 'cancelled'};

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Pfadbasierte URLs (/preise) statt Hash-Routing (/#/preise) - noetig,
  // damit die oeffentlichen Marketing-/Rechtsseiten als echte, teilbare
  // Web-URLs funktionieren (SUB-108). No-op auf Nicht-Web-Plattformen.
  usePathUrlStrategy();
  runApp(SubsumoApp(state: AppState()..restoreSession()));
}

/// Oeffentliche Routen (`/`, `/preise`, `/rechtliches/:slug`) rendern
/// unabhaengig vom Login-Status - fuer G5 (SUB-104: Landing Page, Preisseite,
/// Rechtstexte, siehe docs/21). Die bestehende eingeloggte App (`_Root` /
/// [HomeShell]) bleibt unveraendert unter `/app` erreichbar (SUB-108).
GoRouter _buildRouter({required String initialLocation}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const PublicLandingPage()),
        GoRoute(path: '/preise', builder: (context, state) => const PublicPricingPage()),
        GoRoute(
          path: '/rechtliches/:slug',
          builder: (context, state) => PublicLegalPage(slug: state.pathParameters['slug']!),
        ),
        GoRoute(path: '/app', builder: (context, state) => const _Root()),
      ],
    );

class SubsumoApp extends StatelessWidget {
  const SubsumoApp({required this.state, this.initialLocation = '/', super.key});

  final AppState state;

  /// Nur fuer Tests: erlaubt, direkt auf einer oeffentlichen Route wie
  /// `/preise` zu starten, statt ueber Navigation dorthin zu gelangen.
  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: state,
      child: MaterialApp.router(
        title: 'Subsumo',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        routerConfig: _buildRouter(initialLocation: initialLocation),
      ),
    );
  }
}

/// Eingeloggte App (bisheriges Verhalten, unveraendert): LoginPage oder
/// HomeShell je nach Auth-Status, erreichbar unter `/app`.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!(app.isAuthenticated && app.user != null)) return const LoginPage();
    // Stripe leitet nach dem Checkout per vollem Seitenaufruf auf die App-URL
    // zurueck (?checkout=success|cancelled, siehe docs/20 F2) - `Uri.base`
    // ist deshalb hier, beim frischen Laden, die richtige Quelle statt eines
    // Router-States.
    final checkoutStatus = Uri.base.queryParameters['checkout'];
    return HomeShell(
      checkoutStatus: _handledCheckoutStatuses.contains(checkoutStatus) ? checkoutStatus : null,
    );
  }
}

/// Navigationsgeruest. Auf schmalen Geraeten unten, ab Tablet-Breite als
/// Seitenleiste mit Wortmarke - dasselbe Layout traegt Handy, Tablet,
/// Windows und Web. Den Seitentitel traegt jede Seite selbst
/// ([SubsumoPageHeader]); die AppBar bleibt schmal und zeigt auf schmalen
/// Geraeten die Wortmarke, auf breiten nur die Aktionen.
class HomeShell extends StatefulWidget {
  const HomeShell({this.checkoutStatus, super.key});

  /// `success`/`cancelled` aus der Rueckkehr-URL nach einem Stripe-Checkout
  /// (siehe [CheckoutReturnBanner]), sonst `null`.
  final String? checkoutStatus;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Fokussierter Lesemodus (SUB-160): blendet AppBar und Navigation aus,
  /// solange der Karteikarten-Tab aktiv ist. Nur hier relevant - der
  /// Umschalter dazu sitzt in [ReviewPage] selbst, damit die Chrome-
  /// Entscheidung bei der Seite bleibt, die sie auch ausblendet.
  bool _focusMode = false;

  // Funktionale Navigations-Icons bleiben in jedem Fall Icons.*_outlined,
  // auch fuer den aktiven Tab (docs/25 Abschnitt 5+8.3) - keine gefuellte
  // Variante als Aktiv-Signal. Das Label des Fall-Tabs traegt den Begriff
  // der Fachrichtung (docs/34: "Fälle" bei Jura, "Aufgaben" bei
  // Elektrotechnik), deshalb wird die Liste je Build aus dem AppState gebaut.
  static List<({IconData icon, String label})> _destinations(AppState app) => [
        (icon: Icons.today_outlined, label: 'Heute'),
        (icon: Icons.style_outlined, label: 'Karten'),
        (icon: Icons.account_tree_outlined, label: 'Schemata'),
        (icon: Icons.gavel_outlined, label: app.begriff('faelle', 'Fälle')),
        // Examen-Reiter (docs/32-examensvorbereitung.md): Profil, Examensreife,
        // Kurs-Decks, Landesrecht, Klausurrhythmus - bewusst als eigener Tab
        // statt als Unterseite des Dashboards.
        (icon: Icons.school_outlined, label: 'Examen'),
      ];

  @override
  void initState() {
    super.initState();
    // Die Startseite zeigt die Zahl der faelligen Karten - dafuer den Stapel
    // einmal beim Start laden, nicht erst beim Wechsel in den Karten-Tab.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).loadDueCards();
    });
  }

  Widget get _page => switch (_index) {
        0 => DashboardPage(onStartReview: () => setState(() => _index = 1)),
        1 => ReviewPage(
            focusMode: _focusMode,
            onToggleFocusMode: () => setState(() => _focusMode = !_focusMode),
          ),
        2 => const SchemataPage(),
        3 => const CasesPage(),
        _ => const ExamenPage(),
      };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final breit = MediaQuery.sizeOf(context).width >= 800;
    final hideChrome = _focusMode && _index == 1;

    // Kombiniert die beiden bestehenden Signale fuer einen fehlgeschlagenen
    // Server-Kontakt (siehe state.dart: dueCardsFromCache, outbox) zu einer
    // app-weiten Anzeige (SUB-161/SUB-153) - reaktiv auf einen tatsaechlichen
    // Fehlschlag statt auf eine ungeprueft optimistische Netzstatus-API, im
    // Sinne von "Ehrlichkeit vor Motivation" (docs/01-produktvision.md).
    final offline = app.dueCardsFromCache || app.outbox.isNotEmpty;
    final destinations = _destinations(app);

    return Scaffold(
      appBar: hideChrome
          ? null
          : AppBar(
              title: breit ? null : const SubsumoWordmark(),
              actions: [
                if (offline)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Spacing.xs),
                    child: Tooltip(
                      message: 'Letzter Kontakt zum Server ist fehlgeschlagen - '
                          'zeigt zuletzt gespeicherte Daten.',
                      child: SubsumoChip(label: 'offline', icon: Icons.cloud_off),
                    ),
                  ),
                if (app.outbox.isNotEmpty)
                  IconButton(
                    tooltip: '${app.outbox.length} Bewertung(en) nicht synchronisiert',
                    icon: const Icon(Icons.cloud_upload_outlined),
                    onPressed: app.flushOutbox,
                  ),
                IconButton(
                  tooltip: 'Konto',
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AccountPage()),
                  ),
                ),
                IconButton(
                  tooltip: 'Abmelden',
                  icon: const Icon(Icons.logout),
                  onPressed: app.signOut,
                ),
                const SizedBox(width: Spacing.sm),
              ],
            ),
      body: SafeArea(
        top: hideChrome,
        child: Column(
          children: [
            if (!hideChrome && widget.checkoutStatus != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, 0),
                child: CheckoutReturnBanner(status: widget.checkoutStatus!),
              ),
            Expanded(
              child: Row(
                children: [
                  if (breit && !hideChrome)
                    _Sidebar(
                      index: _index,
                      onSelect: _select,
                      email: app.user?['email'] as String?,
                      destinations: destinations,
                    ),
                  Expanded(child: _page),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: (breit || hideChrome)
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    label: d.label,
                  ),
              ],
            ),
    );
  }

  void _select(int i) => setState(() => _index = i);
}

/// Seitenleiste ab 800px: Wortmarke oben, Navigation mit Beschriftung,
/// unten das angemeldete Konto. Bewusst ein [NavigationRail] im erweiterten
/// Modus statt einer Eigenkonstruktion - Tastatur- und Screenreader-
/// Verhalten kommen so mit, das Aussehen aus dem Theme.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.index,
    required this.onSelect,
    required this.email,
    required this.destinations,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final String? email;
  final List<({IconData icon, String label})> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationRail(
      extended: true,
      labelType: NavigationRailLabelType.none,
      selectedIndex: index,
      onDestinationSelected: onSelect,
      leading: const Padding(
        padding: EdgeInsets.fromLTRB(Spacing.xl, Spacing.md, Spacing.xl, Spacing.xl),
        child: Align(alignment: Alignment.centerLeft, child: SubsumoWordmark(accent: true)),
      ),
      trailing: email == null
          ? null
          : Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SubsumoEyebrow('Angemeldet'),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        email!,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
      destinations: [
        for (final d in destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            label: Text(d.label),
            padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          ),
      ],
    );
  }
}
