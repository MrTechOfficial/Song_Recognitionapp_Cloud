import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'halloween_motion.dart';
import 'halloween_timeline.dart';
import 'halloween_characters.dart';
import 'halloween_bats.dart';
import 'scene_frame_clock.dart';
import 'seasonal_scene_support.dart';
export 'halloween_characters.dart' show HalloweenPaintedHead, HalloweenPumpkin;

class HalloweenSceneHost extends StatefulWidget {
  const HalloweenSceneHost({super.key, required this.child});
  final Widget child;
  @override
  State<HalloweenSceneHost> createState() => _HalloweenSceneHostState();
}

class _HalloweenSceneHostState extends State<HalloweenSceneHost> {
  final _shade = ValueNotifier<double>(0);
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Color(0xFF231339)),
        HalloweenLayeredSceneV2(moonShade: _shade),
        RepaintBoundary(child: widget.child),
        IgnorePointer(
            child: ExcludeSemantics(
                child: ValueListenableBuilder<double>(
                    valueListenable: _shade,
                    builder: (context, value, _) => ColoredBox(
                        key: const ValueKey('halloween-ui-moon-dimming'),
                        color: const Color(0xFF080615)
                            .withValues(alpha: value))))),
      ]);
  @override
  void dispose() {
    _shade.dispose();
    super.dispose();
  }
}

/// One paced decoration clock, one retained painter, no per-frame widget trees.
class HalloweenLayeredSceneV2 extends StatefulWidget {
  const HalloweenLayeredSceneV2({super.key, this.randomSeed, this.moonShade});
  final int? randomSeed;
  final ValueNotifier<double>? moonShade;
  @override
  State<HalloweenLayeredSceneV2> createState() =>
      _HalloweenLayeredSceneV2State();
}

class _HalloweenLayeredSceneV2State
    extends SeasonalSceneState<HalloweenLayeredSceneV2> {
  static const root = 'assets/seasonal/halloween_v2';
  late final SceneFrameClock clock;
  late final HalloweenTimeline timeline;
  final images = <String, ui.Image>{};
  ui.ImageShader? treeTexture, skullTexture;
  HalloweenPumpkinRig? pumpkin;
  HalloweenMoonOcclusion? moon;
  Rect? _visible;
  List<double> _shadeCurve = [];
  bool _loading = false, _still = false;
  int _lastShadeFrame = -1;
  int get completedTreeSways => timeline.sways.completed;
  int get releasedLeaves => timeline.sways.leavesReleased;
  int get launchedBats => timeline.launchedBats;
  int get frameCount => clock.frames;
  bool get layersReady => images.isNotEmpty && skullTexture != null;
  @override
  void initState() {
    super.initState();
    timeline = HalloweenTimeline(seed: widget.randomSeed);
    clock = SceneFrameClock()..addListener(_frame);
  }

  void _frame() {
    timeline.advance(clock.seconds);
    if (clock.policy.fps == 0) {
      _publishShade();
      return;
    }
    // Light changes slowly. A 6 fps lookup replaces six alpha-mask scans on
    // every display frame; the illustration itself remains 24 fps.
    if (clock.frames - _lastShadeFrame >= 4) {
      _lastShadeFrame = clock.frames;
      _publishShade();
    }
  }

  @override
  void onMotionChanged(bool enabled) {
    if (enabled) {
      clock.repeat();
    } else {
      clock.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publishShade();
    });
    if (!_loading) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final owned = <String, ui.Image>{};
    ui.ImageShader? tree, skull;
    HalloweenPumpkinRig? pumpkinRig;
    var installed = false;
    try {
      for (final name in [
        'background_living_sky',
        'tree_isolated',
        'moon_cloud_bank',
        'skeleton_skull_rig',
        'pumpkin_classic',
        'pumpkin_surprised',
        'pumpkin_sly',
        'pumpkin_classic_eyes_mask',
        'pumpkin_surprised_eyes_mask',
        'pumpkin_sly_eyes_mask',
        'fog_far_clean',
        'fog_near_clean',
        'leaf_01',
        'leaf_02',
        for (var i = 2; i < 6; i++) 'sky_cloud_$i'
      ]) {
        final data = await rootBundle.load('$root/$name.png');
        final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        try {
          owned[name] = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
        if (!mounted) return;
      }
      final bank = owned['moon_cloud_bank']!;
      final rgba = (await bank.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final coverage = HalloweenMoonOcclusion.fromRgba(
          rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
          bank.width,
          bank.height);
      if (!mounted) return;
      tree = ui.ImageShader(owned['tree_isolated']!, TileMode.clamp,
          TileMode.clamp, Matrix4.identity().storage);
      skull = ui.ImageShader(owned['skeleton_skull_rig']!, TileMode.clamp,
          TileMode.clamp, Matrix4.identity().storage);
      pumpkinRig = HalloweenPumpkinRig([
        for (final face in ['classic', 'surprised', 'sly'])
          owned['pumpkin_$face']!
      ], [
        for (final face in ['classic', 'surprised', 'sly'])
          owned['pumpkin_${face}_eyes_mask']!
      ]);
      setState(() {
        images.addAll(owned);
        treeTexture = tree;
        skullTexture = skull;
        moon = coverage;
        pumpkin = pumpkinRig;
      });
      installed = true;
    } catch (error) {
      debugPrint('Halloween layers unavailable: $error');
    } finally {
      if (!installed) {
        tree?.dispose();
        skull?.dispose();
        pumpkinRig?.dispose();
        for (final image in owned.values) {
          image.dispose();
        }
      }
    }
  }

  void _geometry(Rect visible) {
    if (_visible == visible && _shadeCurve.isNotEmpty) return;
    _visible = visible;
    if (moon == null) return;
    _shadeCurve = List.generate(257,
        (i) => moon!.dimming(HalloweenSky.bankRect(i / 256, visible)) * .90);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publishShade();
    });
  }

  double get moonShade {
    if (_still || clock.policy.fps == 0 || _shadeCurve.isEmpty) return 0;
    final p = HalloweenSky.bankPhase(clock.seconds) * 256;
    final i = p.floor().clamp(0, 255);
    return _shadeCurve[i] + (_shadeCurve[i + 1] - _shadeCurve[i]) * (p - i);
  }

  void _publishShade() {
    final notifier = widget.moonShade;
    if (notifier == null) return;
    final value = moonShade;
    if ((notifier.value - value).abs() > .003 ||
        (value == 0 && notifier.value != 0)) {
      notifier.value = value;
    }
  }

  @override
  Widget build(BuildContext context) => SeasonalSceneCanvas(
      sourceSize: const Size(406, 696),
      builder: (context, visible) {
        _geometry(visible);
        if (!layersReady) return const ColoredBox(color: Color(0xFF231339));
        return CustomPaint(
            key: const ValueKey('halloween-world'),
            painter: _HalloweenWorld(
                clock,
                timeline,
                images,
                treeTexture!,
                skullTexture!,
                pumpkin!,
                visible,
                _still,
                widget.moonShade == null ? () => moonShade : null));
      });
  @override
  void dispose() {
    clock.removeListener(_frame);
    clock.dispose();
    treeTexture?.dispose();
    skullTexture?.dispose();
    pumpkin?.dispose();
    for (final image in images.values) {
      image.dispose();
    }
    super.dispose();
  }
}

