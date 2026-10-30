import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:song_recognition_app/seasonal/halloween_event.dart';
import 'package:song_recognition_app/main.dart' show localizedStrings;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'event uses local dates, includes Nov 2, and is claimed once on Standard',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(HalloweenEventCampaign.inWindow(DateTime(2026, 10, 28, 23, 59)),
        isFalse);
    expect(HalloweenEventCampaign.inWindow(DateTime(2026, 10, 29)), isTrue);
    expect(HalloweenEventCampaign.inWindow(DateTime(2026, 11, 2, 23, 59, 59)),
        isTrue);
    expect(HalloweenEventCampaign.inWindow(DateTime(2026, 11, 3)), isFalse);
    expect(
        await HalloweenEventCampaign.claim(prefs, DateTime(2026, 10, 30),
            standard: false),
        isFalse);
    expect(
        await HalloweenEventCampaign.claim(prefs, DateTime(2026, 10, 28),
            standard: true),
        isFalse);
    expect(prefs.getBool(HalloweenEventCampaign.seenKey), isNull);
    expect(
        await HalloweenEventCampaign.claim(prefs, DateTime(2026, 10, 30),
            standard: true),
        isTrue);
    expect(
        await HalloweenEventCampaign.claim(prefs, DateTime(2026, 10, 30),
            standard: true),
        isFalse);
    expect(
        await HalloweenEventCampaign.claim(prefs, DateTime(2027, 10, 30),
            standard: true),
        isFalse);
  });
  test('all fifteen dictionaries contain every added event string', () {
    expect(localizedStrings.length, 15);
    for (final language in localizedStrings.entries) {
      for (final key in ['title', 'body', 'preview', 'ok']) {
        expect(language.value['halloween_event_$key'], isNotNull,
            reason: language.key);
        expect(language.value['halloween_event_$key'], isNotEmpty);
      }
    }
  });
  testWidgets(
      'localized popup fits a small phone, supports RTL, and returns the chosen action',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final language in ['en', 'ar', 'de']) {
      for (final preview in [true, false]) {
        bool? result;
        await tester.pumpWidget(MaterialApp(
            home: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                          context: context,
                          builder: (_) => HalloweenAnnouncement(
                              language: language,
                              t: (key) => localizedStrings[language]![key]!));
                    },
                    child: const Text('Open')))));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final key = ValueKey(
            preview ? 'halloween-event-preview' : 'halloween-event-ok');
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(result, preview);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
