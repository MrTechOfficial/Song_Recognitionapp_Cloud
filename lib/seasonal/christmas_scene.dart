import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'christmas_scene_layout.dart';
import 'christmas_skating.dart';
import 'seasonal_scene_support.dart';
export 'christmas_scene_layout.dart'
    show ChristmasSceneRegion, ChristmasSceneRegionId;
export 'christmas_skating.dart' show SnowmanSkatingPose, ChristmasSkatingRoute;

/// This host measures the actual interface; it never moves or restyles it.
class ChristmasSceneHost extends StatefulWidget {
  const ChristmasSceneHost({super.key, required this.child});
  final Widget child;
  @override
  State<ChristmasSceneHost> createState() => _ChristmasSceneHostState();
}

class _ChristmasSceneHostState extends State<ChristmasSceneHost> {
  final _rootKey = GlobalKey();
  late final _regions = ChristmasSceneRegions(_rootKey);
  @override
  void dispose() {
    _regions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Stack(key: _rootKey, fit: StackFit.expand, children: [
        ChristmasScene(regions: _regions),
        ChristmasSceneLayout(
            regions: _regions,
            child: NotificationListener<ScrollNotification>(
                onNotification: (_) {
                  _regions.scheduleMeasurement();
                  return false;
                },
                child: widget.child)),
      ]);
}

class ChristmasScene extends StatefulWidget {
  const ChristmasScene({super.key, this.regions});
  final ChristmasSceneRegions? regions;
  @override
  State<ChristmasScene> createState() => _ChristmasSceneState();
}

class _ChristmasSceneState extends SeasonalSceneState<ChristmasScene> {
  static const _root = 'assets/seasonal/christmas';
  late final AnimationController _clock;
  late final List<_Snowflake> _flakes;
  ChristmasSkatingRoute? _route, _previousRoute;
  Rect? _visible, _cards, _instructions;
  double _routeChangedAt = -10;
  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
        vsync: this, duration: const Duration(seconds: 192));
    final random = math.Random(19);
    _flakes = List.generate(
        78,
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
    for (final pose in ['right', 'left']) {
      precacheImage(AssetImage('$_root/snowman_skate_$pose.png'), context);
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
    super.dispose();
  }

  SnowmanSkatingPose _pose(double seconds, Rect visible) {
    Rect? sourceRect(ChristmasSceneRegionId id) {
      final rect = widget.regions?.rects[id];
      if (rect == null) return null;
      final viewport = context.findRenderObject();
      if (viewport is! RenderBox || !viewport.hasSize) return null;
      final scale =
          SeasonalSceneGeometry(const Size(941, 1672), viewport.size).scale;
      return Rect.fromLTWH(
          visible.left + rect.left / scale,
          visible.top + rect.top / scale,
          rect.width / scale,
          rect.height / scale);
    }

    final cards = sourceRect(ChristmasSceneRegionId.cards);
    final instructions = sourceRect(ChristmasSceneRegionId.instructions);
    if (_route == null ||
        visible != _visible ||
        cards != _cards ||
        instructions != _instructions) {
      _previousRoute = _route;
      _route = ChristmasSkatingRoute(visible,
          cards: cards, instructions: instructions);
      _visible = visible;
      _cards = cards;
      _instructions = instructions;
      _routeChangedAt = seconds;
    }
    final pose = _route!.sample(seconds);
    final age = (seconds - _routeChangedAt + 192) % 192;
    if (_previousRoute == null || age >= 1.4) return pose;
    final old = _previousRoute!.sample(seconds);
    final mix = Curves.easeInOut.transform((age / 1.4).clamp(0, 1));
    double lerp(double a, double b) => a + (b - a) * mix;
    return SnowmanSkatingPose(
        feet: Offset.lerp(old.feet, pose.feet, mix)!,
        width: lerp(old.width, pose.width),
        lean: lerp(old.lean, pose.lean),
        facing: lerp(old.facing, pose.facing),
        strideBlend: lerp(old.strideBlend, pose.strideBlend),
        lift: lerp(old.lift, pose.lift),
        depth: lerp(old.depth, pose.depth),
        speed: lerp(old.speed, pose.speed));
  }

  @override
  Widget build(BuildContext context) => SeasonalSceneCanvas(
        sourceSize: const Size(941, 1672),
        builder: (context, visible) => Stack(fit: StackFit.expand, children: [
          const RepaintBoundary(
              child: Image(
                  image: AssetImage('$_root/christmas_background_clean.png'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high)),
          AnimatedBuilder(
              animation: Listenable.merge(
                  [_clock, if (widget.regions != null) widget.regions!]),
              builder: (context, _) {
                final seconds = _clock.value * 192;
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
    Widget body() => _SkatingBody(pose: pose);
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
      Positioned(
          left: pose.feet.dx - width * .52,
          top: pose.feet.dy + 2,
          width: width,
          height: width * (.12 + pose.depth * .14),
          child: Opacity(
              opacity: pose.reflectionOpacity,
              child: Transform.flip(
                  flipY: true,
                  child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (rect) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.white])
                          .createShader(rect),
                      child: body())))),
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

/// Two skate poses, with a stable upper body. The left-facing leg pose is
/// mirrored into the same direction and feathered in below the torso. This
/// avoids alternating faces/hat silhouettes like a blinking two-frame GIF.
class _SkatingBody extends StatelessWidget {
  const _SkatingBody({required this.pose});
  final SnowmanSkatingPose pose;
  static const _root = 'assets/seasonal/christmas';
  @override
  Widget build(BuildContext context) {
    final facing = ((pose.facing + .12) / .24).clamp(0.0, 1.0);
    final rightAmount = facing * facing * (3 - 2 * facing);
    Widget art(bool flip) => Transform.flip(
        flipX: flip,
        child: Transform.rotate(
            angle: pose.lean * (flip ? -1 : 1),
            alignment: Alignment.bottomCenter,
            child: Stack(fit: StackFit.expand, children: [
              ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [
                            0,
                            .64,
                            .79,
                            1
                          ],
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.white
                                .withValues(alpha: 1 - pose.strideBlend),
                            Colors.white.withValues(alpha: 1 - pose.strideBlend)
                          ]).createShader(rect),
                  child: const Image(
                      image: AssetImage('$_root/snowman_skate_right.png'),
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high)),
              Opacity(
                  opacity: pose.strideBlend,
                  child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (rect) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [
                                0,
                                .64,
                                .79,
                                1
                              ],
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                Colors.white,
                                Colors.white
                              ]).createShader(rect),
                      child: const _MirroredSkatePose())),
            ])));
    return Transform.scale(
        scaleX: .91 + .09 * pose.facing.abs(),
        child: Stack(fit: StackFit.expand, children: [
          if (rightAmount < 1)
            Opacity(opacity: 1 - rightAmount, child: art(true)),
          if (rightAmount > 0) Opacity(opacity: rightAmount, child: art(false)),
        ]));
  }
}

