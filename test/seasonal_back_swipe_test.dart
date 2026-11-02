import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/main.dart';
import 'package:song_recognition_app/seasonal/halloween_scene_v2.dart';
import 'package:song_recognition_app/seasonal/scene_frame_clock.dart';
import 'package:song_recognition_app/seasonal/seasonal_page_transition.dart';

class _Menu extends StatelessWidget {
  const _Menu();
  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(
          child: TextButton(
              onPressed: () => Navigator.push(
                  context,
                  RecztPageRoute<void>(
                      allowSnapshotting: false,
                      builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Details')),
                          body: ListView(children: [
                            for (var i = 0; i < 50; i++)
                              SizedBox(height: 64, child: Text('Row $i'))
                          ])))),
              child: const Text('Open details'))));
}

void main() {
  Future<void> open(WidgetTester tester,
      {String language = 'en',
      RecztSeason season = RecztSeason.halloween}) async {
    await tester.pumpWidget(MyApp(
        currentLang: language, seasonalTheme: season, home: const _Menu()));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Open details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(SceneEnergyPolicy.instance.activeScenes, 0);
    expect(tester.takeException(), isNull);
  }

  testWidgets('full-page right swipe pops over the same stationary scene',
      (tester) async {
    await open(tester);
    final scene = tester.state(find.byType(HalloweenLayeredSceneV2));
    final nav = Navigator.of(tester.element(find.text('Details')));
    await tester.flingFrom(const Offset(200, 250), const Offset(480, 0), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Open details'), findsOneWidget);
    expect(find.text('Details'), findsNothing);
    expect(tester.state(find.byType(HalloweenLayeredSceneV2)), same(scene));
    expect(nav.userGestureInProgress, false);
    await close(tester);
  });

  testWidgets(
      'a short cancelled swipe restores the page and can be followed by a completed swipe',
      (tester) async {
    await open(tester);
    final nav = Navigator.of(tester.element(find.text('Details')));
    final gesture = await tester.startGesture(const Offset(180, 250));
    await gesture.moveBy(const Offset(90, 0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(nav.userGestureInProgress, true);
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Details'), findsOneWidget);
    expect(nav.userGestureInProgress, false);
    await tester.flingFrom(const Offset(200, 250), const Offset(480, 0), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Details'), findsNothing);
    await close(tester);
  });

  testWidgets(
      'vertical scrolling and the opposite horizontal direction do not pop the page',
      (tester) async {
    await open(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Details'), findsOneWidget);
    expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        greaterThan(200));
    await tester.flingFrom(const Offset(600, 250), const Offset(-450, 0), 1200);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Details'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
      'RTL mirrors the back direction and the first route cannot be swiped away',
      (tester) async {
    await open(tester, language: 'ar');
    await tester.flingFrom(const Offset(600, 250), const Offset(-480, 0), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Details'), findsNothing);
    await tester.flingFrom(const Offset(600, 250), const Offset(-480, 0), 1200);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Open details'), findsOneWidget);
    await close(tester);
  });

  testWidgets('iOS Standard retains its native edge-swipe back gesture',
      (tester) async {
    await open(tester, season: RecztSeason.standard);
    await tester.flingFrom(const Offset(2, 250), const Offset(600, 0), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Details'), findsNothing);
    await close(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
