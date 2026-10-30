import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/seasonal/christmas_scene.dart';
import 'package:song_recognition_app/seasonal/christmas_weather.dart';
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
  test('lake route uses depth and stays within the visible ice', () {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(430, 932),
      const Size(768, 1024),
      const Size(844, 390)
    ]) {
      final geometry = SeasonalSceneGeometry(const Size(941, 1672), size);
      final visible = geometry.visibleSourceRect;
      final route = ChristmasSkatingRoute(visible);
      final poses = List.generate(960, (i) => route.sample(i / 10));
      for (final pose in poses) {
        expect(pose.feet.dy, inInclusiveRange(760, 1450));
        expect(pose.width, inInclusiveRange(103, 230));
        expect(pose.feet.dx - pose.width * .52,
            greaterThanOrEqualTo(visible.left));
        expect(
            pose.feet.dx + pose.width * .48, lessThanOrEqualTo(visible.right));
        expect(pose.feet.dy + pose.width * .28, lessThan(visible.bottom));
        expect(pose.strideBlend, inInclusiveRange(0, 1));
        expect(pose.lift, inInclusiveRange(0, .81));
      }
      final xs = poses.map((p) => p.feet.dx);
      final ys = poses.map((p) => p.feet.dy);
      expect(xs.reduce(math.max) - xs.reduce(math.min),
          greaterThan(visible.width * .4));
      expect(ys.reduce(math.max) - ys.reduce(math.min),
          greaterThan(math.min(170, visible.height * .3)));
    }
  });

  test('large near passes clear the narrowing banks with the whole character',
      () {
    final visible =
        SeasonalSceneGeometry(const Size(941, 1672), const Size(390, 844))
            .visibleSourceRect;
    final route = ChristmasSkatingRoute(visible);
    final near = List.generate(1920, (frame) => route.sample(frame / 20))
        .where((pose) => pose.depth > .8);
    expect(near, isNotEmpty);
    for (final pose in near) {
      // The foreground banks/trees begin outside this strip in the artwork.
      expect(pose.feet.dx - pose.width * .52, greaterThan(180));
      expect(pose.feet.dx + pose.width * .48, lessThan(760));
      expect(pose.feet.dy, lessThan(1410));
    }
    expect(near.map((p) => p.width).reduce(math.max), greaterThan(220));
  });

  test('route joins and stride remain continuous across the entire loop', () {
    final route = ChristmasSkatingRoute(const Rect.fromLTWH(0, 0, 941, 1672));
    for (final join in [0.0, 18.0, 38.0, 48.0, 56.0, 66.0, 76.0, 86.0, 96.0]) {
      final t = join - ChristmasSkatingRoute.startingPhase;
      final a = route.sample(t - .001), b = route.sample(t + .001);
      expect((a.feet - b.feet).distance, lessThan(.15));
      expect((a.width - b.width).abs(), lessThan(.02));
      expect((a.strideBlend - b.strideBlend).abs(), lessThan(.04));
      final before = (a.feet - route.sample(t - .002).feet) / .001;
      final after = (route.sample(t + .002).feet - b.feet) / .001;
      expect((before - after).distance, lessThan(.1));
    }
  });

  test(
      'near passes have stronger depth cues and the two pushes include long glides',
      () {
    final route = ChristmasSkatingRoute(const Rect.fromLTWH(0, 0, 941, 1672));
    final poses = List.generate(1920, (i) => route.sample(i / 20));
    final near = poses.where((p) => p.depth > .8).toList();
    final far = poses.where((p) => p.depth < .12).toList();
    expect(near, isNotEmpty);
    expect(far, isNotEmpty);
    expect(near.first.width, greaterThan(far.first.width * 1.7));
    expect(near.first.shadowWidth, greaterThan(far.first.shadowWidth * 2));
    expect(near.first.reflectionOpacity,
        greaterThan(far.first.reflectionOpacity * 2));
    expect(near.map((p) => p.speed).reduce(math.max),
        greaterThan(far.map((p) => p.speed).reduce(math.max)));
    expect(poses.where((p) => p.strideBlend > .99).length, greaterThan(200));
    expect(poses.where((p) => p.strideBlend < .01).length, greaterThan(200));
    expect(poses.where((p) => p.lift < .001).length,
        greaterThan(poses.length ~/ 2));
  });

  test('twinkles stay visible, vary independently, and loop smoothly', () {
    var strongest = 0.0;
    for (var i = 0; i < 960; i++) {
      final t = i / 20;
      final levels =
          List.generate(7, (j) => ChristmasWeather.lightIntensity(t, j));
      expect(levels.where((v) => v > .01).length, inInclusiveRange(1, 4));
      expect(levels.every((v) => v >= 0 && v <= 1), isTrue);
      if (t < 4) strongest = math.max(strongest, levels.reduce(math.max));
    }
    expect(strongest, greaterThan(.95));
    for (var i = 0; i < 7; i++) {
      expect(ChristmasWeather.lightIntensity(1.5, i),
          closeTo(ChristmasWeather.lightIntensity(193.5, i), 1e-12));
      final cycle = List.generate(
          160, (frame) => ChristmasWeather.lightIntensity(frame / 20, i));
      expect(cycle.reduce(math.max) - cycle.reduce(math.min), greaterThan(.99));
    }
  });

  test(
      'clouds visibly travel and foreground gusts start in the opening seconds',
      () {
    for (var layer = 0; layer < 3; layer++) {
      final travel = (ChristmasWeather.cloudX(4, layer) -
              ChristmasWeather.cloudX(0, layer))
          .abs();
      expect(travel, inExclusiveRange(25, 60));
      expect(ChristmasWeather.cloudX(384, layer),
          closeTo(ChristmasWeather.cloudX(0, layer), .001));
    }
    expect(ChristmasWeather.gustStrength(4), greaterThan(.95));
    expect(ChristmasWeather.gustStrength(10), 0);
    expect(ChristmasWeather.wind(4).abs(), greaterThan(40));
  });

  test(
      'roof snow falls from the front cap and settles quickly into the bank pile',
      () {
    expect(ChristmasWeather.roofSnowAt(0).visible, isFalse);
    final slide = ChristmasWeather.roofSnowAt(3.5);
    final falling = ChristmasWeather.roofSnowAt(4.5);
    final fallingLater = ChristmasWeather.roofSnowAt(4.8);
    final landed = ChristmasWeather.roofSnowAt(5.4);
    expect(slide.visible, isTrue);
    expect(slide.position.dx, lessThan(falling.position.dx));
    expect(slide.position.dy, lessThan(falling.position.dy));
    final earlyDrop =
        ChristmasWeather.roofSnowAt(4.6).position.dy - falling.position.dy;
    final lateDrop =
        ChristmasWeather.roofSnowAt(4.9).position.dy - fallingLater.position.dy;
    expect(lateDrop, greaterThan(earlyDrop));
    expect(landed.position, const Offset(826, 725));
    expect(landed.landed, isTrue);
    expect(ChristmasWeather.roofSnowAt(5.9).visible, isFalse);
    for (final join in [4.35, 5.2]) {
      expect(
          (ChristmasWeather.roofSnowAt(join - .0001).position -
                  ChristmasWeather.roofSnowAt(join + .0001).position)
              .distance,
          lessThan(.05));
    }
    expect(ChristmasWeather.roofSnowAt(3.5).position,
        ChristmasWeather.roofSnowAt(27.5).position);
    expect(ChristmasWeather.wind(0), closeTo(ChristmasWeather.wind(192), .001));
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
      final dynamic state = tester.state(find.byType(HalloweenLayeredSceneV2));
      final blink = state.timeline.eyelid as double;
      final turning = state.timeline.turn.abs() > .00001;
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
        (tester.state(find.byType(HalloweenLayeredSceneV2)) as dynamic)
            .timeline
            .eyelid,
        0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'scrolling foreground UI never retargets or teleports the snowman',
      (tester) async {
    tester.view.physicalSize = const Size(780, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Row(children: [
      Expanded(
          child: ChristmasSceneHost(
              key: const ValueKey('control-world'),
              child: SingleChildScrollView(
                  child: SizedBox(height: 1800, child: Text('Control UI'))))),
      Expanded(
          child: ChristmasSceneHost(
              key: const ValueKey('scroll-world'),
              child: SingleChildScrollView(
                  key: const ValueKey('scroll-ui'),
                  controller: scroll,
                  child: SizedBox(height: 1800, child: Text('Scrolling UI'))))),
    ])));
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    Positioned snowman(String world) =>
        tester.widget<Positioned>(find.descendant(
            of: find.byKey(ValueKey(world)),
            matching: find.byKey(const ValueKey('christmas-snowman'))));
    await tester.drag(
        find.byKey(const ValueKey('scroll-ui')), const Offset(0, -420));
    for (final delay in [17, 300, 1800]) {
      await tester.pump(Duration(milliseconds: delay));
      final a = snowman('control-world'), b = snowman('scroll-world');
      expect(b.left, closeTo(a.left!, .001));
      expect(b.top, closeTo(a.top!, .001));
      expect(b.width, closeTo(a.width!, .001));
    }
    expect(scroll.offset, greaterThan(200));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
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
