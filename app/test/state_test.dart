// Tests der Offline-Schicht in [AppState]: Outbox und Kartencache muessen
// einen Prozess-Neustart und einen Netzausfall ueberstehen, ohne dass
// Bewertungen verloren gehen oder die Karten-Ansicht leer wird.
//
// Kein echtes Netz: [http.MockClient] simuliert das Backend, so dass Tests
// deterministisch und ohne laufenden Server durchlaufen.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsumo/api.dart';
import 'package:subsumo/state.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

const _dueCard = {
  'slug': 'zr-at-angebot',
  'topic_slug': 'zr-bgb-at',
  'type': 'definition',
  'front': 'Definiere: Angebot',
  'back': 'Ein Angebot ist ...',
  'norms': ['§ 145 BGB'],
  'sources': [],
  'stand': '2026-09',
  'due': null,
  'state': 'new',
  'reps': 0,
  'content_changed': false,
};

const _snapshotCard = {
  'slug': 'zr-at-angebot',
  'topic_slug': 'zr-bgb-at',
  'type': 'definition',
  'front': 'Definiere: Angebot',
  'back': 'Ein Angebot ist ...',
  'norms': ['§ 145 BGB'],
  'sources': [],
  'stand': '2026-09',
  'content_hash': 'abc',
};

