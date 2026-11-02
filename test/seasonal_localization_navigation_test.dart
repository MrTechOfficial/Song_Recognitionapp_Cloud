import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:song_recognition_app/main.dart';
import 'package:song_recognition_app/seasonal/halloween_scene_v2.dart';
import 'package:song_recognition_app/seasonal/seasonal_page_transition.dart';

class _Pages extends StatelessWidget {
  const _Pages();
  @override
  Widget build(BuildContext context) => Scaffold(
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(recztText(RecztLanguageScope.of(context), 'no_valid_match')),
        Text(
            RecztSeason.christmas.editionLabel(RecztLanguageScope.of(context))),
        TextButton(
            onPressed: () => Navigator.push(
                context,
                RecztPageRoute<void>(
                    allowSnapshotting: false,
                    builder: (_) => const Scaffold(
                        body: Center(child: Text('History probe'))))),
            child: const Text('Open history')),
      ])));
}

void main() {
  test('all theme labels and outcome copy exist in every canonical dictionary',
      () {
    for (final entry in localizedStrings.entries) {
      final keys = [
        'seasonal_lab',
        'seasonal_testing',
        'seasonal_preview_info',
        'seasonal_save_hint',
        'no_valid_match',
        'activity_found',
        'activity_redirecting',
        'activity_found_hint',
        'activity_no_match_hint',
        'activity_queued',
        for (final season in RecztSeason.values) season.displayNameKey,
        for (final season
            in RecztSeason.values.where((s) => s != RecztSeason.standard))
          season.editionKey,
      ];
      for (final key in keys) {
        expect(entry.value[key], isNotEmpty, reason: '${entry.key}/$key');
      }
    }
    expect(localizedStrings['pl']!['no_valid_match'], contains('Spróbuj'));
  });

  testWidgets(
      'saved language changes update edition and existing confidence status',
      (tester) async {
    await tester.pumpWidget(const MyApp(home: _Pages()));
    final dynamic root = tester.state(find.byType(MyApp));
    for (final language in localizedStrings.keys) {
      root.updatePreferences(
          language: language,
          color: Colors.purple,
          season: RecztSeason.standard);
      await tester.pump();
      expect(find.text(recztText(language, 'no_valid_match')), findsOneWidget);
      expect(
          find.text(recztText(language, 'edition_christmas')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'seasonal page changes keep one fixed scene and fade only content',
      (tester) async {
    await tester.pumpWidget(
        const MyApp(seasonalTheme: RecztSeason.halloween, home: _Pages()));
    await tester.pump(const Duration(milliseconds: 400));
    final scene = tester.state(find.byType(HalloweenLayeredSceneV2));
    final origin = tester.getTopLeft(find.byType(HalloweenLayeredSceneV2));
    final theme = Theme.of(tester.element(find.byType(_Pages)));
    expect(theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isA<SeasonalPageTransitionsBuilder>());
    await tester.tap(find.text('Open history'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final position = tester.getTopLeft(find.text('History probe'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.state(find.byType(HalloweenLayeredSceneV2)), same(scene));
      expect(tester.getTopLeft(find.byType(HalloweenLayeredSceneV2)), origin);
      expect(tester.getTopLeft(find.text('History probe')), position);
    }
    Navigator.of(tester.element(find.text('History probe'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.state(find.byType(HalloweenLayeredSceneV2)), same(scene));
    expect(find.text('Open history'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('the real Analytics page starts safely and follows the app language', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp(home: AnalyticsPage(lang: 'en')));
    await tester.pump();
    final dynamic root = tester.state(find.byType(MyApp));
    root.updatePreferences(language: 'es', color: Colors.purple, season: RecztSeason.standard);
    await tester.pump();
    expect(find.text(recztText('es', 'analytics_title')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('standard keeps its platform page transition', (tester) async {
    await tester.pumpWidget(const MyApp(home: _Pages()));
    final theme = Theme.of(tester.element(find.byType(_Pages)));
    expect(theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isNot(isA<SeasonalPageTransitionsBuilder>()));
  });
}
