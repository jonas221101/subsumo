// F2 (docs/20-release-g2-bezahlstrecke.md Abschnitt 4): Checkout-Flow.
// Deckt CheckoutPage (Planwahl + Stripe-Redirect) und CheckoutReturnBanner
// (Rueckkehr-Zustaende) als automatisierten Widget-Test ab - kein Stripe-
// Testmodus in dieser Ausfuehrungsumgebung erreichbar.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/pages/checkout_page.dart';
import 'package:subsumo/state.dart';
import 'package:subsumo/theme.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

http.Response _json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

class _FakeUrlLauncher extends UrlLauncherPlatform {
  _FakeUrlLauncher({this.launchResult = true});

  final bool launchResult;
  String? lastLaunchedUrl;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastLaunchedUrl = url;
    return launchResult;
  }
}

Future<void> _pumpCheckoutPage(WidgetTester tester, {http.Client? client}) async {
  final state = AppState(api: ApiClient(client: client ?? MockClient((_) async => _json({}, 404))));

  await tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const CheckoutPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _FakeUrlLauncher fakeLauncher;

  setUp(() {
    fakeLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeLauncher;
  });

  group('CheckoutPage', () {
    testWidgets('zeigt beide Plaene inkl. Preisgarantie-Hinweis aus docs/19', (tester) async {
      await _pumpCheckoutPage(tester);

      expect(find.text('3,99 EUR / Monat'), findsOneWidget);
      expect(find.text('39 EUR / Jahr'), findsOneWidget);
      expect(find.textContaining('Preisgarantie'), findsOneWidget);
    });

    testWidgets('Planwahl ruft die Checkout-Session ab und oeffnet sie extern', (tester) async {
      String? requestedPlan;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/billing/checkout-session') {
          requestedPlan = (jsonDecode(request.body) as Map)['plan'] as String;
          return _json({'checkout_url': 'https://checkout.stripe.com/session/xyz'}, 200);
        }
        return _json({}, 404);
      });
      await _pumpCheckoutPage(tester, client: client);

      await tester.tap(find.text('Auswaehlen').first);
      await tester.pumpAndSettle();

      expect(requestedPlan, 'monthly');
      expect(fakeLauncher.lastLaunchedUrl, 'https://checkout.stripe.com/session/xyz');
    });

    testWidgets('ApiException beim Session-Aufbau zeigt die Server-Meldung', (tester) async {
      final client = MockClient((request) async => _json({'detail': 'stripe_unreachable'}, 502));
      await _pumpCheckoutPage(tester, client: client);

      await tester.tap(find.text('Auswaehlen').first);
      await tester.pumpAndSettle();

      expect(find.text('stripe_unreachable'), findsOneWidget);
    });

    testWidgets('kann der Browser die URL nicht oeffnen, erscheint ein Hinweis', (tester) async {
      fakeLauncher = _FakeUrlLauncher(launchResult: false);
      UrlLauncherPlatform.instance = fakeLauncher;
      final client = MockClient(
        (request) async => _json({'checkout_url': 'https://checkout.stripe.com/session/xyz'}, 200),
      );
      await _pumpCheckoutPage(tester, client: client);

      await tester.tap(find.text('Auswaehlen').first);
      await tester.pumpAndSettle();

      expect(find.text('Checkout konnte nicht geoeffnet werden.'), findsOneWidget);
    });
  });

  group('CheckoutReturnBanner', () {
    testWidgets('?checkout=success zeigt die Bestaetigung, sobald proActive gesetzt ist',
        (tester) async {
      final state = AppState(
        api: ApiClient(
          client: MockClient((request) async {
            if (request.url.path == '/v1/auth/me') {
              return _json({'email': 'pro@example.com', 'pro_active': true}, 200);
            }
            return _json({}, 404);
          }),
        ),
      );

      await tester.pumpWidget(
        AppScope(
          notifier: state,
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const Scaffold(body: CheckoutReturnBanner(status: 'success')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Zahlung bestaetigt - du bist jetzt Pro.'), findsOneWidget);
    });

    testWidgets('?checkout=cancelled zeigt eine neutrale Meldung ohne Fehlerzustand',
        (tester) async {
      final state = AppState(api: ApiClient(client: MockClient((_) async => _json({}, 404))));

      await tester.pumpWidget(
        AppScope(
          notifier: state,
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const Scaffold(body: CheckoutReturnBanner(status: 'cancelled')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Zahlung abgebrochen.'), findsOneWidget);
    });
  });
}
