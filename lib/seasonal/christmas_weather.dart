import 'dart:math' as math;
import 'package:flutter/material.dart';

class ChristmasBreeze {
  const ChristmasBreeze(this.position, this.opacity, this.rightward);
  final Offset position;
  final double opacity;
  final bool rightward;
  static double _hash(double value) =>
      (math.sin(value * 12.9898) * 43758.5453) % 1;
  static ChristmasBreeze sample(double seconds, Rect visible, int band) {
    final clock = seconds + band * 4.3;
    final cycle = (clock / 17).floor(), age = clock % 17;
    final seed = cycle * 7.0 + band * 23;
    final duration = 4 + _hash(seed + 1) * 2;
    final p = (age / duration).clamp(0.0, 1.0);
    final right = _hash(seed + 3) > .5;
    final progress = right ? p : 1 - p;
    final y = visible.top + visible.height * (.12 + .76 * _hash(seed + 8));
    return ChristmasBreeze(
        Offset(visible.left - 100 + progress * (visible.width + 200),
            y + math.sin(p * math.pi * 2) * 20),
        age < duration ? math.sin(p * math.pi) : 0,
        right);
  }
}

@immutable
class ChristmasRoofSnowState {
  const ChristmasRoofSnowState(
      {required this.position,
      required this.rotation,
      required this.opacity,
      required this.scatter,
      this.pile = 0});
  final Offset position;
  final double rotation, opacity, scatter, pile;
  bool get visible => opacity > 0;
  bool get landed => scatter > 0;
}

/// All weather uses scene time. Pausing the scene pauses every effect, and no
/// weather event can change the skating route or depend on scroll position.
class ChristmasWeather {
  static const loopSeconds = 384;
  static const roofBank = Offset(733, 731);
  static const roofStart = Offset(821, 591), roofEave = Offset(743, 666);
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
    // Follow the front gable's LEFT slope, then drop beside the left wall.
    // A new mound grows on impact, rests, then gently blends back into the bank.
    final age = ((seconds - 3) % 24 + 24) % 24;
    const roof = roofStart, eave = roofEave, bank = roofBank;
    final grow = ((age - 2.4) / .65).clamp(0.0, 1.0);
    final melt = 1 - ((age - 16) / 5).clamp(0.0, 1.0);
    final pile = grow * grow * (3 - 2 * grow) * melt;
    if (age >= 3.15) {
      return ChristmasRoofSnowState(
          position: roof, rotation: -.78, opacity: 0, scatter: 0, pile: pile);
    }
    if (age < 1.25) {
      final slide = math.pow(age / 1.25, 1.7).toDouble();
      return ChristmasRoofSnowState(
          position: Offset.lerp(roof, eave, slide)!,
          rotation: -.78 + slide * .13,
          opacity: (age / .15).clamp(0, 1),
          scatter: 0);
    }
    if (age < 2.4) {
      final fall = (age - 1.25) / 1.15;
      return ChristmasRoofSnowState(
          position: Offset(eave.dx + (bank.dx - eave.dx) * fall,
              eave.dy + (bank.dy - eave.dy) * fall * fall),
          rotation: -.65 - fall * .3,
          opacity: 1,
          scatter: 0);
    }
    final scatter = (age - 2.4) / .75;
    return ChristmasRoofSnowState(
        position: bank,
        rotation: 0,
        opacity: 1 - scatter,
        scatter: scatter,
        pile: pile);
  }
}