Map<String, dynamic> _manifest(String version) => {
      'content_version': version,
      'topics': 1,
      'cards': 1,
      'schemata': 0,
      'cases': 0,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AppState buildState(Future<http.Response> Function(http.Request) handler) {
    final client = MockClient((request) async => handler(request));
    final api = ApiClient(client: client)..setToken('test-token');
    return AppState(api: api);
  }

  group('Pro-Gating (F1)', () {
    test('bildet pro_active/pro_until/cancel_at_period_end aus /auth/me ab', () async {
      SharedPreferences.setMockInitialValues({'subsumo.token': 'test-token'});
      final app = buildState((request) async {
        if (request.url.path == '/v1/auth/me') {
          return _json({
            'id': 1,
            'email': 'a@b.de',
            'display_name': 'A',
            'daily_minutes': 90,
            'pro_active': true,
            'pro_until': '2026-10-15T00:00:00Z',
            'cancel_at_period_end': true,
          });
        }
        return _json({}, status: 404);
      });

      await app.restoreSession();

      expect(app.proActive, isTrue);
      expect(app.proUntil, DateTime.utc(2026, 10, 15));
      expect(app.cancelAtPeriodEnd, isTrue);
    });

    test('ohne eingeloggten Nutzer sind alle Pro-Felder auf dem Free-Default', () async {
      final app = buildState((request) async => _json({}, status: 404));

      expect(app.proActive, isFalse);
      expect(app.proUntil, isNull);
      expect(app.cancelAtPeriodEnd, isFalse);
    });

    test(
      'paywall_enabled=false liefert proActive=true fuer alle - keine Sonderlogik noetig',
      () async {
        SharedPreferences.setMockInitialValues({'subsumo.token': 'test-token'});
        final app = buildState((request) async {
          if (request.url.path == '/v1/auth/me') {
            return _json({
              'id': 1,
              'email': 'a@b.de',
              'display_name': 'A',
              'daily_minutes': 90,
              'pro_active': true,
              'pro_until': null,
              'cancel_at_period_end': false,
            });
          }
          return _json({}, status: 404);
        });

        await app.restoreSession();

        expect(app.proActive, isTrue);
        expect(app.cancelAtPeriodEnd, isFalse);
      },
    );
  });

  group('Checkout-Rueckkehr (F2, docs/20-release-g2-bezahlstrecke.md Abschnitt 4)', () {
    test('proActive bereits beim ersten Versuch beendet das Polling sofort', () async {
      var meCalls = 0;
      final app = buildState((request) async {
        if (request.url.path == '/v1/auth/me') {
          meCalls++;
          return _json({
            'id': 1,
            'email': 'a@b.de',
            'display_name': 'A',
            'daily_minutes': 90,
            'pro_active': true,
          });
        }
        return _json({}, status: 404);
      });

      final confirmed = await app.confirmProAfterCheckout(interval: Duration.zero);

      expect(confirmed, isTrue);
      expect(meCalls, 1, reason: 'Webhook war schon durch - kein weiterer Versuch noetig');
    });

    test('bleibt proActive nach allen Versuchen false, gilt die Bestaetigung als verzoegert', () async {
      var meCalls = 0;
      final app = buildState((request) async {
        if (request.url.path == '/v1/auth/me') {
          meCalls++;
          return _json({
            'id': 1,
            'email': 'a@b.de',
            'display_name': 'A',
            'daily_minutes': 90,
            'pro_active': false,
          });
        }
        return _json({}, status: 404);
      });

      final confirmed = await app.confirmProAfterCheckout(attempts: 3, interval: Duration.zero);

      expect(confirmed, isFalse);
      expect(meCalls, 3, reason: 'Muss alle Versuche ausschoepfen, bevor es aufgibt');
    });

    test('ein einzelner Netzausfall unterbricht das Polling nicht', () async {
      var meCalls = 0;
      final app = buildState((request) async {
        if (request.url.path == '/v1/auth/me') {
          meCalls++;
          if (meCalls == 1) throw Exception('Netzwerk nicht erreichbar');
          return _json({
            'id': 1,
            'email': 'a@b.de',
            'display_name': 'A',
            'daily_minutes': 90,
            'pro_active': true,
          });
        }
        return _json({}, status: 404);
      });

      final confirmed = await app.confirmProAfterCheckout(attempts: 3, interval: Duration.zero);

      expect(confirmed, isTrue);
      expect(meCalls, 2);
    });
  });

  group('Kartencache', () {
    test('erfolgreiches Laden speichert die Karten lokal', () async {
      final app = buildState((request) async {
        if (request.url.path == '/v1/cards/due') {
          return _json([_dueCard]);
        }
        return _json({}, status: 404);
      });

      final ok = await app.loadDueCards();

      expect(ok, isTrue);
      expect(app.dueCards, hasLength(1));
      expect(app.dueCardsFromCache, isFalse);

      final prefs = await SharedPreferences.getInstance();
      final cached =
          jsonDecode(prefs.getString('subsumo.due_cards_cache')!) as List;
      expect(cached, hasLength(1));
      expect(cached.first['slug'], 'zr-at-angebot');
    });

    test(
      'Netzfehler faellt auf den zuletzt geladenen Stapel zurueck',
      () async {
        var callCount = 0;
        final app = buildState((request) async {
          callCount++;
          if (callCount == 1) return _json([_dueCard]);
          throw Exception('Netzwerk nicht erreichbar');
        });

        await app.loadDueCards(); // erster Aufruf: online, fuellt den Cache
        final ok =
            await app.loadDueCards(); // zweiter Aufruf: simuliert offline

        expect(ok, isFalse);
        expect(
          app.dueCards,
          hasLength(1),
          reason: 'Alte Karten duerfen nicht verschwinden',
        );
        expect(app.dueCardsFromCache, isTrue);
        expect(app.error, contains('Offline'));
      },
    );

    test(
      'Cache wird beim Start wiederhergestellt, bevor das Netz antwortet',
      () async {
        SharedPreferences.setMockInitialValues({
          'subsumo.due_cards_cache': jsonEncode([_dueCard]),
        });
        final app = buildState((request) async => _json({}, status: 404));

        await app.restoreSession();

        expect(app.dueCards, hasLength(1));
        expect(app.dueCardsFromCache, isTrue);
      },
    );

    test(
      'ohne Cache und ohne Netz bleibt die Fehlermeldung eindeutig',
      () async {
        final app = buildState((request) async {
          throw Exception('Netzwerk nicht erreichbar');
        });

        final ok = await app.loadDueCards();

        expect(ok, isFalse);
        expect(app.dueCards, isEmpty);
        expect(app.error, contains('Server nicht erreichbar'));
      },
    );
  });

  group('Karten-Snapshot-Sync', () {
    test(
      'Erstsynchronisierung persistiert Manifest und kompletten Snapshot',
      () async {
        final app = buildState((request) async {
          if (request.url.path == '/v1/content/manifest') {
            return _json(_manifest('v1'));
          }
          if (request.url.path == '/v1/content/cards') {
            expect(request.url.queryParameters['limit'], '2000');
            return _json([_snapshotCard]);
          }
          return _json({}, status: 404);
        });

        expect(await app.syncContent(), isTrue);
        expect(app.contentManifest!['content_version'], 'v1');
        expect(app.contentCards.single['slug'], 'zr-at-angebot');

        final prefs = await SharedPreferences.getInstance();
        final stored =
            jsonDecode(prefs.getString('subsumo.content_state')!) as Map;
        expect(stored['manifest']['content_version'], 'v1');
        expect(stored['cards'], hasLength(1));
      },
    );

    test('gleiche Version laedt keinen Snapshot erneut', () async {
      var cardRequests = 0;
      final app = buildState((request) async {
        if (request.url.path == '/v1/content/manifest') {
          return _json(_manifest('v1'));
        }
        if (request.url.path == '/v1/content/cards') {
          cardRequests++;
          return _json([_snapshotCard]);
        }
        return _json({}, status: 404);
      });

      await app.syncContent();
      await app.syncContent();
      expect(cardRequests, 1);
    });

    test('neue Version ersetzt den bestaetigten Snapshot', () async {
      var version = 'v1';
      final app = buildState((request) async {
        if (request.url.path == '/v1/content/manifest') {
          return _json(_manifest(version));
        }
        if (request.url.path == '/v1/content/cards') {
          return _json([
            Map<String, dynamic>.from(_snapshotCard)..['back'] = version,
          ]);
        }
        return _json({}, status: 404);
      });

      await app.syncContent();
      version = 'v2';
      await app.syncContent();
      expect(app.contentManifest!['content_version'], 'v2');
      expect(app.contentCards.single['back'], 'v2');
    });

    test(
      'Fehler laesst bestaetigten Snapshot, Karten und Outbox unveraendert',
      () async {
        final pending = PendingReview(
          clientId: 'atomic-review',
          cardSlug: 'zr-at-angebot',
          rating: 3,
          reviewedAt: DateTime.utc(2026),
        );
        final oldState = {
          'manifest': _manifest('v1'),
          'cards': [_snapshotCard],
        };
        SharedPreferences.setMockInitialValues({
          'subsumo.content_state': jsonEncode(oldState),
          'subsumo.due_cards_cache': jsonEncode([_dueCard]),
          'subsumo.outbox': jsonEncode([pending.toJson()]),
        });
        final app = buildState((request) async {
          if (request.url.path == '/v1/content/manifest') {
            return _json(_manifest('v2'));
          }
          if (request.url.path == '/v1/content/cards') {
            return _json({'not': 'a list'});
          }
          return _json({}, status: 404);
        });
        await app.restoreSession();

        expect(await app.syncContent(), isFalse);
        expect(app.contentManifest!['content_version'], 'v1');
        expect(app.contentCards, [_snapshotCard]);
        expect(app.dueCards, [_dueCard]);
        expect(app.outbox.single.clientId, 'atomic-review');
      },
    );

    test('Offline-Neustart stellt Snapshot wieder her', () async {
      SharedPreferences.setMockInitialValues({
        'subsumo.content_state': jsonEncode({
          'manifest': _manifest('v1'),
          'cards': [_snapshotCard],
        }),
      });
      final app = buildState((request) async => throw Exception('offline'));

      await app.restoreSession();

      expect(app.contentManifest!['content_version'], 'v1');
      expect(app.contentCards, [_snapshotCard]);
    });
  });

  group('Review-Outbox', () {
    test(
      'Bewertung wird sofort persistiert, bevor der Server antwortet',
      () async {
        final completer = <void>[];
        final app = buildState((request) async {
          if (request.url.path == '/v1/reviews/batch') {
            // Der lokale Speicherzugriff in rateTopCard() laeuft VOR diesem
            // Request ab - zum Zeitpunkt des Sendeversuchs muss die Bewertung
            // also schon auf der Platte liegen.
            final prefs = await SharedPreferences.getInstance();
            final stored = prefs.getString('subsumo.outbox');
            expect(stored, isNotNull);
            expect(jsonDecode(stored!), hasLength(1));
            completer.add(null);
            return _json({
              'applied': 1,
              'duplicates': 0,
              'unknown_cards': [],
              'results': [],
            });
          }
          return _json({}, status: 404);
        });
        app.dueCards = [Map<String, dynamic>.from(_dueCard)];

        await app.rateTopCard(3, elapsedMs: 1200);

        expect(completer, isNotEmpty, reason: 'Server wurde nie aufgerufen');
      },
    );

    test(
      'erfolgreich gesendete Bewertung verschwindet aus der Outbox',
      () async {
        final app = buildState((request) async {
          if (request.url.path == '/v1/reviews/batch') {
            return _json({
              'applied': 1,
              'duplicates': 0,
              'unknown_cards': [],
              'results': [],
            });
          }
          return _json({}, status: 404);
        });
        app.dueCards = [Map<String, dynamic>.from(_dueCard)];

        await app.rateTopCard(3);

        expect(app.outbox, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('subsumo.outbox'), isNull);
      },
    );

    test(
      'fehlgeschlagener Versand laesst die Bewertung in der Outbox',
      () async {
        final app = buildState((request) async {
          throw Exception('Netzwerk nicht erreichbar');
        });
        app.dueCards = [Map<String, dynamic>.from(_dueCard)];

        await app.rateTopCard(3);

        expect(app.outbox, hasLength(1));
        expect(app.error, contains('Offline'));
        final prefs = await SharedPreferences.getInstance();
        expect(jsonDecode(prefs.getString('subsumo.outbox')!), hasLength(1));
      },
    );

    test(
        'Outbox wird beim Start wiederhergestellt und automatisch gesendet '
        'sobald online', () async {
      final pending = PendingReview(
        clientId: 'abc123',
        cardSlug: 'zr-at-angebot',
        rating: 4,
        reviewedAt: DateTime.utc(2026, 1, 1),
      );
      SharedPreferences.setMockInitialValues({
        'subsumo.token': 'test-token',
        'subsumo.outbox': jsonEncode([pending.toJson()]),
      });

      var flushed = false;
      final app = buildState((request) async {
        if (request.url.path == '/v1/auth/me') {
          return _json({
            'id': 1,
            'email': 'a@b.de',
            'display_name': 'A',
            'daily_minutes': 90,
          });
        }
        if (request.url.path == '/v1/reviews/batch') {
          flushed = true;
          return _json({
            'applied': 1,
            'duplicates': 0,
            'unknown_cards': [],
            'results': [],
          });
        }
        return _json({}, status: 404);
      });

      await app.restoreSession();
      // flushOutbox() laeuft nach dem Start bewusst unawaited - kurz nachfassen,
      // statt sich auf einen genauen Zeitpunkt vor dem Flush zu verlassen.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        flushed,
        isTrue,
        reason: 'Die wiederhergestellte Bewertung wurde nie gesendet',
      );
      expect(
        app.outbox,
        isEmpty,
        reason: 'Nach erfolgreichem Versand nicht mehr in der Outbox',
      );
    });

    test(
        'Outbox wird beim Start wiederhergestellt, auch wenn der '
        'anschliessende Flush offline scheitert', () async {
      final pending = PendingReview(
        clientId: 'abc123',
        cardSlug: 'zr-at-angebot',
        rating: 4,
        reviewedAt: DateTime.utc(2026, 1, 1),
      );
      SharedPreferences.setMockInitialValues({
        'subsumo.token': 'test-token',
        'subsumo.outbox': jsonEncode([pending.toJson()]),
      });

      final app = buildState((request) async {
        if (request.url.path == '/v1/auth/me') {
          return _json({
            'id': 1,
            'email': 'a@b.de',
            'display_name': 'A',
            'daily_minutes': 90,
          });
        }
        // /v1/reviews/batch schlaegt fehl - simuliert Netzausfall genau beim
        // automatischen Nachreich-Versuch.
        throw Exception('Netzwerk nicht erreichbar');
      });

      await app.restoreSession();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        app.outbox,
        hasLength(1),
        reason: 'muss aus SharedPreferences wiederhergestellt sein',
      );
      expect(app.outbox.single.clientId, 'abc123');
    });

    test('Outbox uebersteht signOut und signIn', () async {
      final app = buildState((request) async {
        throw Exception('kein Netz fuer den Sendeversuch');
      });
      app.dueCards = [Map<String, dynamic>.from(_dueCard)];
      await app.rateTopCard(2);
      expect(app.outbox, hasLength(1));

      await app.signOut();

      expect(
        app.outbox,
        hasLength(1),
        reason: 'Abmelden darf keine Bewertungen loeschen',
      );
    });

    test(
      'beschaedigter Outbox-Eintrag laesst die App trotzdem starten',
      () async {
        SharedPreferences.setMockInitialValues({'subsumo.outbox': 'kein-json'});
        final app = buildState((request) async => _json({}, status: 404));

        await app.restoreSession();

        expect(app.outbox, isEmpty);
      },
    );
  });
}
