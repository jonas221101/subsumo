import 'package:flutter/animation.dart';

/// Bewegungs-Skala fuer Kartenwechsel und State-Uebergaenge. Bewusst
/// sparsam gehalten - eine Dauer- statt Effekt-Verbesserung fuer ein
/// "gemachtes" statt statisches Gefuehl, ausdruecklich ohne Bounce-
/// Overshoots oder sonstige Gamification-Effekte (siehe SUB-153/SUB-158).
class Motion {
  const Motion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Curve curve = Curves.easeInOut;
}
