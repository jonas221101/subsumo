import 'dart:convert';

import 'package:http/http.dart' as http;

/// Basisadresse des Backends. Wird beim Build gesetzt:
/// `flutter run --dart-define=SUBSUMO_API=https://api.subsumo.de`
const String kApiBase = String.fromEnvironment(
  'SUBSUMO_API',
  defaultValue: 'http://localhost:8000',
);

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.upgradeRequired = false});

  final int statusCode;
  final String message;

  /// True bei 402/403-Antworten, die laut Fehlerformat der Free-Tier-Limits
  /// (`upgrade_required: true` im Body, siehe docs/20 B2) einen erreichten
  /// Free-Limit statt eines generischen Fehlers melden.
  final bool upgradeRequired;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Duenner Client um die REST-API. Kennt kein UI und keinen Zustand.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;

  bool get isAuthenticated => _token != null;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleaned = query?.map((k, v) => MapEntry(k, '$v'));
    return Uri.parse('$kApiBase$path').replace(queryParameters: cleaned);
  }

  dynamic _decode(http.Response response) {
    final body = response.body.isEmpty ? '{}' : utf8.decode(response.bodyBytes);
    if (response.statusCode >= 400) {
      String message = 'Unbekannter Fehler';
      bool upgradeRequired = false;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          // FastAPI verpackt HTTPException(detail=...) im `detail`-Feld. Ein
          // Free-Limit (siehe docs/20 B2) haengt dort ein Objekt mit
          // `upgrade_required`/`message` ein statt eines blossen Strings.
          final detail = decoded['detail'];
          if (detail is Map) {
            if (detail['upgrade_required'] == true) upgradeRequired = true;
            message = detail['message'] as String? ?? '$detail';
          } else if (detail != null) {
            message = '$detail';
          }
          if (decoded['upgrade_required'] == true) upgradeRequired = true;
        }
      } on FormatException {
        message = body;
      }
      throw ApiException(response.statusCode, message, upgradeRequired: upgradeRequired);
    }
    return jsonDecode(body);
  }

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async =>
      _decode(await _client.get(_uri(path, query), headers: _headers));

  Future<dynamic> _post(String path, Object? body) async => _decode(
        await _client.post(_uri(path),
            headers: _headers, body: jsonEncode(body)),
      );

  // --- Auth ----------------------------------------------------------------

  Future<String> register(String email, String password) async {
    final data = await _post('/v1/auth/register', {
      'email': email,
      'password': password,
    });
    return data['access_token'] as String;
  }

  Future<String> login(String email, String password) async {
    final data = await _post('/v1/auth/login', {
      'email': email,
      'password': password,
    });
    return data['access_token'] as String;
  }

  Future<Map<String, dynamic>> me() async =>
      (await _get('/v1/auth/me')) as Map<String, dynamic>;

  // --- Lernen ---------------------------------------------------------------

  Future<List<Map<String, dynamic>>> dueCards({int limit = 20}) async {
    final data = await _get('/v1/cards/due', {'limit': limit});
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Sendet die Outbox. Idempotent ueber `client_id` - ein Retry nach einem
  /// Netzabbruch veraendert den Kartenzustand kein zweites Mal.
  Future<Map<String, dynamic>> submitReviews(
    List<Map<String, dynamic>> reviews,
  ) async =>
      (await _post('/v1/reviews/batch', {'reviews': reviews}))
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> coverage() async =>
      (await _get('/v1/progress/coverage')) as Map<String, dynamic>;

  // --- Inhalte --------------------------------------------------------------

  Future<Map<String, dynamic>> contentManifest() async {
    final data = await _get('/v1/content/manifest');
    if (data is! Map) {
      throw const FormatException('Content-Manifest ist kein Objekt');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> contentCards({int limit = 2000}) async {
    final data = await _get('/v1/content/cards', {'limit': limit});
    if (data is! List || data.any((card) => card is! Map)) {
      throw const FormatException('Karten-Snapshot ist ungueltig');
    }
    return data.map((card) => Map<String, dynamic>.from(card as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> schemata({String? area}) async {
    final data = await _get('/v1/content/schemata', {
      if (area != null) 'area': area,
    });
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> cases() async =>
      ((await _get('/v1/content/cases')) as List).cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> caseDetail(String slug) async =>
      (await _get('/v1/cases/$slug')) as Map<String, dynamic>;

  // --- Gutachten ------------------------------------------------------------

  Future<Map<String, dynamic>> analyze(String text, {String? caseSlug}) async =>
      (await _post('/v1/gutachten/analyze', {
        'text': text,
        if (caseSlug != null) 'case_slug': caseSlug,
      })) as Map<String, dynamic>;

  Future<Map<String, dynamic>> submitCase(
    String slug,
    String text, {
    String mode = 'uebung',
    int durationSeconds = 0,
  }) async =>
      (await _post('/v1/cases/$slug/submit', {
        'text': text,
        'mode': mode,
        'duration_s': durationSeconds,
      })) as Map<String, dynamic>;

  // --- Bezahlstrecke ----------------------------------------------------------

  /// Erstellt eine Stripe-Checkout-Session fuer `plan` (`monthly`/`yearly`,
  /// siehe docs/20-release-g2-bezahlstrecke.md B3) und liefert die URL, zu
  /// der der Client extern weiterleiten soll. Setzt selbst kein Entitlement -
  /// das passiert erst asynchron ueber den Webhook (B4).
  Future<String> createCheckoutSession(String plan) async {
    final data = await _post('/v1/billing/checkout-session', {'plan': plan});
    return (data as Map<String, dynamic>)['checkout_url'] as String;
  }

  /// Kuendigt das laufende Abo (F3, siehe docs/20-release-g2-bezahlstrecke.md
  /// B5). Liefert `mode` im Ergebnis: `"period_end"` (Zugriff bleibt bis zum
  /// Periodenende) oder `"immediate_refund"` (Widerrufsfall, sofortige
  /// Kuendigung mit voller Rueckerstattung). Wirft `ApiException(409, ...)`,
  /// wenn kein aktives Abo hinterlegt ist.
  Future<Map<String, dynamic>> cancelSubscription() async =>
      (await _post('/v1/billing/cancel', const {})) as Map<String, dynamic>;
}
