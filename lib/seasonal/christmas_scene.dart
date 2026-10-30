import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'scene_frame_clock.dart';
import 'package:flutter/material.dart';
import 'christmas_skating.dart';
import 'christmas_weather.dart';
import 'seasonal_scene_support.dart';
export 'christmas_skating.dart' show SnowmanSkatingPose, ChristmasSkatingRoute;

/// The world is fixed behind the interface. Scrolling the child never changes
/// the snowman's route, position, scale, or animation clock.
class ChristmasSceneHost extends StatelessWidget {
  const ChristmasSceneHost({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Color(0xFF061A2B)),
        const ChristmasScene(),
        RepaintBoundary(child: child),
      ]);
}

class ChristmasScene extends StatefulWidget {
  const ChristmasScene({super.key});
  @override
  State<ChristmasScene> createState() => _ChristmasSceneState();
}

class _ChristmasSceneState extends SeasonalSceneState<ChristmasScene> {
  static const _root = 'assets/seasonal/christmas';
  late final SceneFrameClock _clock;
  final _rig = <String, ui.Image>{};
  ui.ImageShader? _scarf;
  bool _rigLoading = false;
  late final List<_Snowflake> _flakes;
  ChristmasSkatingRoute? _route;
  Rect? _visible;
  @override
  void initState() {
    super.initState();
    _clock = SceneFrameClock(period: ChristmasWeather.loopSeconds.toDouble());
    final random = math.Random(19);
    _flakes = List.generate(
        64,
        (i) => _Snowflake(
            random.nextDouble(),
            random.nextDouble(),
            .2 + random.nextDouble() * .8,
            random.nextDouble() * math.pi * 2,
            i % 3));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_rigLoading) {
      _rigLoading = true;
      _loadRig();
    }
  }

  Future<void> _loadRig() async {
    final owned = <String, ui.Image>{};
    var installed = false;
    ui.ImageShader? scarf;
    try {
      for (final name in [
        'body_rig',
        'skate_back',
        'skate_front',
        'scarf_tail'
      ]) {
        final data = await rootBundle.load('$_root/snowman_$name.png');
        final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        try {
          owned[name] = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
        if (!mounted) return;
      }
      scarf = ui.ImageShader(owned['scarf_tail']!, TileMode.clamp,
          TileMode.clamp, Matrix4.identity().storage);
      setState(() {
        _rig.addAll(owned);
        _scarf = scarf;
      });
      installed = true;
    } catch (error) {
      debugPrint('Christmas rig unavailable: $error');
    } finally {
      if (!installed) {
        scarf?.dispose();
        for (final image in owned.values) {
          image.dispose();
        }
      }
    }
  }

  @override
  void onMotionChanged(bool enabled) {
    if (enabled) {
      _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _scarf?.dispose();
    for (final image in _rig.values) {
      image.dispose();
    }
    super.dispose();
  }

  SnowmanSkatingPose _pose(double seconds, Rect visible) {
    // Only a real viewport/crop change (e.g. rotation) can alter the lake bounds.
    // Never inspect positions of scrolling widgets here.
    if (_route == null || visible != _visible) {
      _route = ChristmasSkatingRoute(visible);
      _visible = visible;
    }
    return _route!.sample(seconds);
  }

  @override
  Widget build(BuildContext context) => SeasonalSceneCanvas(
        sourceSize: const Size(941, 1672),
        builder: (context, visible) => Stack(fit: StackFit.expand, children: [
          const RepaintBoundary(
              child: Image(
                  image:
                      AssetImage('$_root/christmas_background_edge_fill.png'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high)),
          AnimatedBuilder(
              animation: _clock,
              builder: (context, _) {
                final seconds = _clock.value * ChristmasWeather.loopSeconds;
                final pose = _pose(seconds, visible);
                return Stack(fit: StackFit.expand, children: [
                  if (motionEnabled)
                    CustomPaint(
                        painter: _WinterAtmosphere(seconds, _flakes, visible,
                            foreground: false)),
                  _snowman(pose),
                  if (motionEnabled)
                    CustomPaint(
                        painter: _WinterAtmosphere(seconds, _flakes, visible,
                            foreground: true)),
                ]);
              }),
        ]),
      );

  Widget _snowman(SnowmanSkatingPose pose) {
    final width = pose.width;
    Widget body() =>
        ChristmasSkatingFigure(pose: pose, images: _rig, scarf: _scarf);
    return Stack(children: [
      Positioned(
          left: pose.feet.dx - pose.shadowWidth / 2,
          top: pose.feet.dy - 2,
          width: pose.shadowWidth,
          height: 2 + pose.depth * 3,
          child: DecoratedBox(
              decoration: BoxDecoration(
                  color: const Color(0xFF05203A)
                      .withValues(alpha: pose.shadowOpacity),
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                BoxShadow(
                    color: const Color(0xFF05203A)
                        .withValues(alpha: pose.shadowOpacity * .6),
                    blurRadius: 3 + pose.depth * 3)
              ]))),
      if (_rig['body_rig'] != null)
        Positioned(
            left: pose.feet.dx - width * .48,
            top: pose.feet.dy + 2,
            width: width * .90,
            height: width * .16,
            child: CustomPaint(
                painter: _SnowmanReflection(
                    _rig['body_rig']!, pose.reflectionOpacity * .60))),
      Positioned(
          key: const ValueKey('christmas-snowman'),
          left: pose.feet.dx - width * .52,
          top: pose.feet.dy - width * .95 - pose.lift,
          width: width,
          height: width,
          child: body()),
    ]);
  }
}

/// Separate painted boots alternate support/push. The torso never dissolves.
class ChristmasSkatingFigure extends StatelessWidget {
  const ChristmasSkatingFigure(
      {super.key,
      required this.pose,
      required this.images,
      required this.scarf});
  final SnowmanSkatingPose pose;
  final Map<String, ui.Image> images;
  final ui.ImageShader? scarf;
  @override
  Widget build(BuildContext context) => images.isEmpty
      ? const SizedBox.shrink()
      : Transform.flip(
          flipX: pose.facing < 0,
          child: CustomPaint(painter: _SkaterPainter(pose, images, scarf!)));
}

class _SnowmanReflection extends CustomPainter {
  const _SnowmanReflection(this.image, this.opacity);
  final ui.Image image;
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(0, size.height);
    canvas.scale(1, -1);
    canvas.drawImageRect(
        image,
        const Rect.fromLTWH(0, 0, 400, 400),
        Offset.zero & size,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, opacity)
          ..filterQuality = FilterQuality.low);
  }

  @override
  bool shouldRepaint(_SnowmanReflection old) =>
      opacity != old.opacity || image != old.image;
}

