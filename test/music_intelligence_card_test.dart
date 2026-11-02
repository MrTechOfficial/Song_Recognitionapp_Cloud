import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:song_recognition_app/main.dart' show localizedStrings;
import 'package:song_recognition_app/seasonal/music_intelligence_card.dart';

void main() {
  testWidgets(
      'empty and populated summaries stay one fixed height in every language',
      (tester) async {
    for (final entry in localizedStrings.entries) {
      for (final count in [0, 99]) {
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Directionality(
                    textDirection: entry.key == 'ar'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: Center(
                        child: SizedBox(
                            width: 270,
                            child: CompactMusicIntelligence(
                                t: (key) => entry.value[key]!,
                                count: count,
                                bpm: 126,
                                musicalKey: 'Am',
                                instrument: 'very long instrument description',
                                pace: 78,
                                loudness: -10.6,
                                onSamples: () {})))))));
        expect(tester.getSize(find.byType(CompactMusicIntelligence)).height,
            CompactMusicIntelligence.height);
        expect(tester.takeException(), isNull, reason: entry.key);
      }
    }
  });
  testWidgets(
      'examples are labeled samples and leave analytics preferences intact',
      (tester) async {
    SharedPreferences.setMockInitialValues({'analytics_mu_count': 7});
    final prefs = await SharedPreferences.getInstance();
    final snapshot = {for (final key in prefs.getKeys()) key: prefs.get(key)};
    String t(String key) => localizedStrings['en']![key]!;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => showMusicIntelligenceSamples(context, t),
                child: const Text('Samples')))));
    await tester.tap(find.text('Samples'));
    await tester.pumpAndSettle();
    expect(find.text(t('mi_sample_note')), findsOneWidget);
    expect(find.byType(CompactMusicIntelligence), findsNWidgets(3));
    expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, snapshot);
    expect(tester.takeException(), isNull);
  });
}
