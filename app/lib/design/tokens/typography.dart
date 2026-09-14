import 'package:flutter/material.dart';

/// Typoskala. Fliesstext dominiert die App (Gutachtentexte, Falltexte,
/// Schemata) - deshalb ist body* bewusst gross genug fuer lange
/// Lesestrecken, und Ueberschriften sind zurueckhaltend gestuft statt
/// dekorativ gross.
class TypeScale {
  const TypeScale._();

  static const double bodyLarge = 16;
  static const double bodyLargeHeight = 1.5;
  static const double bodyMedium = 15;
  static const double bodyMediumHeight = 1.5;
  static const double bodySmall = 13;
  static const double bodySmallHeight = 1.4;

  static const double titleLarge = 22;
  static const double titleMedium = 17;
  static const double titleSmall = 15;

  static const FontWeight titleWeight = FontWeight.w600;
}
