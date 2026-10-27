import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'halloween_carvings.dart';
import 'halloween_motion.dart';

/// One painted texture bends over a rounded skull surface. There are no
/// dissolving perspective PNGs; eye vertices physically close the sockets.
class HalloweenPaintedHead extends StatelessWidget {
  const HalloweenPaintedHead(
      {super.key,
      required this.turn,
      required this.blink,
      this.nod = 0,
      this.texture});
  final double turn, blink, nod;
  final ui.ImageShader? texture;
  @override
  Widget build(BuildContext context) => texture == null
      ? Image.asset('assets/seasonal/halloween_v2/skeleton_skull_rig.png',
          fit: BoxFit.fill)
      : CustomPaint(painter: _SkullPainter(texture!, turn, blink, nod));
}

class _SkullPainter extends CustomPainter {
  const _SkullPainter(this.texture, this.turn, this.blink, this.nod);
  final ui.ImageShader texture;
  final double turn, blink, nod;
  static const columns = 42, rows = 44;
  static final coordinates = <Offset>[
    for (var row = 0; row <= rows; row++)
      for (var col = 0; col <= columns; col++)
        Offset(84 * col / columns, 88 * row / rows)
  ];
  static final indices = <int>[
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < columns; col++) ...[
        row * (columns + 1) + col,
        row * (columns + 1) + col + 1,
        (row + 1) * (columns + 1) + col,
        row * (columns + 1) + col + 1,
        (row + 1) * (columns + 1) + col + 1,
        (row + 1) * (columns + 1) + col,
      ]
  ];
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 84, size.height / 88);
    final vertices = ui.Vertices(
        ui.VertexMode.triangles,
        [
          for (final p in coordinates)
            HalloweenMotion.skullVertex(p, turn, blink, nod: nod)
        ],
        textureCoordinates: coordinates,
        indices: indices);
    canvas.drawVertices(
        vertices,
        BlendMode.srcOver,
        Paint()
          ..shader = texture
          ..filterQuality = FilterQuality.high);
    vertices.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkullPainter old) =>
      texture != old.texture ||
      turn != old.turn ||
      blink != old.blink ||
      nod != old.nod;
}

class HalloweenPumpkin extends StatelessWidget {
  const HalloweenPumpkin(
      {super.key,
      required this.shell,
      required this.face,
      required this.expression,
      required this.blink,
      required this.candle,
      required this.breath});
  final ui.Image? shell;
  final int face;
  final double expression, blink, candle, breath;
  @override
  Widget build(BuildContext context) => shell == null
      ? Image.asset('assets/seasonal/halloween_v2/pumpkin_classic.png')
      : CustomPaint(
          painter:
              _PumpkinPainter(shell!, face, expression, blink, candle, breath));
}

class _PumpkinPainter extends CustomPainter {
  const _PumpkinPainter(this.shell, this.face, this.expression, this.blink,
      this.candle, this.breath);
  final ui.Image shell;
  final int face;
  final double expression, blink, candle, breath;

  Path _shape(List<Offset> normal, List<Offset> surprised,
      {bool eye = false, bool right = false}) {
    final points = <Offset>[];
    final center =
        normal.map((p) => p.dy).reduce((a, b) => a + b) / normal.length;
    for (var i = 0; i < normal.length; i++) {
      final a = normal[i];
      final target = face == 1
          ? surprised[i]
          : Offset(a.dx,
              eye ? center + (a.dy - center) * .55 : 73 + (a.dy - 73) * .16);
      var point = Offset.lerp(a, target, expression)!;
      if (eye) {
        final lid = right ? math.pow(blink, 1.25).toDouble() : blink;
        point =
            Offset(point.dx, center + (point.dy - center) * (1 - .94 * lid));
      }
      points.add(point);
    }
    return Path()..addPolygon(points, true);
  }

  void _carving(Canvas canvas, Path path) {
    // Warm spill follows the aperture, while the dark cut edge remains crisp.
    canvas.drawPath(
        path,
        Paint()
          ..color = Color.fromRGBO(255, 145, 33, .17 + candle * .32)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 + candle * 1.9));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.7
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF54220C));
    final top =
        Color.lerp(const Color(0xFFA3430B), const Color(0xFFFFBB3D), candle)!;
    final core =
        Color.lerp(const Color(0xFFEC7B16), const Color(0xFFFFF0AC), candle)!;
    canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(const Offset(58, 30),
              const Offset(58, 81), [top, core, top], [0, .66, 1]));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65
          ..color = Color.fromRGBO(255, 194, 75, .30 + candle * .45));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 115, size.height / 96);
    // Tiny anticipation/breathing stretches the illustration from its planted
    // base; the pumpkin never bobs away from the ground.
    canvas.translate(57.5, 96);
    canvas.scale(1 + breath * .009, 1 - breath * .013);
    canvas.translate(-57.5, -96);
    canvas.drawImageRect(
        shell,
        Rect.fromLTWH(0, 0, shell.width.toDouble(), shell.height.toDouble()),
        const Rect.fromLTWH(0, 0, 115, 96),
        Paint()..filterQuality = FilterQuality.high);
    _carving(
        canvas,
        _shape(HalloweenCarvings.classicLeftEye,
            HalloweenCarvings.surprisedLeftEye,
            eye: true));
    _carving(
        canvas,
        _shape(HalloweenCarvings.classicRightEye,
            HalloweenCarvings.surprisedRightEye,
            eye: true, right: true));
    _carving(
        canvas,
        Path()
          ..moveTo(61, 55)
          ..lineTo(56, 63)
          ..lineTo(65, 63)
          ..close());
    _carving(
        canvas,
        _shape(
            HalloweenCarvings.classicMouth, HalloweenCarvings.surprisedMouth));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PumpkinPainter old) =>
      shell != old.shell ||
      face != old.face ||
      expression != old.expression ||
      blink != old.blink ||
      candle != old.candle ||
      breath != old.breath;
}
