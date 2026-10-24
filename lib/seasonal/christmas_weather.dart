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
  static const loopSeconds = 384;
  static const roofBank = Offset(826, 725);
  // Artwork-space centers of the seven bulbs, including the partially cropped
  // bulbs at the sides. Use the same cover transform as the background.
  static const lightPositions = [
    Offset(159, 178),
    Offset(286, 155),
    Offset(399, 116),
    Offset(504, 65),
    Offset(594, 118),
    Offset(716, 156),
    Offset(900, 131),
  ];
  // Short, staggered pulses: something visibly brightens every second or two.
  // No frame flashes the entire string, and eight seconds divides scene time.
  static const _twinkles = [.2, 2.6, 5.1, 1.4, 4.1, .8, 6.2];
  static double lightIntensity(double seconds, int index) {
    final age = ((seconds - _twinkles[index]) % 8 + 8) % 8;
    if (age >= 2.6) return 0;
    final pulse = math.sin(age / 2.6 * math.pi);
    return pulse * pulse;
  }

  static double wind(double seconds) =>
      math.sin(seconds * math.pi * 2 / 24) * 55 +
      math.sin(seconds * math.pi * 2 / 8) * 12;

  // Whole clouds travel steadily instead of barely shifting an almost invisible
  // wisp. Wrap outside the illustration so a cloud never jumps on screen.
  static double cloudX(double seconds, int layer) {
    const starts = [710.0, 1020.0, 220.0];
    const periods = [96.0, 128.0, 192.0];
    const span = 1341.0;
    return ((starts[layer] + seconds * span / periods[layer]) % span + span) %
            span -
        200;
  }

  static double gustStrength(double seconds) {
    final age = ((seconds - 1) % 12 + 12) % 12;
    return age < 6 ? math.sin(age / 6 * math.pi) : 0;
  }

  static ChristmasRoofSnowState roofSnowAt(double seconds) {
    // The front gable's snow cap. Fresh snow joins a small settled pile rather
    // than hanging around as airborne flecks after landing.
    final age = ((seconds - 3) % 24 + 24) % 24;
    const roof = Offset(822, 591), eave = Offset(840, 612), bank = roofBank;
    if (age >= 2.85) {
      return const ChristmasRoofSnowState(
          position: roof, rotation: .78, opacity: 0, scatter: 0);
    }
    if (age < 1.35) {
      final slide = math.pow(age / 1.35, 1.7).toDouble();
      return ChristmasRoofSnowState(
          position: Offset.lerp(roof, eave, slide)!,
          rotation: .78 - slide * .13,
          opacity: (age / .15).clamp(0, 1),
          scatter: 0);
    }
    if (age < 2.2) {
      final fall = (age - 1.35) / .85;
      return ChristmasRoofSnowState(
          position: Offset(eave.dx + (bank.dx - eave.dx) * fall,
              eave.dy + (bank.dy - eave.dy) * fall * fall),
          rotation: .65 + fall * .6,
          opacity: 1,
          scatter: 0);
    }
    final scatter = (age - 2.2) / .65;
    return ChristmasRoofSnowState(
        position: bank, rotation: 0, opacity: 1 - scatter, scatter: scatter);
  }
}
