import 'package:flutter/material.dart';

/// Einziges abstraktes Marken-Motiv der oeffentlichen Flaechen (Brief
/// Abschnitt 5, docs/25-ui-relaunch-brief.md): eine Subsumtions-Klammer
/// (das "wird subsumiert unter"-Zeichen aus der juristischen Fallpruefung)
/// ueber drei aufsteigenden Stufen (Obersatz -> Definition -> Subsumtion,
/// das Grundmuster jedes Gutachtens). Selbst gezeichnet statt einer
/// Bilddatei (`CustomPainter`, kein Stockfoto/Illustration, siehe Brief
/// Abschnitt 5) - rein dekorativ und deshalb bewusst dezent (niedrige
/// Deckkraft), keine Kontrastpruefung noetig, da kein Text/Informations-
/// traeger. Nur fuer das Hero-Band der Landing-/Preisseite (SUB-241) - nicht
/// in App-Screens, nicht in der "Ehrlich ueber den Umfang"-Sektion.
class SubsumoBrandMotif extends StatelessWidget {
  const SubsumoBrandMotif({this.color = Colors.white, this.opacity = 0.22, super.key});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(painter: _BrandMotifPainter(color: color)),
      ),
    );
  }
}

class _BrandMotifPainter extends CustomPainter {
  const _BrandMotifPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Drei aufsteigende Stufen (Obersatz/Definition/Subsumtion) - stumpfe
    // Rechtecke, keine Fotorealitaet.
    final stepPaint = Paint()..color = color;
    final stepHeight = h * 0.10;
    final steps = [
      Rect.fromLTWH(w * 0.10, h * 0.78, w * 0.36, stepHeight),
      Rect.fromLTWH(w * 0.10, h * 0.62, w * 0.52, stepHeight),
      Rect.fromLTWH(w * 0.10, h * 0.46, w * 0.68, stepHeight),
    ];
    for (final step in steps) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(step, Radius.circular(stepHeight * 0.25)),
        stepPaint,
      );
    }

    // Grosse, geschwungene Subsumtions-Klammer rechts der Stufen.
    final bracketPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;

    final bracket = Path()
      ..moveTo(w * 0.62, h * 0.06)
      ..cubicTo(w * 0.94, h * 0.10, w * 0.94, h * 0.34, w * 0.74, h * 0.42)
      ..cubicTo(w * 0.60, h * 0.47, w * 0.60, h * 0.53, w * 0.74, h * 0.58)
      ..cubicTo(w * 0.94, h * 0.66, w * 0.94, h * 0.90, w * 0.62, h * 0.94);
    canvas.drawPath(bracket, bracketPaint);
  }

  @override
  bool shouldRepaint(covariant _BrandMotifPainter oldDelegate) => oldDelegate.color != color;
}
