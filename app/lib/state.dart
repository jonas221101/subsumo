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
/// Bewusst ein einfacher [ChangeNotifier] im M0-Geruest. Mit der
/// Offline-Synchronisierung in M1 wandert das auf Riverpod plus drift.
class AppState extends ChangeNotifier {
  AppState({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  static const _tokenKey = 'subsumo.token';

  bool loading = false;
  String? error;
  Map<String, dynamic>? user;
  Map<String, dynamic>? coverage;
  List<Map<String, dynamic>> dueCards = [];

  /// Ungesendete Reviews. Bleiben erhalten, bis der Server sie bestaetigt hat.
  final List<PendingReview> outbox = [];

  bool get isAuthenticated => api.isAuthenticated;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) return;
    api.setToken(token);
    try {
      user = await api.me();
      notifyListeners();
    } on ApiException {
      // Abgelaufenes Token: still verwerfen, der Nutzer meldet sich neu an.
      await signOut();
    }
  }

  Future<void> _persistToken(String token) async {
    api.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<bool> signIn(String email, String password, {bool register = false}) async {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  Future<bool> loadDashboard() => _guard(() async {
        coverage = await api.coverage();
      });

  Future<bool> loadDueCards() => _guard(() async {
        dueCards = await api.dueCards(limit: 30);
      });

  /// Bewertet die oberste Karte und legt das Ereignis in die Outbox.
  ///
  /// Die Karte verschwindet sofort aus dem Stapel - das Lernen darf nie auf
  /// eine Netzantwort warten.
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
      error = null;
    } on Exception {
      error = 'Offline - ${outbox.length} Bewertung(en) werden spaeter gesendet.';
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
  const AppScope({required AppState super.notifier, required super.child, super.key});

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope?.notifier != null, 'AppScope fehlt oberhalb dieses Widgets');
    return scope!.notifier!;
  }
}
