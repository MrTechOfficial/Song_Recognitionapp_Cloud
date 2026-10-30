import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/seasonal/scene_frame_clock.dart';
import 'package:song_recognition_app/seasonal/halloween_timeline.dart';
import 'package:song_recognition_app/seasonal/christmas_weather.dart';
import 'dart:ui';

void main() {
  testWidgets(
      'paced scenes lower idle work, honor audio/thermal limits and stop cleanly',
      (tester) async {
    final policy = SceneEnergyPolicy();
    final clock = SceneFrameClock(policy: policy)..repeat();
    await tester.pump(const Duration(seconds: 10));
    expect(clock.frames, inInclusiveRange(239, 241));
    policy.setBusy(true);
    final before = clock.frames;
    await tester.pump(const Duration(seconds: 10));
    expect(clock.frames - before, inInclusiveRange(119, 121));
    policy.setBusy(false);
    await tester.pump(const Duration(seconds: 30));
    expect(policy.fps, 12);
    policy.noteInteraction();
    expect(policy.fps, 24);
    policy.apply({'thermal': 2, 'lowPower': false});
    expect(policy.fps, 8);
    policy.apply({'thermal': 3, 'lowPower': false});
    final frozen = clock.seconds;
    await tester.pump(const Duration(seconds: 30));
    expect(clock.seconds, frozen);
    policy.apply({'thermal': 0, 'lowPower': true});
    expect(policy.fps, 12);
    await tester.pump(const Duration(seconds: 1));
    expect(clock.seconds, greaterThan(frozen));
    clock.stop();
    final stopped = clock.seconds;
    await tester.pump(const Duration(minutes: 1));
    expect(clock.seconds, stopped);
    clock.dispose();
    policy.dispose();
  });
  test(
      'painted pumpkin is quiet, eyes flicker rarely, and leaves wait nine sways',
      () {
    final scene = HalloweenTimeline(seed: 42);
    var flickerFrames = 0, otherFaceFrames = 0, looks = 0, blinks = 0;
    for (var i = 0; i < 14400; i++) {
      scene.advance(i / 24);
      if (scene.eyeDim > 0) {
        flickerFrames++;
      }
      if (scene.face != 0) {
        otherFaceFrames++;
      }
      if (scene.turn.abs() > .01) {
        looks++;
      }
      if (scene.eyelid > .01) {
        blinks++;
      }
      expect(scene.turn.abs() > .01 && scene.eyelid > .01, isFalse);
      expect(scene.sways.leavesReleased, scene.sways.completed ~/ 9);
    }
    expect(flickerFrames / 14400, lessThan(.04));
    expect(otherFaceFrames / 14400, lessThan(.12));
    expect(looks, greaterThan(0));
    expect(blinks, greaterThan(0));
    expect(scene.sways.leavesReleased, inInclusiveRange(3, 7));
  });
  test('winter gusts visit different heights and both directions', () {
    const visible = Rect.fromLTWH(0, 0, 941, 1672);
    final heights = <int>{}, directions = <bool>{};
    for (var t = 0.0; t < 100; t += .5) {
      for (var i = 0; i < 4; i++) {
        final gust = ChristmasBreeze.sample(t, visible, i);
        if (gust.opacity > .2) {
          heights.add((gust.position.dy / 200).floor());
          directions.add(gust.rightward);
        }
      }
    }
    expect(heights.length, greaterThanOrEqualTo(5));
    expect(directions.length, 2);
  });
}