class _MirroredSkatePose extends StatelessWidget {
  const _MirroredSkatePose();
  @override
  Widget build(BuildContext context) => Transform.flip(
      flipX: true,
      child: const Image(
          image: AssetImage('assets/seasonal/christmas/snowman_skate_left.png'),
          fit: BoxFit.fill,
          filterQuality: FilterQuality.high));
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
      _lights(canvas, size);
    }
    for (final flake in flakes) {
      if ((flake.layer == 2) != foreground) continue;
      final cycles = 2 + flake.layer * 2;
      final y = (flake.y + seconds / 192 * 1.08 * cycles) % 1.08 - .04;
      final x = flake.x +
          math.sin(seconds * math.pi * 2 / 96 + flake.phase) *
              (.008 + flake.layer * .006);
      final alpha = [.23, .37, .56][flake.layer];
      canvas.drawCircle(
          Offset(x * size.width, y * size.height),
          .9 + flake.layer * .65 + flake.depth * .5,
          Paint()..color = const Color(0xFFEAF5FF).withValues(alpha: alpha));
    }
    if (foreground) _twig(canvas, size);
  }

  void _clouds(Canvas canvas) {
    for (var i = 0; i < 2; i++) {
      final drift = math.sin(seconds * math.pi * 2 / 192 + i * 1.3) * 18;
      canvas.save();
      canvas.translate(660 + i * 120 + drift, 360 + i * 68.0);
      final path = Path()
        ..moveTo(-80, 18)
        ..cubicTo(-65, 1, -44, 5, -35, 9)
        ..cubicTo(-34, -8, -9, -12, 4, 2)
        ..cubicTo(18, -7, 35, 2, 38, 10)
        ..cubicTo(61, 3, 80, 12, 83, 19)
        ..close();
      canvas.drawPath(path,
          Paint()..color = const Color(0xFF88ACC8).withValues(alpha: .09));
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

  void _lights(Canvas canvas, Size size) {
    const bulbs = [
      Offset(.17, .102),
      Offset(.306, .087),
      Offset(.426, .07),
      Offset(.535, .038),
      Offset(.635, .071),
      Offset(.763, .09),
      Offset(.954, .08)
    ];
    const colors = [Color(0xFFFF6855), Color(0xFF9AE379), Color(0xFFFFD779)];
    const events = [9.0, 31.0, 58.0, 92.0, 123.0, 151.0, 178.0];
    for (var i = 0; i < bulbs.length; i++) {
      final age = seconds - events[i];
      if (age < 0 || age > 1.8) continue;
      final pulse = math.pow(math.sin(age / 1.8 * math.pi), 2).toDouble();
      final center =
          Offset(bulbs[i].dx * size.width, bulbs[i].dy * size.height);
      final radius = 28 + pulse * 9;
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = RadialGradient(colors: [
              colors[i % 3].withValues(alpha: .22 * pulse),
              Colors.transparent
            ]).createShader(Rect.fromCircle(center: center, radius: radius)));
      canvas.drawCircle(
          center,
          2,
          Paint()
            ..color = const Color(0xFFFFF4DC).withValues(alpha: pulse * .4));
    }
  }

  void _twig(Canvas canvas, Size size) {
    // A small new foreground sprig, not a rotating rectangular patch of scenery.
    final age = seconds % 96;
    final breeze =
        age > 64 && age < 70 ? math.sin((age - 64) / 6 * math.pi) : 0.0;
    canvas.save();
    canvas.translate(visible.right - 16, size.height - 58);
    canvas.rotate(breeze * .022);
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