class _SkaterPainter extends CustomPainter {
  const _SkaterPainter(this.pose, this.images, this.scarf);
  final SnowmanSkatingPose pose;
  final Map<String, ui.Image> images;
  final ui.ImageShader scarf;
  void layer(Canvas canvas, String name) {
    canvas.drawImage(
        images[name]!, Offset.zero, Paint()..filterQuality = FilterQuality.low);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 400, size.height / 400);
    final push = math.sin(pose.stridePhase);
    final back = math.pow(math.max(0.0, push), 2).toDouble(),
        front = math.pow(math.max(0.0, -push), 2).toDouble();
    canvas.translate(210, 385);
    canvas.rotate(pose.lean * 1.6 + push * .025);
    canvas.translate(-210, -385);
    for (final rear in [true, false]) {
      final weight = rear ? back : front;
      final pivot = rear ? const Offset(123, 275) : const Offset(239, 313);
      final hip = rear ? const Offset(136, 280) : const Offset(235, 302);
      final ankle = pivot + Offset((rear ? -31 : 24) * weight, -18 * weight);
      final leg = Path()
        ..moveTo(hip.dx, hip.dy)
        ..quadraticBezierTo((hip.dx + ankle.dx) / 2,
            (hip.dy + ankle.dy) / 2 - 5, ankle.dx, ankle.dy);
      canvas.drawPath(
          leg,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 14
            ..color = const Color(0xFFC1D7EA));
      canvas.drawPath(
          leg,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 10
            ..color = const Color(0xFFEDF5F8));
      canvas.save();
      canvas.translate(
          pivot.dx + (rear ? -31 : 24) * weight, pivot.dy - 18 * weight);
      canvas.rotate((rear ? -.36 : .28) * weight);
      canvas.translate(-pivot.dx, -pivot.dy);
      layer(canvas, rear ? 'skate_back' : 'skate_front');
      canvas.restore();
    }
    canvas.save();
    canvas.translate(push * 3, -math.sin(pose.stridePhase * 2).abs() * 2);
    _scarf(canvas);
    layer(canvas, 'body_rig');
    canvas.restore();
    canvas.restore();
  }

  static final uv = <Offset>[
    for (var y = 0; y <= 10; y++)
      for (var x = 0; x <= 10; x++) Offset(x * 40.0, y * 40.0)
  ];
  static final ix = <int>[
    for (var y = 0; y < 10; y++)
      for (var x = 0; x < 10; x++) ...[
        y * 11 + x,
        y * 11 + x + 1,
        (y + 1) * 11 + x,
        y * 11 + x + 1,
        (y + 1) * 11 + x + 1,
        (y + 1) * 11 + x
      ]
  ];
  void _scarf(Canvas canvas) {
    final vertices = ui.Vertices(
        ui.VertexMode.triangles,
        [
          for (final p in uv)
            p +
                Offset(
                    0,
                    (math.sin(pose.scarfPhase - p.dx / 41) * 10 +
                            math.sin(pose.scarfPhase * .75 - p.dx / 27) * 3) *
                        ((183 - p.dx) / 125).clamp(0.0, 1.0))
        ],
        textureCoordinates: uv,
        indices: ix);
    canvas.drawVertices(
        vertices,
        BlendMode.srcOver,
        Paint()
          ..shader = scarf
          ..filterQuality = FilterQuality.low);
    vertices.dispose();
  }

  @override
  bool shouldRepaint(_SkaterPainter old) =>
      pose != old.pose || images != old.images;
}

