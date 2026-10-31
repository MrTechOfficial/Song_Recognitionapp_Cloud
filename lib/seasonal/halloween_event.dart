import 'dart:math' as math;
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
                                height: 132,
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

class _EventSky extends CustomPainter {
  const _EventSky();
  @override
  void paint(Canvas canvas, Size size) {
    final warm = Paint()..color = const Color(0xFFFFCB78);
    canvas.drawCircle(Offset(size.width * .53, 53), 34, warm);
    canvas.drawCircle(Offset(size.width * .53, 53), 42,
        Paint()..color = const Color(0xFFFFBA65).withValues(alpha: .08));
    for (final p in [
      const Offset(121, 37),
      const Offset(153, 60),
      const Offset(139, 73)
    ]) {
      canvas.drawCircle(p, 5, Paint()..color = const Color(0xFFE7AC63));
    }
    paintHalloweenBat(canvas, const Offset(75, 48), 49, .5, -.12);
    paintHalloweenBat(canvas, Offset(size.width - 42, 65), 35, -.4, .15);
    for (final p in [
      const Offset(28, 64),
      const Offset(194, 14),
      const Offset(221, 34),
      const Offset(101, 76)
    ]) {
      canvas.drawCircle(p, 1.5, Paint()..color = const Color(0xFFE8C3F7));
    }
    // A bowed paper bunting and little ink pumpkins make this an event card,
    // rather than just the old moon illustration. No recurring animation loop.
    final cable = Path()
      ..moveTo(6, 1)
      ..quadraticBezierTo(size.width / 2, 32, size.width - 6, 1);
    canvas.drawPath(
        cable,
        Paint()
          ..color = const Color(0xFFC6A2DC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3);
    for (var i = 0; i < 9; i++) {
      final x = 14 + i * (size.width - 28) / 8;
      final y = math.sin((i + .3) / 8.6 * math.pi) * 15;
      final flag = Path()
        ..moveTo(x - 7, y)
        ..lineTo(x + 7, y)
        ..lineTo(x + 1, y + 14)
        ..close();
      canvas.drawPath(
          flag,
          Paint()
            ..color =
                i.isEven ? const Color(0xFFF0A356) : const Color(0xFF9B76B6));
    }
    for (final (x, scale, tilt) in [(49.0, 1.0, -.10), (209.0, .78, .09)]) {
      canvas.save();
      canvas.translate(x, 108);
      canvas.rotate(tilt);
      canvas.scale(scale);
      canvas.drawOval(const Rect.fromLTWH(-23, -18, 46, 35),
          Paint()..color = const Color(0xFFEF8E3D));
      canvas.drawOval(const Rect.fromLTWH(-13, -18, 26, 35),
          Paint()..color = const Color(0xFFFFA650));
      canvas.drawPath(
          Path()
            ..moveTo(-2, -17)
            ..quadraticBezierTo(-4, -27, 5, -25),
          Paint()
            ..color = const Color(0xFF9DAD70)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 4);
      for (final eye in [-8.0, 8.0]) {
        canvas.drawPath(
            Path()
              ..moveTo(eye, -9)
              ..lineTo(eye - 4, -2)
              ..lineTo(eye + 4, -2)
              ..close(),
            warm);
      }
      canvas.drawPath(
          Path()
            ..moveTo(-11, 4)
            ..quadraticBezierTo(0, 17, 12, 4)
            ..quadraticBezierTo(0, 9, -11, 4),
          warm);
      canvas.restore();
    }
    for (final point in [
      const Offset(15, 76),
      const Offset(251, 95),
      const Offset(103, 108)
    ]) {
      canvas.drawLine(
          point + const Offset(-3, 0),
          point + const Offset(3, 0),
          Paint()
            ..color = const Color(0xFFD4B4E6)
            ..strokeWidth = 1.3);
      canvas.drawLine(
          point + const Offset(0, -3),
          point + const Offset(0, 3),
          Paint()
            ..color = const Color(0xFFD4B4E6)
            ..strokeWidth = 1.3);
    }
  }

  @override
  bool shouldRepaint(_EventSky old) => false;
}
