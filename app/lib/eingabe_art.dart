import 'package:flutter/foundation.dart';

/// Wurde in dieser Sitzung schon per Touch bedient? App-weit, damit auch eine
/// frisch geoeffnete Seite (z. B. ein Deck nach Tipp auf eine Themenzeile)
/// keine Tastaturhinweise zeigt (Nutzertest W11, Tablet).
final touchErkannt = ValueNotifier<bool>(false);
