import 'dart:ui' as ui;
import 'package:flutter/material.dart';
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
  static const columns = 28, rows = 32;
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
          ..filterQuality = FilterQuality.low);
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

/// The original painted face stays visible. Only the eyes briefly dim during
/// a rare flicker; no flame, procedural face, mouth pulse or body deformation.
class HalloweenPumpkin extends StatelessWidget {
  const HalloweenPumpkin(
      {super.key, this.image, this.eyeMask, this.eyeDim = 0});
  final ui.Image? image, eyeMask;
  final double eyeDim;
  @override
  Widget build(BuildContext context) => image == null
      ? Image.asset('assets/seasonal/halloween_v2/pumpkin_classic.png')
      : CustomPaint(painter: _PaintedPumpkin(image!, eyeMask!, eyeDim));
}

class _PaintedPumpkin extends CustomPainter {
  const _PaintedPumpkin(this.image, this.mask, this.dim);
  final ui.Image image, mask;
  final double dim;
  @override
  void paint(Canvas canvas, Size size) =>
      paintPaintedPumpkin(canvas, Offset.zero & size, image, mask, dim);
  @override
  bool shouldRepaint(_PaintedPumpkin old) =>
      image != old.image || dim != old.dim;
}

void paintPaintedPumpkin(
    Canvas canvas, Rect rect, ui.Image image, ui.Image eyeMask, double dim) {
  canvas.save();
  canvas.translate(rect.left, rect.top);
  canvas.scale(rect.width / 115, rect.height / 96);
  canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      const Rect.fromLTWH(0, 0, 115, 96),
      Paint()..filterQuality = FilterQuality.low);
  if (dim > 0) {
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(24, 30, 76, 25));
    canvas.drawImageRect(
        eyeMask,
        Rect.fromLTWH(
            0, 0, eyeMask.width.toDouble(), eyeMask.height.toDouble()),
        const Rect.fromLTWH(0, 0, 115, 96),
        Paint()
          ..colorFilter = ColorFilter.mode(
              Color.fromRGBO(35, 16, 8, dim), BlendMode.srcIn));
    canvas.restore();
  }
  canvas.restore();
}

void paintHalloweenSkull(
    Canvas canvas, Size size, ui.ImageShader texture, double turn, double blink,
    {ui.Image? image}) {
  if (turn == 0 && blink == 0 && image != null) {
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.low);
  } else {
    _SkullPainter(texture, turn, blink, 0).paint(canvas, size);
  }
}
