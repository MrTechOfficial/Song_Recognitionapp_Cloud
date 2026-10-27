import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/seasonal/halloween_scene_v2.dart';

Widget host({bool reduce = false, bool ticker = true}) => MaterialApp(
    home: MediaQuery(
        data: MediaQueryData(
            size: const Size(390, 844), disableAnimations: reduce),
        child: TickerMode(
            enabled: ticker,
            child: const HalloweenLayeredSceneV2(randomSeed: 42))));

void main() {
  testWidgets('third-sway leaf rule is wired to real completed tree gestures',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    final dynamic state = tester.state(find.byType(HalloweenLayeredSceneV2));
    // Exercise decoded tree/cloud painting, not just the safe static fallback.
    for (var i = 0; i < 50 && !state.layersReady; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(state.layersReady, isTrue);
    var highestLeaf = 0;
    var blinks = 0, looks = 0;
    final seenFaces = <int>{};
    var pumpkinBlinks = 0;
    for (var i = 0; i < 1100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final head = tester
          .widget<HalloweenPaintedHead>(find.byType(HalloweenPaintedHead));
      expect(head.blink > .01 && head.turn.abs() > .001, isFalse);
      if (head.blink > .01) blinks++;
      if (head.turn.abs() > .1) looks++;
      final pumpkin =
          tester.widget<HalloweenPumpkin>(find.byType(HalloweenPumpkin));
      seenFaces.add(pumpkin.face);
      if (pumpkin.blink > .05) pumpkinBlinks++;
      expect(state.releasedLeaves, state.completedTreeSways ~/ 3);
      if (state.completedTreeSways < 3) {
        expect(find.byType(HalloweenFallingLeaf), findsNothing);
      }
      if (find.byType(HalloweenFallingLeaf).evaluate().isNotEmpty) {
        final leaf = tester
            .widget<HalloweenFallingLeaf>(find.byType(HalloweenFallingLeaf));
        expect(leaf.generation, state.completedTreeSways ~/ 3);
        highestLeaf = leaf.generation;
      }
    }
    expect(state.completedTreeSways, greaterThanOrEqualTo(9));
    expect(state.layersReady, isTrue);
    expect(find.byType(HalloweenTreeLayer), findsOneWidget);
    expect(highestLeaf, greaterThanOrEqualTo(3));
    expect(blinks, greaterThan(0));
    expect(looks, greaterThan(0));
    expect(seenFaces.length, 3);
    expect(pumpkinBlinks, greaterThan(0));
    expect(state.launchedBats, greaterThanOrEqualTo(18));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'moon shade reaches real UI, preserves taps, and clears with Reduce Motion',
      (tester) async {
    var taps = 0;
    Widget app({bool reduce = false}) => MaterialApp(
            home: MediaQuery(
          data: MediaQueryData(
              size: const Size(390, 844), disableAnimations: reduce),
          child: HalloweenSceneHost(
              child: Center(
                  child: TextButton(
                      onPressed: () => taps++,
                      child: const Text('Real control')))),
        ));
    await tester.pumpWidget(app());
    final dynamic state = tester.state(find.byType(HalloweenLayeredSceneV2));
    for (var i = 0; i < 60 && !state.layersReady; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(state.layersReady, isTrue);
    var peak = 0.0;
    for (var i = 0; i < 1000; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final opacity = tester
          .widget<Opacity>(
              find.byKey(const ValueKey('halloween-ui-moon-dimming')))
          .opacity;
      if (opacity > peak) peak = opacity;
      if (opacity > .20 && taps == 0) {
        await tester.tap(find.text('Real control'));
      }
    }
    expect(peak, greaterThan(.22));
    expect(peak, lessThanOrEqualTo(.30));
    expect(taps, 1);
    await tester.pumpWidget(app(reduce: true));
    await tester.pump();
    expect(
        tester
            .widget<Opacity>(
                find.byKey(const ValueKey('halloween-ui-moon-dimming')))
            .opacity,
        0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'background pauses gestures and leaf counter; resume continues safely',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    final dynamic state = tester.state(find.byType(HalloweenLayeredSceneV2));
    final head =
        tester.widget<HalloweenPaintedHead>(find.byType(HalloweenPaintedHead));
    final before = state.completedTreeSways;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 45));
    expect(state.completedTreeSways, before);
    expect(
        tester
            .widget<HalloweenPaintedHead>(find.byType(HalloweenPaintedHead))
            .turn,
        head.turn);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(state.completedTreeSways, greaterThan(before));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduce Motion and disabled TickerMode keep Halloween still',
      (tester) async {
    for (final reduce in [true, false]) {
      await tester.pumpWidget(host(reduce: reduce, ticker: reduce));
      final dynamic state = tester.state(find.byType(HalloweenLayeredSceneV2));
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      final head = tester
          .widget<HalloweenPaintedHead>(find.byType(HalloweenPaintedHead));
      expect(head.turn, 0);
      expect(head.blink, 0);
      expect(state.completedTreeSways, 0);
      expect(find.byType(HalloweenFallingLeaf), findsNothing);
      if (reduce) {
        expect(
            find.byKey(const ValueKey('halloween-moon-dimming')), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(tester.takeException(), isNull);
  });
}
