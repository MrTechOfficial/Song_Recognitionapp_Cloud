import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'halloween_bats.dart';

class HalloweenEventCampaign {
  static const seenKey = 'halloween_event_2026_seen';
  static bool inWindow(DateTime now) {
    final local = now.toLocal();
    return !local.isBefore(DateTime(2026, 10, 29)) &&
        local.isBefore(DateTime(2026, 11, 3));
  }

  static Future<bool> claim(SharedPreferences prefs, DateTime now,
      {required bool standard}) async {
    if (!standard || !inWindow(now) || prefs.getBool(seenKey) == true) {
      return false;
    }
    return prefs.setBool(seenKey, true);
  }
}

class HalloweenAnnouncement extends StatelessWidget {
  const HalloweenAnnouncement(
      {super.key, required this.t, required this.language});
  final String Function(String) t;
  final String language;
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
          backgroundColor: const Color(0xFF211330),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: const BorderSide(color: Color(0xFFFFAE54), width: 1.5)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const ExcludeSemantics(
                            child: SizedBox(
                                height: 94,
                                width: 270,
                                child: CustomPaint(painter: _EventSky()))),
                        Text(t('halloween_event_title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 27,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFFC16C))),
                        const SizedBox(height: 16),
                        Text(t('halloween_event_body'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Color(0xFFF4EAFB))),
                        const SizedBox(height: 24),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                                key: const ValueKey('halloween-event-preview'),
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFAF52),
                                    foregroundColor: const Color(0xFF211330),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15)),
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(t('halloween_event_preview')))),
                        TextButton(
                            key: const ValueKey('halloween-event-ok'),
                            style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFE6D5F1)),
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(t('halloween_event_ok'))),
                      ]))))));
}

class _EventSky extends CustomPainter {
  const _EventSky();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(Offset(size.width * .53, 40), 32,
        Paint()..color = const Color(0xFFFFCB78));
    for (final p in [
      const Offset(121, 24),
      const Offset(153, 47),
      const Offset(139, 60)
    ]) {
      canvas.drawCircle(p, 5, Paint()..color = const Color(0xFFE7AC63));
    }
    paintHalloweenBat(canvas, const Offset(68, 35), 61, .5, -.12);
    paintHalloweenBat(canvas, Offset(size.width - 44, 60), 42, -.4, .15);
    for (final p in [
      const Offset(28, 64),
      const Offset(194, 14),
      const Offset(221, 34),
      const Offset(101, 76)
    ]) {
      canvas.drawCircle(p, 1.5, Paint()..color = const Color(0xFFE8C3F7));
    }
  }

  @override
  bool shouldRepaint(_EventSky old) => false;
}
