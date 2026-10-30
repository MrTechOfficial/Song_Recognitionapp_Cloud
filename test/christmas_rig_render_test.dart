import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/seasonal/christmas_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final images = <String, ui.Image>{};
  late ui.ImageShader scarf;
  setUpAll(() async {
    for (final name in [
      'body_rig',
      'skate_back',
      'skate_front',
      'scarf_tail'
    ]) {
      final data =
          await rootBundle.load('assets/seasonal/christmas/snowman_$name.png');
      final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      try {
        images[name] = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    }
    scarf = ui.ImageShader(images['scarf_tail']!, TileMode.clamp,
        TileMode.clamp, Matrix4.identity().storage);
  });
  tearDownAll(() {
    scarf.dispose();
    for (final im in images.values) {
      im.dispose();
    }
  });
  Future<ByteData> render(
      WidgetTester tester, double stride, double flutter) async {
    final key = GlobalKey();
    final pose = SnowmanSkatingPose(
        feet: const Offset(0, 0),
        width: 200,
        lean: 0,
        facing: 1,
        strideBlend: 0,
        lift: 0,
        depth: 1,
        speed: 1,
        stridePhase: stride,
        scarfPhase: flutter);
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: RepaintBoundary(
                key: key,
                child: SizedBox(
                    width: 400,
                    height: 400,
                    child: ColoredBox(
                        color: const Color(0xFF1E2E4E),
                        child: ChristmasSkatingFigure(
                            pose: pose, images: images, scarf: scarf)))))));
    await tester.pump();
    return (await tester.runAsync(() async {
      final im = await (key.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage();
      try {
        return (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      } finally {
        im.dispose();
      }
    }))!;
  }

  testWidgets(
      'separate skates move in alternate pushes with a small decoded budget',
      (tester) async {
    expect(images.values.every((im) => im.width == 400 && im.height == 400),
        isTrue);
    final left = await render(tester, 1.57, 0),
        right = await render(tester, 4.71, 0);
    var changed = 0;
    for (var y = 265; y < 395; y++) {
      for (var x = 35; x < 350; x++) {
        final i = (y * 400 + x) * 4;
        if (left.getUint32(i) != right.getUint32(i)) {
          changed++;
        }
      }
    }
    expect(changed, greaterThan(1200));
  });
  testWidgets(
      'the scarf moves independently while the upper body stays painted',
      (tester) async {
    final a = await render(tester, 0, 0), b = await render(tester, 0, 2);
    var tailChanged = 0, headChanged = 0;
    for (var y = 0; y < 250; y++) {
      for (var x = 0; x < 400; x++) {
        final i = (y * 400 + x) * 4;
        if (a.getUint32(i) == b.getUint32(i)) {
          continue;
        }
        if (x < 180 && y > 90 && y < 185) {
          tailChanged++;
        }
        if (x > 192 && x < 300 && y > 20 && y < 150) {
          headChanged++;
        }
      }
    }
    expect(tailChanged, greaterThan(150));
    expect(headChanged, 0);
  });
}
