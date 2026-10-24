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
        expect(pose.feet.dy, inInclusiveRange(760, 1370));
        expect(pose.width, inInclusiveRange(53, 124));
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
          greaterThan(visible.width * .5));
      expect(ys.reduce(math.max) - ys.reduce(math.min), greaterThan(170));
    }
  });

  test('route joins and stride remain continuous across the entire loop', () {
    final route = ChristmasSkatingRoute(const Rect.fromLTWH(0, 0, 941, 1672));
    for (final join in [0.0, 18.0, 38.0, 48.0, 56.0, 66.0, 76.0, 86.0, 96.0]) {
      final t = join - 30;
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

  test('measured controls leave intermittent unobstructed near passes', () {
    const visible = Rect.fromLTWH(84, 0, 773, 1672);
    const cards = Rect.fromLTWH(120, 810, 700, 378);
    const instructions = Rect.fromLTWH(120, 1380, 700, 130);
    final route = ChristmasSkatingRoute(visible,
        cards: cards, instructions: instructions);
    var clearNear = 0, behindCards = 0;
    for (var i = 0; i < 960; i++) {
      final p = route.sample(i / 10);
      final body = Rect.fromLTWH(p.feet.dx - p.width * .52,
          p.feet.dy - p.width * .95, p.width, p.width * 1.23);
      if (body.top > cards.bottom && body.bottom < instructions.top) {
        clearNear++;
      }
      if (body.overlaps(cards)) behindCards++;
    }
    expect(clearNear, greaterThan(90));
    expect(clearNear, lessThan(450));
    expect(behindCards, greaterThan(150));
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

  testWidgets(
      'Christmas host measures controls without moving them or capturing taps',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: ChristmasSceneHost(
            child: Stack(children: [
      Positioned(
          left: 40,
          top: 220,
          width: 300,
          height: 150,
          child: ChristmasSceneRegion(
              id: ChristmasSceneRegionId.cards,
              child: TextButton(
                  onPressed: () => taps++, child: const Text('Environment')))),
      const Positioned(
          left: 40,
          top: 510,
          width: 300,
          height: 60,
          child: ChristmasSceneRegion(
              id: ChristmasSceneRegionId.instructions,
              child: Text('Instruction panel'))),
    ]))));
    await tester.pump();
    await tester.pump();
    final rect = tester.getRect(find.text('Instruction panel'));
    await tester.pump(const Duration(seconds: 25));
    expect(tester.getRect(find.text('Instruction panel')), rect);
    await tester.tap(find.text('Environment'));
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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