class _Snowflake {
  const _Snowflake(this.x, this.y, this.depth, this.phase, this.layer);
  final double x, y, depth, phase;
  final int layer;
}

class _WinterAtmosphere extends CustomPainter {
  const _WinterAtmosphere(this.seconds, this.flakes, this.visible,
      {required this.foreground});
  final double seconds;
  final List<_Snowflake> flakes;
  final Rect visible;
  final bool foreground;
  @override
  void paint(Canvas canvas, Size size) {
    if (!foreground) {
      _clouds(canvas);
      _smoke(canvas);
      _lights(canvas);
      _roofSnow(canvas);
    }
    for (final flake in flakes) {
      if ((flake.layer == 2) != foreground) continue;
      final cycles = 3 + flake.layer * 2;
      final y = (flake.y + seconds / 192 * 1.08 * cycles) % 1.08 - .04;
      final x = (flake.x +
                  seconds / 192 * 1.08 * (1 + flake.layer) +
                  math.sin(seconds * math.pi * 2 / 24 + flake.phase) *
                      (.012 + flake.layer * .008) +
                  ChristmasWeather.wind(seconds) /
                      size.width *
                      (.4 + flake.layer * .4)) %
              1.08 -
          .04;
      final alpha = [.35, .60, .80][flake.layer];
      canvas.drawCircle(
          Offset(x * size.width, y * size.height),
          1.3 + flake.layer * .9 + flake.depth * .7,
          Paint()..color = const Color(0xFFEAF5FF).withValues(alpha: alpha));
    }
    if (foreground) {
      _blowingSnow(canvas);
      _twig(canvas, size);
    }
  }

