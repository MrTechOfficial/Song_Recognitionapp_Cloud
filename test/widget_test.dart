import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/main.dart' show MyApp, RecztSeason;
import 'package:song_recognition_app/seasonal/scene_frame_clock.dart';

class _StickyHome extends StatefulWidget {
  const _StickyHome();
  @override
  State<_StickyHome> createState() => _StickyHomeState();
}

class _StickyHomeState extends State<_StickyHome> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(
          child: TextButton(
              onPressed: () => setState(() => taps++),
              child: Text('Count $taps'))));
}

void main() {
  testWidgets(
      'repeated settings changes keep one app and at most one seasonal scene',
      (tester) async {
    await tester.pumpWidget(const MyApp(home: _StickyHome()));
    final original = tester.state(find.byType(_StickyHome));
    await tester.tap(find.text('Count 0'));
    await tester.pump();
    final dynamic root = tester.state(find.byType(MyApp));
    for (var i = 0; i < 12; i++) {
      final season = [
        RecztSeason.halloween,
        RecztSeason.christmas,
        RecztSeason.standard
      ][i % 3];
      root.updatePreferences(
          language: i.isEven ? 'en' : 'es',
          color: Colors.purple,
          season: season);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MyApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(tester.state(find.byType(_StickyHome)), same(original));
      expect(find.text('Count 1'), findsOneWidget);
      expect(SceneEnergyPolicy.instance.activeScenes,
          season == RecztSeason.standard ? 0 : 1);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
    expect(SceneEnergyPolicy.instance.activeScenes, 0);
    expect(tester.takeException(), isNull);
  });
}
