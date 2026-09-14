/// Erhebungsstufen. Bewusst niedrig gehalten - starke Schatten wirken auf
/// textlastigen Seiten unruhig. level0 fuer flaechenbuendige Elemente
/// (Chips, eingebettete Listenzeilen), level1 fuer Karten im Ruhezustand,
/// level2 fuer temporaer im Vordergrund stehende Flaechen (z. B. Dialoge).
class Elevation {
  const Elevation._();

  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 4;
}
