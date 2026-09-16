import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Ein noch nicht synchronisiertes Lernereignis.
///
/// Jedes Review bekommt vom Client eine eigene ID. Der Server verwirft
/// Duplikate anhand dieser ID - der Client muss also nie wissen, was schon
/// angekommen ist, und darf nach jedem Netzfehler bedenkenlos erneut senden.
class PendingReview {
  PendingReview({
    required this.clientId,
    required this.cardSlug,
    required this.rating,
    required this.reviewedAt,
    this.elapsedMs = 0,
  });

  factory PendingReview.fromJson(Map<String, dynamic> json) => PendingReview(
        clientId: json['client_id'] as String,
        cardSlug: json['card_slug'] as String,
        rating: json['rating'] as int,
        reviewedAt: DateTime.parse(json['reviewed_at'] as String),
        elapsedMs: json['elapsed_ms'] as int? ?? 0,
      );

  final String clientId;
  final String cardSlug;
  final int rating;
  final DateTime reviewedAt;
  final int elapsedMs;

  Map<String, dynamic> toJson() => {
        'client_id': clientId,
        'card_slug': cardSlug,
        'rating': rating,
        'reviewed_at': reviewedAt.toUtc().toIso8601String(),
        'elapsed_ms': elapsedMs,
      };
}

