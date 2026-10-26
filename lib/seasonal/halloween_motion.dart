import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';

/// Completed gestures, rather than elapsed time, release the leaves.
class HalloweenSwayCounter {
  int completed = 0;
  int get leavesReleased => completed ~/ 3;
  bool complete() => ++completed % 3 == 0;
}

class HalloweenMotion {
  static double ease(double t) {
    t = t.clamp(0, 1);
    return t * t * t * (t * (6 * t - 15) + 10);
  }

  static double headTurn(double progress, double direction) {
    const times = [0.0, .22, .34, .52, .74, .82, 1.0];
    final poses = [
      0.0,
      direction,
      direction,
      0.0,
      -direction * .82,
      -direction * .82,
      0.0
    ];
    var i = 0;
    while (i < times.length - 2 && progress > times[i + 1]) {
      i++;
    }
    final blend = ease((progress - times[i]) / (times[i + 1] - times[i]));
    return poses[i] + (poses[i + 1] - poses[i]) * blend;
  }

  static double blink(double p) => p < .30
      ? ease(p / .30)
      : p < .50
          ? 1
          : 1 - ease((p - .50) / .50);

  static Offset treeOffset(double y, double phase, double amplitude) {
    final height = ((620 - y) / 530).clamp(0.0, 1.0);
    final envelope = math.pow(math.sin(math.pi * phase), 2).toDouble();
    final bend = math.sin(phase * math.pi * 2 - .25 * (1 - height));
    return Offset(amplitude * envelope * bend * math.pow(height, 1.7),
        amplitude * .055 * envelope * bend.abs() * height);
  }

  static double candle(double phase) {
    final t = phase * math.pi * 2;
    return .55 +
        math.sin(t * 7) * .12 +
        math.sin(t * 19 + .6) * .08 +
        math.sin(t * 47 + 1.3) * .035 +
        math.sin(t * 91) * .015;
  }

  static Rect cloudRect(double progress, Rect visible) => Rect.fromLTWH(
      visible.right + 30 - progress * (visible.width + 290),
      62,
      230,
      230 * 111 / 420);
}

@immutable
class HalloweenBatPose {
  const HalloweenBatPose(this.center, this.flap, this.bank, this.visible);
  final Offset center;
  final double flap, bank;
  final bool visible;
}

@immutable
class HalloweenBatFlight {
  const HalloweenBatFlight(
      {required this.rightward,
      required this.width,
      required this.duration,
      required this.delay,
      required this.altitude,
      required this.bend,
      required this.flapPeriod,
      required this.flapPhase});
  final bool rightward;
  final double width, duration, delay, altitude, bend, flapPeriod, flapPhase;

  HalloweenBatPose sample(double seconds, Rect visible) {
    final age = seconds - delay;
    final p = (age / duration).clamp(0.0, 1.0);
    final start =
        rightward ? visible.left - width * 1.2 : visible.right + width * 1.2;
    final end =
        rightward ? visible.right + width * 1.2 : visible.left - width * 1.2;
    final x = start + (end - start) * p;
    final y = 96 +
        altitude +
        math.sin(p * math.pi) * bend +
        math.sin(p * math.pi * 2 + flapPhase) * 2;
    final slope = (bend * math.pi * math.cos(p * math.pi)) / (end - start);
    return HalloweenBatPose(
        Offset(x, y),
        math.sin(age * math.pi * 2 / flapPeriod + flapPhase) * .62,
        math.atan(slope) * .4,
        age >= 0 && age <= duration);
  }
}

@immutable
class HalloweenLeafFlight {
  const HalloweenLeafFlight(
      {required this.origin,
      required this.landingY,
      required this.drift,
      required this.phase,
      required this.duration,
      required this.width,
      required this.assetIndex});
  final Offset origin;
  final double landingY, drift, phase, duration, width;
  final int assetIndex;
  Offset position(double p) => Offset(
      origin.dx +
          drift * HalloweenMotion.ease(p) +
          math.sin(p * 12 + phase) * 9 * math.sin(p * math.pi),
      origin.dy + (landingY - origin.dy) * math.pow(p.clamp(0, 1), 1.15));
  double rotation(double p) =>
      phase + math.sin(p * 16) * .35 + p * math.pi * 1.8 * drift.sign;
  double opacity(double p) =>
      (p / .035).clamp(0.0, 1.0) * ((1 - p) / .16).clamp(0.0, 1.0);
}

/// A small bilinear alpha map of the actual painted cloud, sampled over the
/// moon's disc. Its position, not an unrelated timer, controls the night shade.
class HalloweenMoonOcclusion {
  HalloweenMoonOcclusion(this.alpha, this.columns, this.rows);
  final List<double> alpha;
  final int columns, rows;
  static const moon = Offset(318, 96);
  static const moonRadius = 46.0;

  factory HalloweenMoonOcclusion.fromRgba(
      Uint8List rgba, int width, int height) {
    const columns = 32, rows = 12;
    final sums = List<double>.filled(columns * rows, 0);
    final counts = List<int>.filled(columns * rows, 0);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final cell = (y * rows ~/ height) * columns + x * columns ~/ width;
        sums[cell] += rgba[(y * width + x) * 4 + 3] / 255;
        counts[cell]++;
      }
    }
    return HalloweenMoonOcclusion(
        List.generate(
            sums.length, (i) => counts[i] == 0 ? 0 : sums[i] / counts[i]),
        columns,
        rows);
  }

  double _alphaAt(double u, double v) {
    if (u < 0 || u > 1 || v < 0 || v > 1) return 0;
    final x = u * (columns - 1), y = v * (rows - 1);
    final x0 = x.floor(), y0 = y.floor();
    final x1 = math.min(x0 + 1, columns - 1), y1 = math.min(y0 + 1, rows - 1);
    final top = alpha[y0 * columns + x0] * (1 - (x - x0)) +
        alpha[y0 * columns + x1] * (x - x0);
    final bottom = alpha[y1 * columns + x0] * (1 - (x - x0)) +
        alpha[y1 * columns + x1] * (x - x0);
    return top * (1 - (y - y0)) + bottom * (y - y0);
  }

  double coverage(Rect cloud) {
    var opacity = 0.0, count = 0;
    for (var y = -10; y <= 10; y++) {
      for (var x = -10; x <= 10; x++) {
        if (x * x + y * y > 100) continue;
        final point = moon + Offset(x * moonRadius / 10, y * moonRadius / 10);
        opacity += _alphaAt((point.dx - cloud.left) / cloud.width,
            (point.dy - cloud.top) / cloud.height);
        count++;
      }
    }
    return opacity / count;
  }

  double dimming(Rect cloud) =>
      .11 * HalloweenMotion.ease(coverage(cloud) * .65 / .38);
}
