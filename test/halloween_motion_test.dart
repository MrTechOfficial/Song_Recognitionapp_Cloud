import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/seasonal/halloween_motion.dart';
import 'package:song_recognition_app/seasonal/halloween_timeline.dart';
import 'package:song_recognition_app/seasonal/halloween_carvings.dart';

void main() {
  test(
      'painted pumpkin landmarks keep a fold-free mesh through every face transition',
      () {
    final faces = HalloweenCarvings.landmarks,
        indices = HalloweenCarvings.indices;
    for (var from = 0; from < faces.length; from++) {
      for (var to = from + 1; to < faces.length; to++) {
        for (var frame = 0; frame <= 20; frame++) {
          final points = [
            for (var i = 0; i < faces[from].length; i++)
              Offset.lerp(faces[from][i], faces[to][i], frame / 20)!
          ];
          for (var i = 0; i < indices.length; i += 3) {
            final a = points[indices[i + 1]] - points[indices[i]];
            final b = points[indices[i + 2]] - points[indices[i]];
            expect(a.dx * b.dy - a.dy * b.dx, greaterThan(-.0001));
          }
        }
      }
    }
  });
  test('slower clouds leave a long clear-sky gap between moon shade passes',
      () {
    for (var band = 0; band < 6; band++) {
      expect(HalloweenSky.bandLeft(10, band).abs(), inInclusiveRange(7, 15));
    }
    final mask = HalloweenMoonOcclusion(List.filled(32 * 12, 1), 32, 12);
    const visible = Rect.fromLTWH(42, 0, 322, 696);
    for (var second = 95; second < 175; second++) {
      expect(
          mask.dimming(HalloweenSky.bankRect(
              HalloweenSky.bankPhase(second.toDouble()), visible)),
          0);
    }
    final scene = HalloweenTimeline(seed: 7);
    final directions = <bool>{}, altitudes = <int>{};
    for (var step = 0; step < 3600; step++) {
      scene.advance(step / 10);
      for (final flight in scene.flights) {
        directions.add(flight.rightward);
        altitudes.add(flight.altitude.round());
        expect(flight.duration, inInclusiveRange(10, 15));
        expect(flight.flapPeriod, greaterThanOrEqualTo(.85));
      }
      expect(scene.treeAmplitude.abs(), lessThanOrEqualTo(15));
    }
    expect(directions.length, 2);
    expect(altitudes.length, greaterThan(12));
  });
  test('one leaf is released only after every ninth completed sway', () {
    final counter = HalloweenSwayCounter();
    for (var cycle = 1; cycle <= 15; cycle++) {
      expect(counter.complete(), cycle % 9 == 0);
      expect(counter.completed, cycle);
      expect(counter.leavesReleased, cycle ~/ 9);
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
    expect(mask.dimming(covered), closeTo(.30, .00001));
    expect(
        HalloweenMoonOcclusion(List.filled(32 * 12, 0), 32, 12)
            .dimming(covered),
        0);
    const visible = Rect.fromLTWH(42, 0, 322, 696);
    final levels = List.generate(
        1001, (i) => mask.dimming(HalloweenSky.bankRect(i / 1000, visible)));
    expect(levels.first, 0);
    expect(levels.last, 0);
    expect(levels.reduce(math.max), greaterThan(.20));
    final shadeCurve = List.generate(
        1001, (i) => HalloweenMoonOcclusion.shadeForCoverage(i / 1000));
    for (var i = 1; i < shadeCurve.length; i++) {
      expect((shadeCurve[i] - shadeCurve[i - 1]).abs(), lessThan(.002));
    }
  });

  test(
      'rounded skull turns and blinks while the painted neck joint stays fixed',
      () {
    for (final turn in [-1.0, -.5, 0.0, .5, 1.0]) {
      for (final blink in [0.0, .5, 1.0]) {
        final joint = HalloweenMotion.skullVertex(
            HalloweenMotion.skullPivot, turn, blink,
            nod: 1);
        expect(joint, HalloweenMotion.skullPivot);
        expect(
            HalloweenMotion.skullRect.topLeft +
                joint * HalloweenMotion.skullScale,
            HalloweenMotion.neck);
      }
    }
    const eye = Offset(33, 46);
    final left = HalloweenMotion.skullVertex(eye, -1, 0);
    final right = HalloweenMotion.skullVertex(eye, 1, 0);
    expect(right.dx - left.dx, greaterThan(10));
    final upper = HalloweenMotion.skullVertex(const Offset(33, 35), 0, 1);
    final lower = HalloweenMotion.skullVertex(const Offset(33, 55), 0, 1);
    expect(lower.dy - upper.dy, lessThan(2));
  });

  test('all six painted sky bands move at distinct rates', () {
    final shifts = [for (var i = 0; i < 6; i++) HalloweenSky.bandLeft(10, i)];
    expect(shifts.toSet().length, 6);
    for (final shift in shifts) {
      expect(shift, lessThan(-6.5));
      expect(shift, greaterThan(-406));
    }
    expect(HalloweenSky.heights.toSet().length, 6);
    const visible = Rect.fromLTWH(42, 0, 322, 696);
    expect(HalloweenSky.bankRect(0, visible).left, greaterThan(visible.right));
    expect(HalloweenSky.bankRect(1, visible).right, lessThan(visible.left));
  });
}