String _newClientId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Zentraler App-Zustand.
///
/// Bewusst ein einfacher [ChangeNotifier] im M0-Geruest, mit einer duennen
/// Offline-Schicht ueber [SharedPreferences]: die zuletzt geladenen faelligen
/// Karten und die Review-Outbox ueberleben Neustart und Netzausfall. Das ist
/// bewusst kein vollwertiger Offline-Speicher (kein Volltext-Cache aller
/// Karten, keine Konfliktaufloesung jenseits der ohnehin idempotenten
/// Server-API) - fuer den vollstaendigen lokalen Datenbestand ist drift
/// vorgesehen, sobald Schemata und Faelle ebenfalls offline gebraucht werden
/// (siehe docs/03-roadmap.md, M2).
class AppState extends ChangeNotifier {
  AppState({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  static const _tokenKey = 'subsumo.token';
  static const _outboxKey = 'subsumo.outbox';
  static const _dueCardsCacheKey = 'subsumo.due_cards_cache';
  static const _contentStateKey = 'subsumo.content_state';

  bool loading = false;
  String? error;
  Map<String, dynamic>? user;
  Map<String, dynamic>? coverage;
  List<Map<String, dynamic>> dueCards = [];

  /// Letzter vollstaendig bestaetigter Karten-Snapshot. Manifest und Snapshot
  /// werden gemeinsam gespeichert, damit ein Schreibfehler nie einen neuen
  /// Stand ohne seine Karten sichtbar macht.
  Map<String, dynamic>? contentManifest;
  List<Map<String, dynamic>> contentCards = [];

  /// True, solange [dueCards] aus dem lokalen Zwischenspeicher stammt statt
  /// vom Server bestaetigt zu sein - z. B. weil der letzte Ladeversuch offline
  /// war. Die UI kann das anzeigen, ohne dass die Karten deshalb verschwinden.
  bool dueCardsFromCache = false;

  /// Ungesendete Reviews. Bleiben erhalten, bis der Server sie bestaetigt hat -
  /// auch ueber einen App-Neustart hinweg (siehe [_persistOutbox]).
  final List<PendingReview> outbox = [];

  bool get isAuthenticated => api.isAuthenticated;

  // --- Pro-Gating ------------------------------------------------------------
  //
  // Bildet direkt die Felder aus `/auth/me` ab (siehe docs/20 B1). Ist die
  // Paywall serverseitig aus, liefert das Backend `pro_active=true` fuer
  // alle Nutzer - dafuer braucht es hier keine Sonderlogik.

  bool get proActive => (user?['pro_active'] as bool?) ?? false;

  DateTime? get proUntil {
    final raw = user?['pro_until'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  bool get cancelAtPeriodEnd => (user?['cancel_at_period_end'] as bool?) ?? false;

  /// Nach der Rueckkehr von einem erfolgreichen Stripe-Checkout aufzurufen
  /// (F2, siehe docs/20-release-g2-bezahlstrecke.md): der Webhook (B4)
  /// schaltet das Entitlement asynchron zur Redirect-Rueckkehr frei, deshalb
  /// wird `/auth/me` mit kurzen Pausen wiederholt abgefragt statt nur einmal.
  ///
  /// Liefert `true`, sobald [proActive] danach `true` ist - sonst `false`
  /// nach dem letzten Versuch, ohne das als Fehler zu behandeln (der Webhook
  /// kann laenger brauchen als dieses kurze Fenster).
  Future<bool> confirmProAfterCheckout({
    int attempts = 5,
    Duration interval = const Duration(seconds: 2),
  }) async {
    for (var i = 0; i < attempts; i++) {
      try {
        user = await api.me();
        notifyListeners();
        if (proActive) return true;
      } on Exception {
        // Naechster Versuch behandelt einen einzelnen Netzausfall - erst nach
        // dem letzten Versuch gilt die Bestaetigung als (noch) nicht da.
      }
      if (i < attempts - 1) await Future<void>.delayed(interval);
    }
    return proActive;
  }

  /// Frischt [user] einmalig vom Server neu - z. B. nach einer Kontoaktion
  /// wie einer Kuendigung (F3), deren Wirkung auf [cancelAtPeriodEnd]/[proActive]
  /// teils erst asynchron ueber den Stripe-Webhook (B4) nachgezogen wird. Ein
  /// Fehlschlag hier verwirft bewusst nicht den zuletzt bekannten Zustand -
  /// der Aufrufer meldet den eigentlichen Vorgang (z. B. die Kuendigung)
  /// ohnehin separat.
  Future<void> refreshUser() async {
    try {
      user = await api.me();
      notifyListeners();
    } on Exception {
      // Letzten bekannten Zustand behalten statt ihn bei einem Netzfehler zu verwerfen.
    }
  }

  /// Einmal beim Start aufzurufen: stellt Login, Outbox und den zuletzt
  /// bekannten Kartenstapel wieder her - in dieser Reihenfolge, damit ein
  /// Offline-Start sofort etwas Sinnvolles zeigt, statt auf das Netz zu warten.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    await _restoreOutbox(prefs);
    _restoreCachedDueCards(prefs);
    _restoreContentState(prefs);

    final token = prefs.getString(_tokenKey);
    if (token == null) return;
    api.setToken(token);
    try {
      user = await api.me();
      notifyListeners();
      unawaited(syncContent());
      // Angemeldet und (jetzt erwiesenermassen) online - liegen gebliebene
      // Bewertungen aus einer frueheren Offline-Phase gleich nachreichen.
      unawaited(flushOutbox());
    } on ApiException {
      // Abgelaufenes Token: still verwerfen, der Nutzer meldet sich neu an.
      await signOut();
    } on Exception {
      // Kein Netz beim Start: Token bleibt gueltig, der zwischengespeicherte
      // Zustand (Outbox, Karten) ist trotzdem sofort nutzbar.
    }
  }

  Future<void> _restoreOutbox(SharedPreferences prefs) async {
    final raw = prefs.getString(_outboxKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List;
      outbox
        ..clear()
        ..addAll(
          decoded.map((e) => PendingReview.fromJson(e as Map<String, dynamic>)),
        );
    } on FormatException {
      // Beschaedigter Eintrag - lieber leer starten als beim Start abstuerzen.
      await prefs.remove(_outboxKey);
    }
  }

  Future<void> _persistOutbox() async {
    final prefs = await SharedPreferences.getInstance();
    if (outbox.isEmpty) {
      await prefs.remove(_outboxKey);
      return;
    }
    await prefs.setString(
      _outboxKey,
      jsonEncode(outbox.map((r) => r.toJson()).toList()),
    );
  }

  void _restoreCachedDueCards(SharedPreferences prefs) {
    final raw = prefs.getString(_dueCardsCacheKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List;
      dueCards = decoded.cast<Map<String, dynamic>>();
      dueCardsFromCache = true;
    } on FormatException {
      // Beschaedigter Cache-Eintrag ignorieren - der naechste Online-Ladevorgang
      // ueberschreibt ihn ohnehin.
    }
  }

  Future<void> _persistDueCardsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dueCardsCacheKey, jsonEncode(dueCards));
  }

  void _restoreContentState(SharedPreferences prefs) {
    final raw = prefs.getString(_contentStateKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          decoded['manifest'] is! Map ||
          decoded['cards'] is! List) {
        return;
      }
      final cards = (decoded['cards'] as List);
      if (cards.any((card) => card is! Map)) return;
      contentManifest = Map<String, dynamic>.from(decoded['manifest'] as Map);
      contentCards =
          cards.map((card) => Map<String, dynamic>.from(card as Map)).toList();
    } on FormatException {
      // Ein unvollstaendiger oder alter Eintrag wird als fehlender Snapshot
      // behandelt; die anderen Offline-Daten bleiben dabei unberuehrt.
    }
  }

