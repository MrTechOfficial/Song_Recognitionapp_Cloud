import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/seasonal/halloween_motion.dart';

void main() {
  test('one leaf is released only after every third completed sway', () {
    final counter = HalloweenSwayCounter();
    for (var cycle = 1; cycle <= 15; cycle++) {
      expect(counter.complete(), cycle % 3 == 0);
      expect(counter.completed, cycle);
      expect(counter.leavesReleased, cycle ~/ 3);
    }
  });

  test('tree flex stays rooted, moves both ways, and settles without a snap',
      () {
    final tips = List.generate(
        101, (i) => HalloweenMotion.treeOffset(100, i / 100, 4).dx);
    expect(tips.reduce(math.max), greaterThan(1));
    expect(tips.reduce(math.min), lessThan(-1));
    for (var i = 0; i <= 100; i++) {
      final p = i / 100;
      expect(HalloweenMotion.treeOffset(620, p, 4), Offset.zero);
      expect(HalloweenMotion.treeOffset(650, p, 4), Offset.zero);
      expect(HalloweenMotion.treeOffset(550, p, 4).distance, lessThan(.15));
    }
    expect(HalloweenMotion.treeOffset(100, 0, 4).distance, 0);
    expect(HalloweenMotion.treeOffset(100, 1, 4).distance, lessThan(.00001));
  });

  test(
      'painted head keyframes have still holds and continuous returns to center',
      () {
    for (final direction in [-1.0, 1.0]) {
      expect(HalloweenMotion.headTurn(0, direction), 0);
      expect(HalloweenMotion.headTurn(1, direction), closeTo(0, .00001));
      expect(HalloweenMotion.headTurn(.25, direction), direction);
      expect(HalloweenMotion.headTurn(.30, direction), direction);
      expect(HalloweenMotion.headTurn(.52, direction), closeTo(0, .00001));
      expect(HalloweenMotion.headTurn(.78, direction),
          closeTo(-direction * .82, .00001));
      for (var i = 1; i < 1000; i++) {
        expect(
            (HalloweenMotion.headTurn(i / 1000, direction) -
                    HalloweenMotion.headTurn((i - 1) / 1000, direction))
                .abs(),
            lessThan(.02));
      }
    }
    expect(HalloweenMotion.blink(0), 0);
    expect(HalloweenMotion.blink(.4), 1);
    expect(HalloweenMotion.blink(1), 0);
  });

  test('bats enter and leave off screen, cross the moon, and flap in flight',
      () {
    const visible = Rect.fromLTWH(42, 0, 322, 696);
    for (final rightward in [true, false]) {
      final flight = HalloweenBatFlight(
          rightward: rightward,
          width: 26,
          duration: 12,
          delay: .8,
          altitude: -4,
          bend: 9,
          flapPeriod: .7,
          flapPhase: .2);
      final start = flight.sample(.8, visible),
          end = flight.sample(12.8, visible);
      expect(flight.sample(0, visible).visible, isFalse);
      expect(flight.sample(14, visible).visible, isFalse);
      expect(
          rightward
              ? start.center.dx + 13 < visible.left
              : start.center.dx - 13 > visible.right,
          isTrue);
      expect(
          rightward
              ? end.center.dx - 13 > visible.right
              : end.center.dx + 13 < visible.left,
          isTrue);
      final poses =
          List.generate(240, (i) => flight.sample(.8 + i / 20, visible));
      expect(
          poses.any(
              (p) => (p.center - HalloweenMoonOcclusion.moon).distance < 40),
          isTrue);
      expect(
          (flight.sample(2, visible).flap - flight.sample(2.2, visible).flap)
              .abs(),
          greaterThan(.3));
      expect(
          poses.map((p) => p.center.dy).reduce(math.max) -
              poses.map((p) => p.center.dy).reduce(math.min),
          greaterThan(5));
    }
  });

  test('leaves start at the bough, flutter, and fade near the ground', () {
    const leaf = HalloweenLeafFlight(
        origin: Offset(145, 235),
        landingY: 640,
        drift: 60,
        phase: .7,
        duration: 8,
        width: 11,
        assetIndex: 1);
    expect(leaf.position(0), leaf.origin);
    expect(leaf.position(1), const Offset(205, 640));
    expect(leaf.opacity(0), 0);
    expect(leaf.opacity(.5), 1);
    expect(leaf.opacity(.95), lessThan(.4));
    expect(leaf.opacity(1), 0);
    expect((leaf.rotation(.4) - leaf.rotation(.6)).abs(), greaterThan(.1));
    final ys = List.generate(101, (i) => leaf.position(i / 100).dy);
    expect(ys, orderedEquals([...ys]..sort()));
  });

  test(
      'moon dimming follows actual cloud coverage and leaves clear sky unchanged',
      () {
    final mask = HalloweenMoonOcclusion(List.filled(32 * 12, 1), 32, 12);
    expect(mask.dimming(const Rect.fromLTWH(-300, 60, 230, 62)), 0);
    final covered = Rect.fromCenter(
        center: HalloweenMoonOcclusion.moon, width: 130, height: 130);
    expect(mask.coverage(covered), 1);
    expect(mask.dimming(covered), closeTo(.11, .00001));
    expect(
        HalloweenMoonOcclusion(List.filled(32 * 12, 0), 32, 12)
            .dimming(covered),
        0);
    const visible = Rect.fromLTWH(42, 0, 322, 696);
    final levels = List.generate(1001,
        (i) => mask.dimming(HalloweenMotion.cloudRect(i / 1000, visible)));
    expect(levels.first, 0);
    expect(levels.last, 0);
    expect(levels.reduce(math.max), greaterThan(.08));
    for (var i = 1; i < levels.length; i++) {
      expect((levels[i] - levels[i - 1]).abs(), lessThan(.02));
    }
  });

  test('candle flicker is warm and bounded with a continuous long-cycle seam',
      () {
    final levels = List.generate(4301, (i) => HalloweenMotion.candle(i / 4300));
    expect(levels.reduce(math.min), greaterThan(.25));
    expect(levels.reduce(math.max), lessThan(.85));
    expect(levels.reduce(math.max) - levels.reduce(math.min), greaterThan(.25));
    expect(levels.first, closeTo(levels.last, .000001));
    for (var i = 1; i < levels.length; i++) {
      expect((levels[i] - levels[i - 1]).abs(), lessThan(.03));
    }
  });
}
