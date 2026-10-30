import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/seasonal/halloween_scene_v2.dart';

Widget host({bool reduce = false, bool ticker = true, Widget? child}) =>
    MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(
                size: const Size(390, 844), disableAnimations: reduce),
            child: TickerMode(
                enabled: ticker,
                child:
                    child ?? const HalloweenLayeredSceneV2(randomSeed: 42))));
Future<dynamic> ready(WidgetTester tester) async {
  final dynamic state = tester.state(find.byType(HalloweenLayeredSceneV2));
  for (var i = 0; i < 100 && !state.layersReady; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  expect(state.layersReady, isTrue);
  return state;
}

void main() {
  testWidgets(
      'ten idle minutes stay bounded; leaves are rare and painted faces stay quiet',
      (tester) async {
    await tester.pumpWidget(host());
    final state = await ready(tester);
    final count = state.images.length;
    final bytes = state.images.values.fold<int>(
        0,
        (int sum, dynamic image) =>
            sum + (image.width as int) * (image.height as int) * 4);
    expect(bytes, lessThan(8 * 1024 * 1024));
    await tester.pump(const Duration(minutes: 10));
    expect(state.images.length, count);
    expect(state.frameCount, lessThan(8000));
    expect(state.releasedLeaves, inInclusiveRange(3, 7));
    expect(state.releasedLeaves, state.completedTreeSways ~/ 9);
    expect(state.timeline.flights.length, lessThanOrEqualTo(4));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 2));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'coverage-based UI shade is visible, tappable and clears for Reduce Motion',
      (tester) async {
    var taps = 0;
    Widget app(bool reduce) => host(
        reduce: reduce,
        child: HalloweenSceneHost(
            child: Center(
                child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('Real control')))));
    await tester.pumpWidget(app(false));
    final state = await ready(tester);
    var peak = 0.0;
    for (var i = 0; i < 600; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final alpha = tester
          .widget<ColoredBox>(
              find.byKey(const ValueKey('halloween-ui-moon-dimming')))
          .color
          .a;
      if (alpha > peak) {
        peak = alpha;
      }
      if (alpha > .30 && taps == 0) {
        await tester.tap(find.text('Real control'));
        state.clock.policy.apply({'thermal': 3, 'lowPower': false});
        await tester.pump();
        expect(
            tester
                .widget<ColoredBox>(
                    find.byKey(const ValueKey('halloween-ui-moon-dimming')))
                .color
                .a,
            0);
        final frames = state.frameCount;
        await tester.pump(const Duration(seconds: 2));
        expect(state.frameCount, frames);
        state.clock.policy.apply({'thermal': 0, 'lowPower': false});
      }
    }
    expect(peak, greaterThan(.33));
    expect(peak, lessThanOrEqualTo(.40));
    expect(taps, 1);
    await tester.pumpWidget(app(true));
    await tester.pump();
    expect(
        tester
            .widget<ColoredBox>(
                find.byKey(const ValueKey('halloween-ui-moon-dimming')))
            .color
            .a,
        0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'background, Reduce Motion and TickerMode freeze scene time without catch-up',
      (tester) async {
    await tester.pumpWidget(host());
    final state = await ready(tester);
    await tester.pump(const Duration(seconds: 3));
    final before = state.clock.seconds;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    expect(state.clock.seconds, before);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(state.clock.seconds, lessThan(before + 1.1));
    await tester.pumpWidget(const SizedBox.shrink());
    for (final reduce in [true, false]) {
      await tester.pumpWidget(host(reduce: reduce, ticker: reduce));
      final still = await ready(tester);
      await tester.pump(const Duration(seconds: 40));
      expect(still.clock.seconds, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(tester.takeException(), isNull);
  });
}