  void _clouds(Canvas canvas) {
    const heights = [342.0, 428.0, 520.0];
    const scales = [1.5, 1.25, 1.05];
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(ChristmasWeather.cloudX(seconds, i), heights[i]);
      canvas.scale(scales[i]);
      final path = Path()
        ..moveTo(-80, 18)
        ..cubicTo(-65, 1, -44, 5, -35, 9)
        ..cubicTo(-34, -8, -9, -12, 4, 2)
        ..cubicTo(18, -7, 35, 2, 38, 10)
        ..cubicTo(61, 3, 80, 12, 83, 19)
        ..cubicTo(55, 26, 39, 20, 20, 23)
        ..cubicTo(4, 28, -12, 20, -28, 23)
        ..cubicTo(-47, 26, -66, 20, -80, 18)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFBBD4E9).withValues(alpha: .27),
                  const Color(0xFF799EBF).withValues(alpha: .40)
                ]).createShader(const Rect.fromLTWH(-85, -12, 170, 40)));
      canvas.save();
      canvas.clipPath(path);
      // Broken pale contours keep the moving layer close to the drawn art.
      final wisps = Path()
        ..moveTo(-65, 14)
        ..quadraticBezierTo(-51, 6, -39, 13)
        ..moveTo(-27, 7)
        ..quadraticBezierTo(-15, -3, -3, 7)
        ..moveTo(16, 14)
        ..quadraticBezierTo(28, 7, 40, 15);
      canvas.drawPath(
          wisps,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .9
            ..color = const Color(0xFFD5E6F2).withValues(alpha: .12));
      canvas.restore();
      canvas.restore();
    }
  }

  void _smoke(Canvas canvas) {
    // Chimney sits at the right-hand cabin, behind the near snow layer.
    for (var i = 0; i < 4; i++) {
      final phase = ((seconds + i * 4) % 16) / 16;
      final opacity = math.sin(phase * math.pi) * .12;
      final x = 876 - phase * 36 + math.sin(phase * 5 + i) * 3;
      final y = 549 - phase * 67;
      final radius = 2 + phase * 9;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y), width: radius * 2.6, height: radius * 1.4),
          Paint()
            ..color = const Color(0xFFC9D8DF).withValues(alpha: opacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }

  void _lights(Canvas canvas) {
    const colors = [Color(0xFFFF6855), Color(0xFF9AE379), Color(0xFFFFD779)];
    const tilts = [-.22, -.16, -.25, -.12, .34, .18, -.26];
    for (var i = 0; i < ChristmasWeather.lightPositions.length; i++) {
      final pulse = ChristmasWeather.lightIntensity(seconds, i);
      final center = ChristmasWeather.lightPositions[i];
      final radius = 48 + pulse * 28;
      // The illustration already contains bright bulbs. Slightly dim their
      // colored glass between pulses so the bright/dim change is unmistakable.
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(tilts[i]);
      canvas.drawOval(const Rect.fromLTWH(-9, -20, 18, 40),
          Paint()..color = Colors.black.withValues(alpha: .35 * (1 - pulse)));
      canvas.restore();
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = RadialGradient(colors: [
              colors[i % 3].withValues(alpha: .10 + .70 * pulse),
              Colors.transparent
            ]).createShader(Rect.fromCircle(center: center, radius: radius)));
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(tilts[i]);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero,
              width: 8 + 5 * pulse,
              height: 18 + 8 * pulse),
          Paint()
            ..color =
                const Color(0xFFFFF8DC).withValues(alpha: .1 + pulse * .9));
      canvas.restore();
      if (pulse > .5) {
        final sparkle = Paint()
          ..color =
              const Color(0xFFFFF3D3).withValues(alpha: (pulse - .5) * 1.6)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(center + const Offset(-18, 0),
            center + const Offset(18, 0), sparkle);
        canvas.drawLine(center + const Offset(0, -26),
            center + const Offset(0, 26), sparkle);
      }
    }
  }

  void _roofSnow(Canvas canvas) {
    final snow = ChristmasWeather.roofSnowAt(seconds);
    _roofSnowPile(canvas, snow);
    if (!snow.visible) return;
    if (!snow.landed) {
      canvas.save();
      canvas.translate(snow.position.dx, snow.position.dy);
      canvas.rotate(snow.rotation);
      canvas.scale(.62);
      final chunk = Path()
        ..moveTo(-27, 3)
        ..quadraticBezierTo(-29, -6, -19, -9)
        ..quadraticBezierTo(-12, -17, -3, -10)
        ..quadraticBezierTo(6, -17, 14, -10)
        ..quadraticBezierTo(29, -13, 29, -1)
        ..lineTo(22, 9)
        ..lineTo(-19, 11)
        ..close();
      canvas.drawPath(
          chunk,
          Paint()
            ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFEFF0EC).withValues(alpha: snow.opacity),
                  const Color(0xFFDDE7EF).withValues(alpha: snow.opacity),
                  const Color(0xFFAAC6DF).withValues(alpha: snow.opacity)
                ],
                stops: const [
                  0,
                  .6,
                  1
                ]).createShader(const Rect.fromLTWH(-30, -15, 60, 27)));
      final folds = Path()
        ..moveTo(-18, 1)
        ..quadraticBezierTo(-11, -4, -5, 0)
        ..moveTo(3, 2)
        ..quadraticBezierTo(12, -4, 22, -1);
      canvas.drawPath(
          folds,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color =
                const Color(0xFF9FB9D0).withValues(alpha: snow.opacity * .28));
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
            Offset(31 + i * 5.0, -4 + math.sin(i * 2.0) * 9),
            2.0 + i % 2,
            Paint()
              ..color =
                  const Color(0xFFE6F2FC).withValues(alpha: snow.opacity * .8));
      }
      canvas.restore();
    } else {
      final t = snow.scatter;
      for (var i = 0; i < 5; i++) {
        final side = (i - 2) / 2;
        final point = snow.position +
            Offset(side * (4 + 14 * t),
                -math.sin(t * math.pi) * (3 + (i % 3) * 2));
        canvas.drawCircle(
            point,
            (1.1 + i % 2) * (1 - .4 * t),
            Paint()
              ..color =
                  const Color(0xFFE8EFF5).withValues(alpha: snow.opacity * .5));
      }
    }
  }

  void _roofSnowPile(Canvas canvas, ChristmasRoofSnowState snow) {
    // A modest existing drift receives each fall. Keeping the resting mound
    // avoids either vanishing snow or an abrupt reset at the scene-clock seam.
    final settle = snow.landed ? math.sin(snow.scatter * math.pi) * 1.8 : 0.0;
    canvas.save();
    canvas.translate(
        ChristmasWeather.roofBank.dx, ChristmasWeather.roofBank.dy);
    final pile = Path()
      ..moveTo(-20, 2)
      ..quadraticBezierTo(-16, -3, -10, -4)
      ..quadraticBezierTo(-4, -10 - settle, 3, -7 - settle)
      ..quadraticBezierTo(11, -8, 16, -2)
      ..quadraticBezierTo(21, -1, 22, 2)
      ..quadraticBezierTo(3, 6, -20, 2)
      ..close();
    canvas.drawOval(const Rect.fromLTWH(-21, 0, 44, 5),
        Paint()..color = const Color(0xFF91ACC4).withValues(alpha: .3));
    canvas.drawPath(
        pile,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFEEF0EC), Color(0xFFCFDEEB)])
              .createShader(const Rect.fromLTWH(-21, -11, 44, 17)));
    canvas.restore();
  }

  void _blowingSnow(Canvas canvas) {
    for (var band = 0; band < 4; band++) {
      final gust = ChristmasBreeze.sample(seconds, visible, band);
      if (gust.opacity <= 0) continue;
      canvas.save();
      canvas.translate(gust.position.dx, gust.position.dy);
      for (var i = 0; i < 9; i++) {
        final x = (i - 4) * 12.0;
        canvas.drawCircle(
            Offset(x, math.sin(i * 1.9 + seconds * 1.3) * 10),
            1.3 + (i % 3) * .6,
            Paint()
              ..color = const Color(0xFFF2FAFF)
                  .withValues(alpha: gust.opacity * .63));
      }
      final wisp = Path()
        ..moveTo(-35, 5)
        ..cubicTo(-10, -7, 12, 7, 35, -1);
      canvas.drawPath(
          wisp,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..color =
                const Color(0xFFD8ECF9).withValues(alpha: gust.opacity * .20));
      canvas.restore();
    }
  }

  void _twig(Canvas canvas, Size size) {
    // A small new foreground sprig, not a rotating rectangular patch of scenery.
    final breeze = ChristmasWeather.wind(seconds) / 67;
    canvas.save();
    canvas.translate(visible.right - 16, size.height - 58);
    canvas.rotate(breeze * .10);
    final twig = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-2, -24, -13, -43)
      ..moveTo(-5, -20)
      ..lineTo(-23, -31)
      ..moveTo(-9, -33)
      ..lineTo(2, -48);
    canvas.drawPath(
        twig,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF112C40));
    canvas.drawLine(
        const Offset(-22, -32),
        const Offset(-9, -25),
        Paint()
          ..color = const Color(0xFFC6DBE8)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WinterAtmosphere oldDelegate) =>
      seconds != oldDelegate.seconds ||
      foreground != oldDelegate.foreground ||
      visible != oldDelegate.visible;
}
