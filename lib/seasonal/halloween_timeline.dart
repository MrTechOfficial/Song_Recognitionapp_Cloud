import 'dart:math' as math;
import 'dart:ui';
import 'halloween_motion.dart';

class HalloweenSky {
  static const tops = [53.0, 112.0, 155.0, 300.0, 388.0, 470.0];
  static const heights = [59.0, 43.0, 57.0, 88.0, 82.0, 65.0];
  static double bandLeft(double seconds, int index) =>
      -(seconds * (.72 + index * .14) % 406);
  // One gentle crossing, followed by clear sky. The former 62-second loop
  // shaded the controls too often. Reset happens fully outside the viewport.
  static const bankCycle = 180.0, bankTravel = 86.0;
  static double bankPhase(double seconds) =>
      ((seconds % bankCycle) / bankTravel + .02).clamp(0.0, 1.0);
  static Rect bankRect(double phase, Rect visible) => Rect.fromLTWH(
      visible.right + 40 - phase * (visible.width + 350 + 80), 27, 350, 139);
}

class HalloweenGesture {
  double start = double.infinity, duration = 1;
  bool active = false;
  double phase(double time) => ((time - start) / duration).clamp(0.0, 1.0);
  void begin(double time, double length) {
    start = time;
    duration = length;
    active = true;
  }

  bool finish(double time) {
    if (!active || time < start + duration) return false;
    active = false;
    return true;
  }
}

/// Small deterministic scene model, advanced only by the paced foreground clock.
/// No timer per effect, repeating candle or background catch-up work.
class HalloweenTimeline {
  HalloweenTimeline({int? seed}) : random = math.Random(seed);
  final math.Random random;
  final look = HalloweenGesture(),
      blink = HalloweenGesture(),
      tree = HalloweenGesture(),
      leaf = HalloweenGesture(),
      bats = HalloweenGesture(),
      candle = HalloweenGesture();
  final sways = HalloweenSwayCounter();
  double time = 0,
      nextLook = 8,
      nextBlink = 4,
      nextTree = 1,
      nextBat = 2,
      nextFace = 38,
      faceUntil = 0,
      nextFlicker = 16;
  double direction = 1, treeAmplitude = 12;
  int face = 0, previousFace = 0, lastFace = 0, launchedBats = 0;
  double faceChangedAt = -1;
  static const faceTransitionSeconds = 1.15;
  double get faceBlend =>
      HalloweenMotion.ease((time - faceChangedAt) / faceTransitionSeconds);
  void _changeFace(int next) {
    previousFace = face;
    face = next;
    faceChangedAt = time;
  }

  HalloweenLeafFlight? fall;
  List<HalloweenBatFlight> flights = [];
  double between(double a, double b) => a + random.nextDouble() * (b - a);
  void advance(double seconds) {
    time = seconds;
    if (look.finish(time)) {
      nextLook = time + between(18, 30);
      nextBlink = time + between(3, 6);
    }
    if (blink.finish(time)) nextBlink = time + between(8, 15);
    if (!look.active && !blink.active && time >= nextLook) {
      direction = (random.nextBool() ? 1 : -1) * between(.65, .85);
      look.begin(time, between(4.5, 6));
    }
    if (!look.active && !blink.active && time >= nextBlink) {
      blink.begin(time, .21);
    }
    if (tree.finish(time)) {
      if (sways.complete()) {
        fall = HalloweenLeafFlight(
            origin: const Offset(197, 221),
            landingY: 640,
            drift: between(-30, 70),
            phase: between(0, 6),
            duration: 8,
            width: 10,
            assetIndex: 1 + random.nextInt(2));
        leaf.begin(time, 8);
      }
      nextTree = time + between(4, 7);
    }
    if (!tree.active && time >= nextTree) {
      treeAmplitude = (random.nextBool() ? 1 : -1) * between(10, 15);
      tree.begin(time, between(8, 11));
    }
    leaf.finish(time);
    if (bats.finish(time)) nextBat = time + between(7, 12);
    if (!bats.active && time >= nextBat) {
      flights = List.generate(
          2 + random.nextInt(3),
          (i) => HalloweenBatFlight(
              rightward: random.nextBool(),
              width: between(20, 32),
              duration: between(10, 15),
              delay: i * between(.6, 1.5),
              altitude: between(-46, 125),
              bend: between(-34, 38),
              flapPeriod: between(.85, 1.2),
              flapPhase: between(0, 6),
              wander: between(3, 9),
              wanderPhase: between(0, math.pi * 2),
              wanderCycles: between(.65, 1.35)));
      launchedBats += flights.length;
      bats.begin(
          time, flights.map((f) => f.delay + f.duration).reduce(math.max));
    }
    if (face != 0 && time >= faceUntil) {
      _changeFace(0);
      nextFace = time + between(35, 55);
    }
    if (face == 0 && time >= nextFace) {
      _changeFace(lastFace == 1 ? 2 : 1);
      lastFace = face;
      faceUntil = time + between(4.5, 5.5);
    }
    if (candle.finish(time)) nextFlicker = time + between(28, 45);
    if (!candle.active && time >= nextFlicker) candle.begin(time, .95);
  }

  double get turn =>
      look.active ? HalloweenMotion.headTurn(look.phase(time), direction) : 0;
  double get eyelid =>
      blink.active ? HalloweenMotion.blink(blink.phase(time)) : 0;
  double get eyeDim {
    if (!candle.active) return 0;
    final p = candle.phase(time);
    return math.sin(p * math.pi) *
        (.12 + .16 * math.pow(math.sin(p * math.pi * 3), 2));
  }
}
