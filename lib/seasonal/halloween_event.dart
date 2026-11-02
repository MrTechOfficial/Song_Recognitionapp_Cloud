import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HalloweenEventCampaign {
  static const seenKey = 'halloween_event_2026_seen';
  static bool inWindow(DateTime now) {
    final local = now.toLocal();
    return !local.isBefore(DateTime(2026, 10, 29)) &&
        local.isBefore(DateTime(2026, 11, 3));
  }

  static Future<bool> claim(SharedPreferences prefs, DateTime now,
      {required bool standard, bool preview = false}) async {
    if (!standard) return false;
    if (preview) return true;
    if (!inWindow(now) || prefs.getBool(seenKey) == true) {
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
                        const HalloweenAnnouncementArtwork(),
                        const SizedBox(height: 20),
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
                            child: FilledButton.icon(
                                key: const ValueKey('halloween-event-preview'),
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFAF52),
                                    foregroundColor: const Color(0xFF211330),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15)),
                                onPressed: () => Navigator.pop(context, true),
                                icon: const Icon(Icons.palette_outlined,
                                    size: 20),
                                label: Text(t('halloween_event_preview')))),
                        TextButton(
                            key: const ValueKey('halloween-event-ok'),
                            style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFE6D5F1)),
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(t('halloween_event_ok'))),
                      ]))))));
}

/// The same painted scene and pumpkin used by the seasonal design. Static
/// image layers replace the former moon/bats/pumpkins CustomPainter.
class HalloweenAnnouncementArtwork extends StatelessWidget {
  const HalloweenAnnouncementArtwork({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
              height: 168,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                Transform.scale(
                    scale: 1.025,
                    child: Image.asset(
                        'assets/seasonal/halloween_v2/announcement_scene.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        filterQuality: FilterQuality.medium)),
                const DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xA6211330)]))),
                Positioned(
                    left: 12,
                    bottom: -2,
                    width: 112,
                    height: 96,
                    child: Image.asset(
                        'assets/seasonal/halloween_v2/pumpkin_classic.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium)),
              ]))));
}