  /// Synchronisiert Karten nur bei einer neuen Manifest-Version.
  ///
  /// Der neue Stand wird zuerst komplett dekodiert und als ein einzelner
  /// Preferences-Wert geschrieben. Erst danach wird der Speicherzustand
  /// ausgetauscht. Dadurch bleiben bei Netz-, Decode- oder Speicherfehlern
  /// der alte Snapshot, die faelligen Karten und die Review-Outbox erhalten.
  Future<bool> syncContent() async {
    try {
      final manifest = await api.contentManifest();
      final version = manifest['content_version'];
      if (version is! String || version.isEmpty) {
        throw const FormatException('Content-Version fehlt');
      }
      if (contentManifest?['content_version'] == version) return true;

      final cards = await api.contentCards(limit: 2000);
      final encoded = jsonEncode({'manifest': manifest, 'cards': cards});
      final prefs = await SharedPreferences.getInstance();
      final written = await prefs.setString(_contentStateKey, encoded);
      if (!written) {
        throw StateError('Karten-Snapshot konnte nicht gespeichert werden');
      }

      contentManifest = manifest;
      contentCards = cards;
      notifyListeners();
      return true;
    } on Exception {
      return false;
    }
  }

  Future<void> _persistToken(String token) async {
    api.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<bool> signIn(
    String email,
    String password, {
    bool register = false,
  }) async {
    return _guard(() async {
      final token = register
          ? await api.register(email, password)
          : await api.login(email, password);
      await _persistToken(token);
      user = await api.me();
    });
  }

  Future<void> signOut() async {
    api.setToken(null);
    user = null;
    coverage = null;
    dueCards = [];
    dueCardsFromCache = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    // Outbox und Kartencache bleiben bewusst bestehen: Ab- und wieder
    // Anmelden (z. B. nach einem abgelaufenen Token) darf keine noch nicht
    // gesendeten Bewertungen verlieren.
    notifyListeners();
  }

  Future<bool> loadDashboard() => _guard(() async {
        coverage = await api.coverage();
      });

  /// Laedt faellige Karten. Schlaegt der Netzaufruf fehl, bleibt der zuletzt
  /// zwischengespeicherte Stapel sichtbar (siehe [dueCardsFromCache]) statt
  /// eines leeren Bildschirms - Offline-Lernen ist der Regelfall, nicht die
  /// Ausnahme (siehe docs/01-produktvision.md, "Offline ist Pflicht").
  Future<bool> loadDueCards() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      dueCards = await api.dueCards(limit: 30);
      dueCardsFromCache = false;
      await _persistDueCardsCache();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } on Exception {
      if (dueCards.isNotEmpty) {
        dueCardsFromCache = true;
        error = 'Offline - zeige die zuletzt geladenen Karten.';
      } else {
        error = 'Server nicht erreichbar. Laeuft das Backend auf $kApiBase?';
      }
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Bewertet die oberste Karte und legt das Ereignis in die Outbox.
  ///
  /// Die Karte verschwindet sofort aus dem Stapel - das Lernen darf nie auf
  /// eine Netzantwort warten. Outbox und Kartenstapel werden vor dem
  /// Sende-Versuch persistiert, nicht erst danach: stuerzt die App zwischen
  /// Bewertung und Bestaetigung ab, ist die Bewertung trotzdem nicht verloren.
  Future<void> rateTopCard(int rating, {int elapsedMs = 0}) async {
    if (dueCards.isEmpty) return;
    final card = dueCards.removeAt(0);
    outbox.add(
      PendingReview(
        clientId: _newClientId(),
        cardSlug: card['slug'] as String,
        rating: rating,
        reviewedAt: DateTime.now(),
        elapsedMs: elapsedMs,
      ),
    );
    notifyListeners();
    await Future.wait([_persistOutbox(), _persistDueCardsCache()]);
    await flushOutbox();
  }

  /// Schickt die Outbox zum Server. Schlaegt das fehl, bleibt alles liegen und
  /// wird beim naechsten Versuch erneut gesendet.
  Future<void> flushOutbox() async {
    if (outbox.isEmpty) return;
    final batch = List<PendingReview>.from(outbox);
    try {
      await api.submitReviews(batch.map((r) => r.toJson()).toList());
      outbox.removeWhere((r) => batch.any((b) => b.clientId == r.clientId));
      await _persistOutbox();
      error = null;
    } on Exception {
      error =
          'Offline - ${outbox.length} Bewertung(en) werden spaeter gesendet.';
    }
    notifyListeners();
  }

  Future<bool> _guard(Future<void> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } on Exception {
      error = 'Server nicht erreichbar. Laeuft das Backend auf $kApiBase?';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

/// Stellt den [AppState] im Widget-Baum bereit.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    required AppState super.notifier,
    required super.child,
    super.key,
  });

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope?.notifier != null, 'AppScope fehlt oberhalb dieses Widgets');
    return scope!.notifier!;
  }
}
