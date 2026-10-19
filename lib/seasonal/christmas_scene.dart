import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'seasonal_scene_support.dart';

class ChristmasScene extends StatefulWidget {
  const ChristmasScene({super.key});
  @override
  State<ChristmasScene> createState() => _ChristmasSceneState();
}

/// Continuous push/glide motion with a pause and turn at either bank.
/// The ice and all moving layers use the background's 941 × 1672 coordinates.
@immutable
class SnowmanSkatingPose {
  const SnowmanSkatingPose(
      {required this.feet,
      required this.width,
      required this.lean,
      required this.yaw,
      required this.moving});
  final Offset feet;
  final double width, lean, yaw;
  final bool moving;
  factory SnowmanSkatingPose.at(double seconds, Rect visible) {
    final cycle = seconds % 36;
    double travel;
    double yaw;
    final moving = cycle < 13 || (cycle >= 18 && cycle < 31);
    if (cycle < 13) {
      travel = (1 - math.cos(math.pi * cycle / 13)) / 2;
      yaw = 0;
    } else if (cycle < 18) {
      travel = 1;
      yaw = math.pi *
          Curves.easeInOutCubic.transform(((cycle - 15) / 1.6).clamp(0.0, 1.0));
    } else if (cycle < 31) {
      travel = (1 + math.cos(math.pi * (cycle - 18) / 13)) / 2;
      yaw = math.pi;
    } else {
      travel = 0;
      yaw = math.pi *
          (1 -
              Curves.easeInOutCubic
                  .transform(((cycle - 33) / 1.6).clamp(0.0, 1.0)));
    }
    // The old height * .365 path put the character above the shoreline.
    final laneLeft = math.max(visible.left + 74, 165.0);
    final laneRight = math.min(visible.right - 74, 775.0);
    final depth = math.sin(travel * math.pi);
    final laneY = math.min(1180.0, visible.bottom - 54);
    return SnowmanSkatingPose(
      feet: Offset(
          laneLeft + (laneRight - laneLeft) * travel, laneY - 35 * depth),
      width: 128 - depth * 14,
      lean: moving ? math.sin(seconds * math.pi * 2 / 1.5) * .045 : 0,
      yaw: yaw,
      moving: moving,
    );
  }
}

class _ChristmasSceneState extends SeasonalSceneState<ChristmasScene> {
  static const _root = 'assets/seasonal/christmas';
  late final AnimationController _clock;
  late final List<_Snowflake> _flakes;
  @override
  void initState() {
    super.initState();
    _clock =
        AnimationController(vsync: this, duration: const Duration(seconds: 72));
    final random = math.Random(19);
    _flakes = List.generate(
        64,
        (_) => _Snowflake(
            random.nextDouble(),
            random.nextDouble(),
            .25 + random.nextDouble() * .75,
            random.nextDouble() * math.pi * 2));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('$_root/snowman_skate_right.png'), context);
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
                final seconds = _clock.value * 72;
                final pose = SnowmanSkatingPose.at(seconds, visible);
                return Stack(fit: StackFit.expand, children: [
                  CustomPaint(painter: _ChristmasLightsPainter(seconds)),
                  _snowman(pose),
                  if (motionEnabled)
                    CustomPaint(painter: _SnowfallPainter(seconds, _flakes)),
                ]);
              }),
        ]),
      );
  Widget _snowman(SnowmanSkatingPose pose) {
    const sprite = AssetImage('$_root/snowman_skate_right.png');
    final width = pose.width;
    // The source image has alpha margins; the blade is at 95% of its height.
    final left = pose.feet.dx - width * .52;
    final top = pose.feet.dy - width * .95;
    final turn = Matrix4.identity()
      ..setEntry(3, 2, .002)
      ..rotateY(pose.yaw);
    Widget character() => Transform(
        alignment: Alignment.center,
        transform: turn,
        child: Transform.rotate(
            angle: pose.lean,
            alignment: Alignment.bottomCenter,
            child: const Image(
                image: sprite,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true)));
    return Stack(children: [
      Positioned(
          left: pose.feet.dx - width * .24,
          top: pose.feet.dy - 2,
          width: width * .48,
          height: 6,
          child: DecoratedBox(
              decoration: BoxDecoration(
                  color: const Color(0x25031D36),
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: const [
                BoxShadow(color: Color(0x22031D36), blurRadius: 7)
              ]))),
      Positioned(
          left: left,
          top: pose.feet.dy + 3,
          width: width,
          height: width * .27,
          child: Opacity(
              opacity: .12,
              child: Transform.flip(
                  flipY: true,
                  child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (rect) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.white])
                          .createShader(rect),
                      child: character())))),
      Positioned(
          key: const ValueKey('christmas-snowman'),
          left: left,
          top: top,
          width: width,
          height: width,
          child: character()),
    ]);
  }
}

class _Snowflake {
  const _Snowflake(this.x, this.y, this.depth, this.phase);
  final double x, y, depth, phase;
}

class _SnowfallPainter extends CustomPainter {
  const _SnowfallPainter(this.seconds, this.flakes);
  final double seconds;
  final List<_Snowflake> flakes;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final flake in flakes) {
      final cycles = 1 + (flake.depth * 2).floor();
      final y = (flake.y + seconds / 72 * 1.08 * cycles) % 1.08 - .04;
      final x = flake.x +
          math.sin(seconds * math.pi * 2 / 72 + flake.phase) *
              .016 *
              flake.depth;
      paint.color =
          const Color(0xFFEAF5FF).withValues(alpha: .23 + flake.depth * .57);
      canvas.drawCircle(
          Offset(x * size.width, y * size.height), 1 + flake.depth * 2, paint);
    }
  }

  @override
  bool shouldRepaint(_SnowfallPainter oldDelegate) =>
      seconds != oldDelegate.seconds;
}

class _ChristmasLightsPainter extends CustomPainter {
  const _ChristmasLightsPainter(this.seconds);
  final double seconds;
  static const _bulbs = [
    Offset(.17, .102),
    Offset(.306, .087),
    Offset(.426, .07),
    Offset(.535, .038),
    Offset(.635, .071),
    Offset(.763, .09),
    Offset(.954, .08)
  ];
  static const _colors = [
    Color(0xFFFF6855),
    Color(0xFF9AE379),
    Color(0xFFFFD779)
  ];
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _bulbs.length; i++) {
      final center =
          Offset(_bulbs[i].dx * size.width, _bulbs[i].dy * size.height);
      final alpha = .16 + .08 * math.sin(seconds * math.pi * 2 / 8 + i * 1.3);
      final radius = size.width * .04;
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                _colors[i % 3].withValues(alpha: alpha),
                Colors.transparent
              ],
            ).createShader(Rect.fromCircle(center: center, radius: radius)));
    }
  }

  @override
  bool shouldRepaint(_ChristmasLightsPainter oldDelegate) =>
      seconds != oldDelegate.seconds;
}
