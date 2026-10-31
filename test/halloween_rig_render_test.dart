import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/seasonal/halloween_characters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image shell, skull, eyeMask;
  late ui.ImageShader skullTexture;
  late HalloweenPumpkinRig pumpkinRig;
  final morphFaces = <ui.Image>[], morphMasks = <ui.Image>[];
  Future<ui.Image> load(String name) async {
    final data =
        await rootBundle.load('assets/seasonal/halloween_v2/$name.png');
    final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  setUpAll(() async {
    shell = await load('pumpkin_classic');
    eyeMask = await load('pumpkin_classic_eyes_mask');
    skull = await load('skeleton_skull_rig');
    skullTexture = ui.ImageShader(
        skull, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage);
    for (final name in ['classic', 'surprised', 'sly']) {
      morphFaces.add(await load('pumpkin_$name'));
      morphMasks.add(await load('pumpkin_${name}_eyes_mask'));
    }
    pumpkinRig = HalloweenPumpkinRig(morphFaces, morphMasks);
  });
  tearDownAll(() {
    skullTexture.dispose();
    skull.dispose();
    shell.dispose();
    eyeMask.dispose();
    pumpkinRig.dispose();
    for (final image in [...morphFaces, ...morphMasks]) {
      image.dispose();
    }
  });

  Future<ByteData> render(WidgetTester tester, Widget child, Size size) async {
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: RepaintBoundary(
                key: key,
                child: SizedBox.fromSize(
                    size: size,
                    child: ColoredBox(
                        color: const Color(0xFF292330), child: child))))));
    await tester.pump();
    return (await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      try {
        return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      } finally {
        image.dispose();
      }
    }))!;
  }

  Widget pumpkin(double dim) =>
      HalloweenPumpkin(image: shell, eyeMask: eyeMask, eyeDim: dim);
  testWidgets(
      'occasional flicker affects only the eyes; mouth and painted body stay identical',
      (tester) async {
    final normal = await render(tester, pumpkin(0), const Size(115, 96));
    final dim = await render(tester, pumpkin(.27), const Size(115, 96));
    var changedEyes = 0, changedElsewhere = 0;
    for (var y = 0; y < 192; y++) {
      for (var x = 0; x < 230; x++) {
        final i = (y * 230 + x) * 4;
        if (normal.getUint32(i) == dim.getUint32(i)) {
          continue;
        }
        if (y >= 60 && y < 110 && x >= 48 && x < 200) {
          changedEyes++;
        } else {
          changedElsewhere++;
        }
      }
    }
    expect(changedEyes, greaterThan(100));
    expect(changedElsewhere, 0);
    final again = await render(tester, pumpkin(0), const Size(115, 96));
    expect(again.buffer.asUint8List(), normal.buffer.asUint8List());
  });

  testWidgets('blink physically closes the painted skull sockets',
      (tester) async {
    final open = await render(
        tester,
        HalloweenPaintedHead(texture: skullTexture, turn: 0, blink: 0),
        const Size(84, 88));
    final closed = await render(
        tester,
        HalloweenPaintedHead(texture: skullTexture, turn: 0, blink: 1),
        const Size(84, 88));
    var openDark = 0, closedDark = 0;
    for (var y = 70; y < 112; y++) {
      for (var x = 44; x < 132; x++) {
        final i = (y * 168 + x) * 4;
        if (open.getUint8(i + 1) < 45) openDark++;
        if (closed.getUint8(i + 1) < 45) closedDark++;
      }
    }
    expect(openDark, greaterThan(700));
    expect(closedDark, lessThan(openDark * .45));
  });

  testWidgets(
      'painted face morph moves the carving instead of dissolving two faces',
      (tester) async {
    for (final target in [1, 2]) {
      Widget pose(double blend) =>
          CustomPaint(painter: _MorphPainter(pumpkinRig, target, blend));
      final start = await render(tester, pose(0), const Size(115, 96));
      final end = await render(tester, pose(1), const Size(115, 96));
      final middle = await render(tester, pose(.5), const Size(115, 96));
      var movedPixels = 0;
      for (var y = 60; y < 172; y++) {
        for (var x = 48; x < 204; x++) {
          final i = (y * 230 + x) * 4;
          var difference = 0.0;
          for (var c = 0; c < 3; c++) {
            difference += (middle.getUint8(i + c) -
                    (start.getUint8(i + c) + end.getUint8(i + c)) / 2)
                .abs();
          }
          if (difference > 35) movedPixels++;
        }
      }
      expect(movedPixels, greaterThan(200),
          reason: 'A dissolve leaves stationary apertures');
      for (final (phase, endpoint) in [(0.00001, start), (.99999, end)]) {
        final near = await render(tester, pose(phase), const Size(115, 96));
        var total = 0.0;
        for (var i = 0; i < near.lengthInBytes; i++) {
          total += (near.getUint8(i) - endpoint.getUint8(i)).abs();
        }
        expect(total / near.lengthInBytes, lessThan(1.5),
            reason:
                'Morph endpoints must join the original painted faces smoothly');
      }
    }
  });
}

class _MorphPainter extends CustomPainter {
  const _MorphPainter(this.rig, this.target, this.blend);
  final HalloweenPumpkinRig rig;
  final int target;
  final double blend;
  @override
  void paint(Canvas canvas, Size size) =>
      rig.paint(canvas, Offset.zero & size, from: 0, to: target, blend: blend);
  @override
  bool shouldRepaint(_MorphPainter old) =>
      target != old.target || blend != old.blend;
}
