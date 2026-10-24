import 'dart:math' as math;
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
        const ChristmasScene(),
        child,
      ]);
}

class ChristmasScene extends StatefulWidget {
  const ChristmasScene({super.key});
  @override
  State<ChristmasScene> createState() => _ChristmasSceneState();
}

class _ChristmasSceneState extends SeasonalSceneState<ChristmasScene> {
  static const _root = 'assets/seasonal/christmas';
  late final AnimationController _clock;
  late final List<_Snowflake> _flakes;
  ChristmasSkatingRoute? _route;
  Rect? _visible;
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
                  image: AssetImage('$_root/christmas_background_clean.png'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high)),
          AnimatedBuilder(
              animation: _clock,
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
      _roofSnow(canvas);
    }
    for (final flake in flakes) {
      if ((flake.layer == 2) != foreground) continue;
      final cycles = 2 + flake.layer * 2;
      final y = (flake.y + seconds / 192 * 1.08 * cycles) % 1.08 - .04;
      final x = flake.x +
          math.sin(seconds * math.pi * 2 / 96 + flake.phase) *
              (.008 + flake.layer * .006) +
          ChristmasWeather.wind(seconds) /
              size.width *
              (.3 + flake.layer * .35);
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
      final drift = math.sin(seconds * math.pi * 2 / 96 + i * 1.3) * 55;
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
          Paint()..color = const Color(0xFF88ACC8).withValues(alpha: .17));
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
    const colors = [Color(0xFFFF6855), Color(0xFF9AE379), Color(0xFFFFD779)];
    for (var i = 0; i < ChristmasWeather.lightPositions.length; i++) {
      final pulse = ChristmasWeather.lightIntensity(seconds, i);
      if (pulse == 0) continue;
      final bulb = ChristmasWeather.lightPositions[i];
      final center = Offset(bulb.dx * size.width, bulb.dy * size.height);
      final radius = 32 + pulse * 13;
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = RadialGradient(colors: [
              colors[i % 3].withValues(alpha: .44 * pulse),
              Colors.transparent
            ]).createShader(Rect.fromCircle(center: center, radius: radius)));
      canvas.drawOval(
          Rect.fromCenter(center: center, width: 4, height: 9),
          Paint()
            ..color = const Color(0xFFFFF8DC).withValues(alpha: pulse * .85));
      if (pulse > .55) {
        final sparkle = Paint()
          ..color =
              const Color(0xFFFFF3D3).withValues(alpha: (pulse - .55) * .7)
          ..strokeWidth = .9
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
            center + const Offset(-7, 0), center + const Offset(7, 0), sparkle);
        canvas.drawLine(center + const Offset(0, -10),
            center + const Offset(0, 10), sparkle);
      }
    }
  }

  void _roofSnow(Canvas canvas) {
    final snow = ChristmasWeather.roofSnowAt(seconds);
    if (!snow.visible) return;
    if (!snow.landed) {
      canvas.save();
      canvas.translate(snow.position.dx, snow.position.dy);
      canvas.rotate(snow.rotation);
      final chunk = Path()
        ..moveTo(-10, 2)
        ..quadraticBezierTo(-12, -2, -7, -4)
        ..quadraticBezierTo(-3, -8, 1, -4)
        ..quadraticBezierTo(9, -7, 11, -1)
        ..lineTo(8, 4)
        ..lineTo(-6, 5)
        ..close();
      canvas.drawPath(
          chunk,
          Paint()
            ..color = const Color(0xFFBCD6E8).withValues(alpha: snow.opacity));
      canvas.drawPath(
          chunk.shift(const Offset(0, -1)),
          Paint()
            ..color = const Color(0xFFF1F7FF).withValues(alpha: snow.opacity));
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
            Offset(-13 - i * 3.0, 3 + i * 2.0),
            1.2,
            Paint()
              ..color =
                  const Color(0xFFE6F2FC).withValues(alpha: snow.opacity * .5));
      }
      canvas.restore();
    } else {
      final t = snow.scatter;
      for (var i = 0; i < 7; i++) {
        final side = (i - 3) / 3;
        final point = snow.position +
            Offset(side * (5 + 17 * t),
                -math.sin(t * math.pi) * (4 + (i % 3) * 4));
        canvas.drawCircle(
            point,
            (1.1 + i % 2) * (1 - .4 * t),
            Paint()
              ..color =
                  const Color(0xFFEEF7FF).withValues(alpha: snow.opacity * .8));
      }
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
