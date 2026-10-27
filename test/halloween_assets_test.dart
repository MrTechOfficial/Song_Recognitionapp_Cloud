import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:song_recognition_app/seasonal/halloween_motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const root = 'assets/seasonal/halloween_v2';
  Future<(ui.Image, ByteData)> decode(String name) async {
    final bytes = await rootBundle.load('$root/$name.png');
    final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
    try {
      final image = (await codec.getNextFrame()).image;
      return (
        image,
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
      );
    } finally {
      codec.dispose();
    }
  }

  test('resting tree composite reproduces the original illustration exactly',
      () async {
    final original = await decode('background'),
        clean = await decode('background_tree_clear'),
        tree = await decode('tree_isolated');
    try {
      expect(original.$1.width, 406);
      expect(original.$1.height, 696);
      expect(clean.$1.width, 406);
      expect(tree.$1.height, 696);
      var changed = 0, transparent = 0;
      for (var i = 0; i < original.$2.lengthInBytes; i += 4) {
        final alpha = tree.$2.getUint8(i + 3);
        expect(alpha == 0 || alpha == 255, isTrue);
        if (alpha == 0) transparent++;
        final source = alpha == 255 ? tree.$2 : clean.$2;
        for (var c = 0; c < 3; c++) {
          if (source.getUint8(i + c) != original.$2.getUint8(i + c)) changed++;
        }
      }
      expect(changed, 0);
      expect(transparent, greaterThan(406 * 696 * .75));
      expect(tree.$2.getUint8((96 * 406 + 318) * 4 + 3), 0,
          reason: 'The moon is not part of the swaying tree');
    } finally {
      original.$1.dispose();
      clean.$1.dispose();
      tree.$1.dispose();
    }
  });

  test('blink changes only painted eye regions, never the head silhouette',
      () async {
    final front = await decode('skeleton_head_front'),
        eyes = await decode('skeleton_eyes_closed_overlay');
    try {
      expect(eyes.$1.width, front.$1.width);
      expect(eyes.$1.height, front.$1.height);
      var painted = 0;
      for (var y = 0; y < eyes.$1.height; y++) {
        for (var x = 0; x < eyes.$1.width; x++) {
          final i = (y * eyes.$1.width + x) * 4;
          if (x >= 42 && x <= 52 && y >= 52 && y <= 66) {
            expect(eyes.$2.getUint8(i + 3), 0,
                reason: 'Blink must not alter the nose');
          }
          if (eyes.$2.getUint8(i + 3) == 0) continue;
          painted++;
          expect(front.$2.getUint8(i + 3), 255);
          expect(x, inInclusiveRange(20, 70));
          expect(y, inInclusiveRange(32, 61));
        }
      }
      expect(painted, greaterThan(300));
      expect(painted, lessThan(1300));
    } finally {
      front.$1.dispose();
      eyes.$1.dispose();
    }
  });

  test('the broad painted bank visibly covers and releases the moon smoothly',
      () async {
    final cloud = await decode('moon_cloud_bank');
    try {
      final data = cloud.$2;
      final mask = HalloweenMoonOcclusion.fromRgba(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          cloud.$1.width,
          cloud.$1.height);
      const visible = ui.Rect.fromLTWH(42, 0, 322, 696);
      final levels = List.generate(1001,
          (i) => mask.dimming(HalloweenMotion.cloudRect(i / 1000, visible)));
      expect(levels.first, 0);
      expect(levels.last, 0);
      expect(levels.reduce(math.max), inInclusiveRange(.22, .30));
      for (var i = 1; i < levels.length; i++) {
        expect((levels[i] - levels[i - 1]).abs(), lessThan(.012));
      }
    } finally {
      cloud.$1.dispose();
    }
  });

  test(
      'every named scene asset and face-specific light mask resolves and decodes',
      () async {
    for (final name in [
      'skeleton_head_front',
      'skeleton_head_left_1',
      'skeleton_head_left_2',
      'skeleton_head_right_1',
      'skeleton_head_right_2',
      'bat_body',
      'bat_left_wing',
      'bat_right_wing',
      'leaf_01',
      'leaf_02',
      'fog_far',
      'fog_near',
      'moon_cloud',
      'moon_cloud_clean',
      'pumpkin_classic',
      'pumpkin_surprised',
      'pumpkin_closed',
      'pumpkin_classic_light_mask',
      'pumpkin_surprised_light_mask',
      'pumpkin_closed_light_mask',
      'skeleton_skull_rig',
      'pumpkin_shell',
      'fog_far_clean',
      'fog_near_clean',
      'moon_cloud_bank'
    ]) {
      final image = await decode(name);
      try {
        expect(image.$1.width, greaterThan(0));
        expect(image.$1.height, greaterThan(0));
        if (name.startsWith('pumpkin_')) {
          expect(image.$1.width, 115);
          expect(image.$1.height, 96);
        }
      } finally {
        image.$1.dispose();
      }
    }
  });
}
