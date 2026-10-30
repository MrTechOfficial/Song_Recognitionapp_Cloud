import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Connected, articulated silhouettes. Wing membranes fold at the shoulder,
/// retaining their finger/scallop shape instead of rotating detached PNG parts.
void paintHalloweenBat(
    Canvas canvas, Offset center, double width, double flap, double bank) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(bank);
  canvas.scale(width / 80);
  final lift = math.sin(flap) * 17;
  final reach = 31 + math.cos(flap) * 7;
  final ink = Paint()..color = const Color(0xFF140E27);
  for (final side in [-1.0, 1.0]) {
    canvas.save();
    canvas.scale(side, 1);
    final wing = Path()
      ..moveTo(4, -2)
      ..cubicTo(12, -9 - lift * .35, 22, -12 - lift, reach, -10 - lift)
      ..quadraticBezierTo(reach - 3, -1 - lift * .35, reach - 2, 9 - lift * .35)
      ..quadraticBezierTo(28, 2 - lift * .15, 23, 12 - lift * .12)
      ..quadraticBezierTo(17, 5, 14, 13)
      ..quadraticBezierTo(10, 6, 4, 8)
      ..close();
    canvas.drawPath(wing, ink);
    canvas.drawPath(
        wing,
        Paint()
          ..color = const Color(0xFF4B335D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65);
    final fingers = Path()
      ..moveTo(5, 0)
      ..lineTo(reach - 3, -9 - lift)
      ..moveTo(5, 0)
      ..quadraticBezierTo(18, -3, 23, 11 - lift * .12);
    canvas.drawPath(
        fingers,
        Paint()
          ..color = const Color(0xFF382546)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .55);
    canvas.restore();
  }
  canvas.drawOval(const Rect.fromLTWH(-5, -7, 10, 22), ink);
  canvas.drawPath(
      Path()
        ..moveTo(-5, -5)
        ..lineTo(-5, -12)
        ..lineTo(-1, -8)
        ..lineTo(3, -9)
        ..lineTo(6, -12)
        ..lineTo(5, -3)
        ..close(),
      ink);
  canvas.restore();
}
