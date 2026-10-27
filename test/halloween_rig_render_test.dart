import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/seasonal/halloween_characters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image shell, skull;
  late ui.ImageShader skullTexture;
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
    shell = await load('pumpkin_shell');
    skull = await load('skeleton_skull_rig');
    skullTexture = ui.ImageShader(
        skull, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage);
  });
  tearDownAll(() {
    skullTexture.dispose();
    skull.dispose();
    shell.dispose();
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

  Widget pumpkin({double expression = 0, int face = 0, double candle = .7}) =>
      HalloweenPumpkin(
          shell: shell,
          face: face,
          expression: expression,
          blink: 0,
          candle: candle,
          breath: 0);

  testWidgets(
      'candle intensity visibly changes carved interiors, not the whole pumpkin',
      (tester) async {
    final low = await render(tester, pumpkin(candle: .16), const Size(115, 96));
    final high = await render(tester, pumpkin(candle: 1), const Size(115, 96));
    var eyeGain = 0.0, count = 0, skinChanged = 0;
    for (var y = 0; y < 192; y++) {
      for (var x = 0; x < 230; x++) {
        final i = (y * 230 + x) * 4;
        if (x >= 72 && x < 86 && y >= 88 && y < 98) {
          eyeGain += high.getUint8(i + 1) - low.getUint8(i + 1);
          count++;
        }
        if (x < 34 &&
            y > 60 &&
            y < 170 &&
            high.getUint32(i) != low.getUint32(i)) {
          skinChanged++;
        }
      }
    }
    expect(eyeGain / count, greaterThan(45));
    expect(skinChanged, lessThan(12));
  });

  testWidgets(
      'the expression passes through moving carving shapes, rather than a face dissolve',
      (tester) async {
    final a = await render(tester, pumpkin(face: 1), const Size(115, 96));
    final b = await render(
        tester, pumpkin(face: 1, expression: 1), const Size(115, 96));
    final mid = await render(
        tester, pumpkin(face: 1, expression: .5), const Size(115, 96));
    final near = await render(
        tester, pumpkin(face: 1, expression: .501), const Size(115, 96));
    var differsFromDissolve = 0, adjacentDifference = 0.0;
    for (var i = 0; i < a.lengthInBytes; i += 4) {
      if ((mid.getUint8(i + 1) - (a.getUint8(i + 1) + b.getUint8(i + 1)) / 2)
              .abs() >
          25) {
        differsFromDissolve++;
      }
      adjacentDifference += (mid.getUint8(i + 1) - near.getUint8(i + 1)).abs();
    }
    expect(differsFromDissolve, greaterThan(300));
    expect(adjacentDifference / (a.lengthInBytes / 4), lessThan(1));
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
}
