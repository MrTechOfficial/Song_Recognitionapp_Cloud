import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'halloween_motion.dart';
import 'halloween_carvings.dart';

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
          fit: BoxFit.fill, filterQuality: FilterQuality.high)
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
      Paint()..filterQuality = FilterQuality.high);
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
        Paint()..filterQuality = FilterQuality.high);
  } else {
    _SkullPainter(texture, turn, blink, 0).paint(canvas, size);
  }
}

/// The painted apertures physically change shape: both images are warped onto
/// the same moving eye/mouth landmarks before their paint colors blend. This
/// avoids a dissolve between two stationary faces, duplicate eyes or a flame.
/// Shaders are created once per scene; only three small radial patches move.
class HalloweenPumpkinRig {
  HalloweenPumpkinRig(this.faces, this.eyeMasks)
      : textures = [for (final image in faces) _texture(image)],
        maskTextures = [for (final image in eyeMasks) _texture(image)];
  final List<ui.Image> faces, eyeMasks;
  final List<ui.ImageShader> textures, maskTextures;
  static ui.ImageShader _texture(ui.Image image) => ui.ImageShader(
      image, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage);
  void dispose() {
    for (final shader in [...textures, ...maskTextures]) {
      shader.dispose();
    }
  }

  void paint(Canvas canvas, Rect rect,
      {required int from,
      required int to,
      required double blend,
      double dim = 0}) {
    if (from == to || blend >= 1) {
      paintPaintedPumpkin(canvas, rect, faces[to], eyeMasks[to], dim);
      return;
    }
    if (blend <= 0) {
      paintPaintedPumpkin(canvas, rect, faces[from], eyeMasks[from], dim);
      return;
    }
    final source = HalloweenCarvings.landmarks[from];
    final target = HalloweenCarvings.landmarks[to];
    final positions = [
      for (var i = 0; i < source.length; i++)
        Offset.lerp(source[i], target[i], blend)!
    ];
    final indices = HalloweenCarvings.indices;
    final first = ui.Vertices(ui.VertexMode.triangles, positions,
        textureCoordinates: source, indices: indices);
    final second = ui.Vertices(ui.VertexMode.triangles, positions,
        textureCoordinates: target, indices: indices);
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / 115, rect.height / 96);
    final bounds = const Rect.fromLTWH(0, 0, 115, 96);
    for (final (image, opacity) in [(faces[from], 1.0), (faces[to], blend)]) {
      canvas.drawImageRect(
          image,
          bounds,
          bounds,
          Paint()
            ..filterQuality = FilterQuality.high
            ..color = Color.fromRGBO(255, 255, 255, opacity));
    }
    canvas.clipRect(const Rect.fromLTRB(24, 27, 102, 86));
    canvas.drawVertices(
        first,
        BlendMode.srcOver,
        Paint()
          ..shader = textures[from]
          ..filterQuality = FilterQuality.high);
    canvas.drawVertices(
        second,
        BlendMode.srcOver,
        Paint()
          ..shader = textures[to]
          ..filterQuality = FilterQuality.high
          ..color = Color.fromRGBO(255, 255, 255, blend));
    if (dim > 0) {
      canvas.clipRect(const Rect.fromLTWH(24, 30, 76, 25));
      for (final (mesh, shader, opacity) in [
        (first, maskTextures[from], 1 - blend),
        (second, maskTextures[to], blend)
      ]) {
        canvas.drawVertices(
            mesh,
            BlendMode.srcOver,
            Paint()
              ..shader = shader
              ..filterQuality = FilterQuality.high
              ..colorFilter = ColorFilter.mode(
                  Color.fromRGBO(35, 16, 8, dim * opacity), BlendMode.srcIn));
      }
    }
    canvas.restore();
    first.dispose();
    second.dispose();
  }
}
