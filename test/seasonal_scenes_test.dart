import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/seasonal/christmas_scene.dart';
import 'package:song_recognition_app/seasonal/halloween_scene_v2.dart';
import 'package:song_recognition_app/seasonal/seasonal_scene_support.dart';
import 'package:song_recognition_app/seasonal_preview.dart';

Widget host(Widget child, {bool reduceMotion = false, bool ticker = true}) =>
    MaterialApp(
      home: MediaQuery(
          data: MediaQueryData(
              size: const Size(390, 844), disableAnimations: reduceMotion),
          child: TickerMode(
              enabled: ticker, child: SizedBox.expand(child: child))),
    );

void main() {
  test(
      'cover geometry and skating path stay on the visible ice at phone and tablet sizes',
      () {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(430, 932),
      const Size(768, 1024),
      const Size(844, 390)
    ]) {
      final geometry = SeasonalSceneGeometry(const Size(941, 1672), size);
      final visible = geometry.visibleSourceRect;
      expect(visible.width * geometry.scale, closeTo(size.width, .001));
      expect(visible.height * geometry.scale, closeTo(size.height, .001));
      for (var i = 0; i <= 720; i++) {
        final pose = SnowmanSkatingPose.at(i / 20, visible);
        expect(pose.feet.dy, inInclusiveRange(850, 1200));
        expect(pose.feet.dx - pose.width * .52,
            greaterThanOrEqualTo(visible.left));
        expect(
            pose.feet.dx + pose.width * .48, lessThanOrEqualTo(visible.right));
        expect(pose.feet.dy - pose.width * .95, greaterThan(750));
      }
    }
  });

  test(
      'skating pauses, turns and returns without teleporting at loop boundaries',
      () {
    const visible = Rect.fromLTWH(0, 0, 941, 1672);
    expect(SnowmanSkatingPose.at(14, visible).moving, isFalse);
    expect(SnowmanSkatingPose.at(20, visible).moving, isTrue);
    expect(SnowmanSkatingPose.at(17, visible).yaw, closeTo(math.pi, .001));
    expect(SnowmanSkatingPose.at(35, visible).yaw, closeTo(0, .001));
    for (final boundary in [13.0, 18.0, 31.0, 36.0, 72.0]) {
      final a = SnowmanSkatingPose.at(boundary - .001, visible);
      final b = SnowmanSkatingPose.at(boundary + .001, visible);
      expect((a.feet - b.feet).distance, lessThan(.02));
      expect((a.yaw - b.yaw).abs(), lessThan(.01));
    }
  });

  testWidgets('decorative scenes leave foreground controls tappable',
      (tester) async {
    var taps = 0;
    for (final scene in [
      const HalloweenLayeredSceneV2(),
      const ChristmasScene()
    ]) {
      await tester.pumpWidget(host(
          Stack(fit: StackFit.expand, children: [
            scene,
            Center(
                child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('Real control'))),
          ]),
          reduceMotion: true));
      await tester.tap(find.text('Real control'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(taps, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'skull blinks and looks on separate schedules, then disposes cleanly',
      (tester) async {
    await tester.pumpWidget(host(const HalloweenLayeredSceneV2()));
    var blinks = 0, looks = 0;
    for (var frame = 0; frame < 500; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      final blink = tester
          .widget<Opacity>(find.byKey(const ValueKey('halloween-blink')))
          .opacity;
      final head = tester
          .widget<Transform>(find.byKey(const ValueKey('halloween-head-turn')));
      final turning = (head.transform.entry(0, 0) - 1).abs() > .00001 ||
          head.transform.entry(0, 1).abs() > .00001;
      if (blink > .01) blinks++;
      if (turning) looks++;
      expect(blink > .01 && turning, isFalse,
          reason: 'Blink and head turn must not overlap');
    }
    expect(blinks, greaterThan(0));
    expect(looks, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 40));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reduced motion and TickerMode stop characters and gesture timers',
      (tester) async {
    await tester.pumpWidget(host(const ChristmasScene(), reduceMotion: true));
    final still = tester
        .widget<Positioned>(find.byKey(const ValueKey('christmas-snowman')))
        .left;
    await tester.pump(const Duration(seconds: 10));
    expect(
        tester
            .widget<Positioned>(find.byKey(const ValueKey('christmas-snowman')))
            .left,
        still);
    await tester.pumpWidget(host(const ChristmasScene(), ticker: false));
    await tester.pump(const Duration(seconds: 10));
    expect(
        tester
            .widget<Positioned>(find.byKey(const ValueKey('christmas-snowman')))
            .left,
        still);
    await tester.pumpWidget(host(const ChristmasScene()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    final moving = tester
        .widget<Positioned>(find.byKey(const ValueKey('christmas-snowman')))
        .left;
    expect(moving, isNot(still));
    await tester
        .pumpWidget(host(const HalloweenLayeredSceneV2(), reduceMotion: true));
    await tester.pump(const Duration(seconds: 60));
    expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('halloween-blink')))
            .opacity,
        0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('app lifecycle freezes and resumes the snowman', (tester) async {
    await tester.pumpWidget(host(const ChristmasScene()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final paused = tester
        .widget<Positioned>(find.byKey(const ValueKey('christmas-snowman')))
        .left;
    await tester.pump(const Duration(seconds: 12));
    expect(
        tester
            .widget<Positioned>(find.byKey(const ValueKey('christmas-snowman')))
            .left,
        paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(
        tester
            .widget<Positioned>(find.byKey(const ValueKey('christmas-snowman')))
            .left,
        isNot(paused));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'preview switches themes and pauses without overflow on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SeasonalPreviewApp());
    await tester.tap(find.byKey(const ValueKey('preview-christmas')));
    await tester.pump();
    expect(find.byType(ChristmasScene), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('preview-pause')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('preview-controls')));
    await tester.pump();
    expect(find.text('Where Are You?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
