import 'dart:math' as math;
import 'package:flutter/material.dart';

@immutable
class ChristmasRoofSnowState {
  const ChristmasRoofSnowState(
      {required this.position,
      required this.rotation,
      required this.opacity,
      required this.scatter});
  final Offset position;
  final double rotation, opacity, scatter;
  bool get visible => opacity > 0;
  bool get landed => scatter > 0;
}

/// All weather uses scene time. Pausing the scene pauses every effect, and no
/// weather event can change the skating route or depend on scroll position.
class ChristmasWeather {
  static const lightPositions = [
    Offset(.17, .102),
    Offset(.306, .087),
    Offset(.426, .07),
    Offset(.535, .038),
    Offset(.635, .071),
    Offset(.763, .09),
    Offset(.954, .08),
  ];
  // Individually staggered, with the first twinkle visible within two seconds.
  static const _twinkles = [7.6, 35.5, 20.4, 1.0, 42.0, 13.0, 28.0];
  static double lightIntensity(double seconds, int index) {
    final age = ((seconds - _twinkles[index]) % 48 + 48) % 48;
    if (age >= 2.8) return 0;
    final pulse = math.sin(age / 2.8 * math.pi);
    return pulse * pulse;
  }

  static double wind(double seconds) =>
      math.sin(seconds * math.pi * 2 / 96) * 18 +
      math.sin(seconds * math.pi * 2 / 24) * 6;

  static ChristmasRoofSnowState roofSnowAt(double seconds) {
    final age = ((seconds - 10) % 64 + 64) % 64;
    const roof = Offset(788, 607),
        eave = Offset(734, 655),
        bank = Offset(722, 724);
    if (age >= 3.6) {
      return const ChristmasRoofSnowState(
          position: roof, rotation: -.72, opacity: 0, scatter: 0);
    }
    if (age < 1.3) {
      final slide = math.pow(age / 1.3, 1.7).toDouble();
      return ChristmasRoofSnowState(
          position: Offset.lerp(roof, eave, slide)!,
          rotation: -.72 + slide * .30,
          opacity: (age / .15).clamp(0, 1),
          scatter: 0);
    }
    if (age < 2.2) {
      final fall = (age - 1.3) / .9;
      return ChristmasRoofSnowState(
          position: Offset(eave.dx + (bank.dx - eave.dx) * fall,
              eave.dy + (bank.dy - eave.dy) * fall * fall),
          rotation: -.42 + fall * 1.9,
          opacity: 1,
          scatter: 0);
    }
    final scatter = (age - 2.2) / 1.4;
    return ChristmasRoofSnowState(
        position: bank, rotation: 0, opacity: 1 - scatter, scatter: scatter);
  }
}