class _HalloweenWorld extends CustomPainter {
  _HalloweenWorld(this.clock, this.scene, this.images, this.tree, this.skull,
      this.pumpkin, this.visible, this.still, this.shade)
      : super(repaint: clock);
  final SceneFrameClock clock;
  final HalloweenTimeline scene;
  final Map<String, ui.Image> images;
  final ui.ImageShader tree, skull;
  final HalloweenPumpkinRig pumpkin;
  final Rect visible;
  final bool still;
  final double Function()? shade;
  void image(Canvas canvas, String name, Rect rect,
      {double opacity = 1, ColorFilter? tint}) {
    final im = images[name]!;
    canvas.drawImageRect(
        im,
        Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
        rect,
        Paint()
          ..filterQuality = FilterQuality.high
          ..color = Color.fromRGBO(255, 255, 255, opacity)
          ..colorFilter = tint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final staticScene = still || clock.policy.fps == 0;
    final t = staticScene ? 0.0 : clock.seconds;
    image(canvas, 'background_living_sky', const Rect.fromLTWH(0, 0, 406, 696));
    // Every extracted painted sky bank moves, not just an added foreground PNG.

    for (var i = 0; i < 6; i++) {
      final shift = staticScene ? 0.0 : -HalloweenSky.bandLeft(t, i);
      for (final x in [-shift, 406 - shift]) {
        // The first two original strips contain a circular moon cutout. Use
        // a clean, flatter painted bank there rather than moving that outline.
        image(
            canvas,
            i < 2 ? 'moon_cloud_bank' : 'sky_cloud_$i',
            Rect.fromLTWH(
                x + (i < 2 ? 24 + i * 90 : 0),
                HalloweenSky.tops[i] +
                    (staticScene ? 0 : math.sin(t / 13 + i) * 2),
                i < 2 ? (i == 0 ? 285 : 235) : 406,
                i < 2 ? (i == 0 ? 41 : 33) : HalloweenSky.heights[i]),
            opacity: [.65, .65, .77, .45, .30, .16][i]);
      }
    }
    if (!staticScene) {
      image(canvas, 'moon_cloud_bank',
          HalloweenSky.bankRect(HalloweenSky.bankPhase(t), visible),
          opacity: .90,
          tint: const ColorFilter.mode(Color(0xFF9583AC), BlendMode.modulate));
    }
    _tree(canvas, staticScene || !scene.tree.active ? 0 : scene.tree.phase(t));
    // Ground fog stays below the menu, down among the graves and fence.
    for (var i = 0; i < 3; i++) {
      final dx = staticScene ? 0 : math.sin(t / 31 + i * 1.4) * 47;
      image(
          canvas,
          'fog_${i == 0 ? 'far' : 'near'}_clean',
          Rect.fromLTWH(visible.left - 90 + dx, [568.0, 612.0, 650.0][i],
              visible.width + 180, 42),
          opacity: [.065, .075, .035][i]);
    }
    if (!staticScene && scene.bats.active) {
      final age = t - scene.bats.start;
      for (final flight in scene.flights) {
        final p = flight.sample(age, visible);
        if (!p.visible) continue;
        paintHalloweenBat(
            canvas,
            p.center,
            flight.width,
            (age - flight.delay) * math.pi * 2 / flight.flapPeriod +
                flight.flapPhase,
            p.bank);
      }
    }
    if (!staticScene && scene.leaf.active && scene.fall != null) {
      final fall = scene.fall!, p = scene.leaf.phase(t);
      canvas.save();
      canvas.translate(fall.position(p).dx, fall.position(p).dy);
      canvas.rotate(fall.rotation(p));
      image(
          canvas,
          'leaf_0${fall.assetIndex}',
          Rect.fromCenter(
              center: Offset.zero, width: fall.width, height: fall.width),
          opacity: fall.opacity(p));
      canvas.restore();
    }
    final width = math.min(visible.width * .27, 105.0);
    final pumpkinRect = Rect.fromLTWH(visible.left + 14,
        696 - 27 - width * 96 / 115, width, width * 96 / 115);
    final face = staticScene ? 0 : scene.face;
    pumpkin.paint(canvas, pumpkinRect,
        from: staticScene ? 0 : scene.previousFace,
        to: face,
        blend: staticScene ? 1 : scene.faceBlend,
        dim: staticScene ? 0 : scene.eyeDim);
    canvas.save();
    canvas.translate(
        HalloweenMotion.skullRect.left, HalloweenMotion.skullRect.top);
    paintHalloweenSkull(canvas, HalloweenMotion.skullRect.size, skull,
        staticScene ? 0 : scene.turn, staticScene ? 0 : scene.eyelid,
        image: images['skeleton_skull_rig']);
    canvas.restore();
    if (shade != null) {
      canvas.drawRect(const Rect.fromLTWH(0, 0, 406, 696),
          Paint()..color = const Color(0xFF080615).withValues(alpha: shade!()));
    }
  }

  static const cols = 8, rows = 14;
  static final coords = <Offset>[
    for (var y = 0; y <= rows; y++)
      for (var x = 0; x <= cols; x++) Offset(x * 406 / cols, y * 696 / rows)
  ];
  static final indices = <int>[
    for (var y = 0; y < rows; y++)
      for (var x = 0; x < cols; x++) ...[
        y * (cols + 1) + x,
        y * (cols + 1) + x + 1,
        (y + 1) * (cols + 1) + x,
        y * (cols + 1) + x + 1,
        (y + 1) * (cols + 1) + x + 1,
        (y + 1) * (cols + 1) + x
      ]
  ];
  void _tree(Canvas canvas, double phase) {
    final offsets = List.generate(
        rows + 1,
        (row) => HalloweenMotion.treeOffset(
            row * 696 / rows, phase, scene.treeAmplitude));
    final mesh = ui.Vertices(
        ui.VertexMode.triangles,
        [
          for (var i = 0; i < coords.length; i++)
            coords[i] + offsets[i ~/ (cols + 1)]
        ],
        textureCoordinates: coords,
        indices: indices);
    canvas.drawVertices(
        mesh,
        BlendMode.srcOver,
        Paint()
          ..shader = tree
          ..filterQuality = FilterQuality.high);
    mesh.dispose();
  }

  @override
  bool shouldRepaint(_HalloweenWorld old) =>
      images != old.images ||
      still != old.still ||
      visible != old.visible ||
      tree != old.tree;
}
