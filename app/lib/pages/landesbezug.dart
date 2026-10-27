/// Landesbezug von Faellen und Schemata (API-Feld `bundesland`, Kuerzel).
const bundeslandNamen = <String, String>{
  'BW': 'Baden-Württemberg',
  'BY': 'Bayern',
  'BE': 'Berlin',
  'BB': 'Brandenburg',
  'HB': 'Bremen',
  'HH': 'Hamburg',
  'HE': 'Hessen',
  'MV': 'Mecklenburg-Vorpommern',
  'NI': 'Niedersachsen',
  'NW': 'Nordrhein-Westfalen',
  'RP': 'Rheinland-Pfalz',
  'SL': 'Saarland',
  'SN': 'Sachsen',
  'ST': 'Sachsen-Anhalt',
  'SH': 'Schleswig-Holstein',
  'TH': 'Thüringen',
};

/// Chip-Beschriftung zum Landeskuerzel, `null` ohne Landesbezug.
String? landesLabel(Object? code) {
  if (code is! String || code.trim().isEmpty) return null;
  final name = bundeslandNamen[code.trim().toUpperCase()];
  return name ?? 'Landesrecht $code';
}

final _wortTrenner = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

List<String> _woerter(String text) => [
      for (final w in text.toLowerCase().split(_wortTrenner))
        if (w.isNotEmpty) w,
    ];

/// Wortbasierte Suche: jedes Suchwort muss ein Wort im Text exakt treffen
/// (Rang 0) oder als Wortanfang (Rang 1). Teilstrings mitten im Wort zaehlen
/// nicht ("BW" findet nicht "Gebwald"). `null` = kein Treffer; sonst der
/// schlechteste Rang ueber alle Suchwoerter (kleiner = besser).
int? suchRang(String query, String haystack) {
  final tokens = _woerter(query);
  if (tokens.isEmpty) return 0;
  final words = _woerter(haystack);
  var rang = 0;
  for (final t in tokens) {
    var best = 2;
    for (final w in words) {
      if (w == t) {
        best = 0;
        break;
      }
      if (best > 1 && w.startsWith(t)) best = 1;
    }
    if (best == 2) return null;
    if (best > rang) rang = best;
  }
  return rang;
}

/// Gebraeuchliche Kuerzel je internem Landescode (zusaetzlich zum Code selbst).
const bundeslandAliasse = <String, List<String>>{
  'BE': ['Bln'],
  'NW': ['NRW'],
  'RP': ['RLP'],
  'ST': ['LSA'],
};

/// Zusaetzliche Suchbegriffe fuer Landesrecht-Inhalte.
String landesSuchtext(Object? code) {
  final label = landesLabel(code);
  if (label == null) return '';
  final aliasse = bundeslandAliasse[code.toString().trim().toUpperCase()] ?? const [];
  return '$code ${aliasse.join(' ')} $label Landesrecht';
}
