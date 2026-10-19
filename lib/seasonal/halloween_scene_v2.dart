import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'seasonal_scene_support.dart';

/// Separate decorative layers; Reczt's real controls render above this scene.
class HalloweenLayeredSceneV2 extends StatefulWidget {
  const HalloweenLayeredSceneV2({super.key});
  @override
  State<HalloweenLayeredSceneV2> createState() =>
      _HalloweenLayeredSceneV2State();
}

class _HalloweenLayeredSceneV2State
    extends SeasonalSceneState<HalloweenLayeredSceneV2> {
  static const _root = 'assets/seasonal/halloween_v2';
  final _random = math.Random();
  late final AnimationController _ambient;
  late final AnimationController _blink;
  late final AnimationController _look;
  Timer? _blinkTimer;
  Timer? _lookTimer;
  Timer? _pumpkinTimer;
  Timer? _pumpkinResetTimer;
  int _pumpkinFace = 0;

  @override
  void initState() {
    super.initState();
    _ambient =
        AnimationController(vsync: this, duration: const Duration(seconds: 60));
    _blink = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _look = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 5200));
    _blink.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _blink.reset();
      if (motionEnabled) _scheduleBlink();
    });
    _look.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _look.reset();
      if (motionEnabled) {
        _scheduleLook();
        // Leave a visible pause after looking about before the next blink.
        _scheduleBlink(const Duration(seconds: 3));
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final name in [
      'skeleton_head_front',
      'skeleton_head_front_blink',
      'skeleton_head_left_1',
      'skeleton_head_left_2',
      'skeleton_head_right_1',
      'skeleton_head_right_2',
      'pumpkin_neutral',
      'pumpkin_classic',
      'pumpkin_surprised',
      'pumpkin_sly'
    ]) {
      precacheImage(AssetImage('$_root/$name.png'), context);
    }
  }

  @override
  void onMotionChanged(bool enabled) {
    _cancelTimers();
    if (enabled) {
      _ambient.repeat();
      _scheduleBlink(const Duration(milliseconds: 3400));
      _scheduleLook(const Duration(seconds: 11));
      _schedulePumpkin();
    } else {
      _ambient.stop();
      _blink.stop();
      _blink.reset();
      _look.stop();
      _look.reset();
      _pumpkinFace = 0;
    }
  }

  void _scheduleBlink([Duration? delay]) {
    _blinkTimer?.cancel();
    if (!motionEnabled) return;
    _blinkTimer = Timer(
        delay ?? Duration(milliseconds: 5500 + _random.nextInt(4500)), () {
      if (!mounted || !motionEnabled) return;
      if (_look.isAnimating || _blink.isAnimating) {
        _scheduleBlink(const Duration(seconds: 2));
        return;
      }
      _blink.forward(from: 0);
    });
  }

  void _scheduleLook([Duration? delay]) {
    _lookTimer?.cancel();
    if (!motionEnabled) return;
    _lookTimer =
        Timer(delay ?? Duration(seconds: 17 + _random.nextInt(10)), () {
      if (!mounted || !motionEnabled) return;
      if (_blink.isAnimating) {
        _scheduleLook(const Duration(milliseconds: 900));
        return;
      }
      _blinkTimer?.cancel();
      _look.forward(from: 0);
    });
  }

  void _schedulePumpkin() {
    _pumpkinTimer?.cancel();
    if (!motionEnabled) return;
    _pumpkinTimer = Timer(Duration(seconds: 10 + _random.nextInt(8)), () {
      if (!mounted || !motionEnabled) return;
      setState(() => _pumpkinFace = 1 + _random.nextInt(3));
      _pumpkinResetTimer = Timer(const Duration(milliseconds: 2400), () {
        if (mounted && motionEnabled) setState(() => _pumpkinFace = 0);
      });
      _schedulePumpkin();
    });
  }

  void _cancelTimers() {
    _blinkTimer?.cancel();
    _lookTimer?.cancel();
    _pumpkinTimer?.cancel();
    _pumpkinResetTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    _ambient.dispose();
    _blink.dispose();
    _look.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SeasonalSceneCanvas(
        sourceSize: const Size(406, 696),
        builder: (context, visible) => Stack(fit: StackFit.expand, children: [
          const RepaintBoundary(
              child: Image(
                  image: AssetImage('$_root/background.png'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high)),
          // The old tree patch contained opaque sky; rotating it moved a rectangle
          // of sky over the background. Keep the original illustration intact.
          if (motionEnabled) _atmosphere(visible),
          _pumpkin(visible),
          _skeleton(visible),
        ]),
      );

  Widget _atmosphere(Rect visible) => AnimatedBuilder(
        animation: _ambient,
        builder: (context, _) {
          final seconds = _ambient.value * 60;
          final cloudPhase = (seconds % 30) / 30;
          final leafPhase = (seconds % 20) / 20;
          Widget fog(String asset, double y, double phase, double opacity) =>
              Positioned(
                  left: visible.left -
                      65 +
                      math.sin(seconds * math.pi / 30 + phase) * 35,
                  top: y,
                  width: visible.width + 130,
                  child: Opacity(
                      opacity: opacity,
                      child: Image.asset('$_root/$asset.png',
                          fit: BoxFit.fitWidth)));
          return Stack(fit: StackFit.expand, children: [
            fog('fog_far', 390, 0, .10),
            fog('fog_near', 535, 1.6, .07),
            _bat(visible, seconds, .65, .13, 0, .42),
            _bat(visible, seconds, .80, .23, 2.2, .31),
            if (leafPhase > .08 && leafPhase < .42)
              _leaf(visible, (leafPhase - .08) / .34),
            if (cloudPhase < .3)
              Positioned(
                  left: visible.right +
                      70 -
                      cloudPhase / .3 * (visible.width * .62 + 90),
                  top: 55,
                  width: visible.width * .54,
                  child: Opacity(
                      opacity: math.sin(cloudPhase / .3 * math.pi) * .32,
                      child: Image.asset('$_root/moon_cloud.png'))),
          ]);
        },
      );

  Widget _bat(Rect visible, double seconds, double x, double y, double phase,
      double scale) {
    final flap = math.sin(seconds * math.pi * 2 / 1.2 + phase) * .38;
    return Positioned(
      left: visible.left +
          visible.width * x +
          math.sin(seconds * math.pi / 10 + phase) * 9,
      top: 696 * y + math.sin(seconds * math.pi / 5 + phase) * 3,
      child: Opacity(
          opacity: .65,
          child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: SizedBox(
                  width: 76,
                  height: 40,
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned(
                        left: 0,
                        top: 8,
                        child: Transform.rotate(
                            angle: -.1 + flap,
                            alignment: Alignment.centerRight,
                            child: Image.asset('$_root/bat_left_wing.png',
                                width: 33))),
                    Positioned(
                        right: 4,
                        top: 8,
                        child: Transform.rotate(
                            angle: .1 - flap,
                            alignment: Alignment.centerLeft,
                            child: Image.asset('$_root/bat_right_wing.png',
                                width: 27))),
                    Image.asset('$_root/bat_body.png', width: 19),
                  ])))),
    );
  }

  Widget _leaf(Rect visible, double progress) => Positioned(
        left: visible.left +
            visible.width * (.10 + .52 * progress) +
            math.sin(progress * 11) * 9,
        top: 100 + progress * 410,
        width: 21,
        height: 21,
        child: Opacity(
            opacity: math.sin(progress * math.pi).clamp(0, 1).toDouble(),
            child: Transform.rotate(
                angle: progress * math.pi * 3,
                child: Image.asset('$_root/leaf_01.png'))),
      );

  Widget _pumpkin(Rect visible) {
    final width = math.min(visible.width * .27, 105.0);
    const faces = [
      'pumpkin_neutral',
      'pumpkin_classic',
      'pumpkin_surprised',
      'pumpkin_sly'
    ];
    return Positioned(
      left: visible.left + 14,
      bottom: 27,
      width: width,
      height: width * 96 / 115,
      child: Stack(fit: StackFit.expand, children: [
        AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: Image.asset('$_root/${faces[_pumpkinFace]}.png',
                key: ValueKey(_pumpkinFace),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high)),
        AnimatedBuilder(
            animation: _ambient,
            builder: (context, child) {
              final t = _ambient.value * math.pi * 120;
              final flicker =
                  math.sin(t * 1.3) * .035 + math.sin(t * 2.8) * .025;
              return Opacity(opacity: .19 + flicker, child: child);
            },
            child: Image.asset('$_root/pumpkin_glow.png', fit: BoxFit.contain)),
      ]),
    );
  }

  double _turn(double p) {
    if (p < .18) return -Curves.easeInOutCubic.transform(p / .18);
    if (p < .32) return -1;
    if (p < .58)
      return -1 + 2 * Curves.easeInOutCubic.transform((p - .32) / .26);
    if (p < .74) return 1;
    return 1 - Curves.easeInOutCubic.transform((p - .74) / .26);
  }

  Widget _skeleton(Rect visible) {
    final width = math.min(visible.width * .18, 70.0);
    return Positioned(
      left: visible.right - width - 16,
      bottom: 30,
      width: width,
      height: width * 88 / 84,
      child: AnimatedBuilder(
          animation: Listenable.merge([_look, _blink]),
          builder: (context, _) {
            final turn = _look.isAnimating ? _turn(_look.value) : 0.0;
            const poses = [
              'skeleton_head_left_2',
              'skeleton_head_left_1',
              'skeleton_head_front',
              'skeleton_head_right_1',
              'skeleton_head_right_2'
            ];
            final frame = (turn + 1) * 2;
            final low = frame.floor().clamp(0, 4);
            final high = (low + 1).clamp(0, 4);
            final blend = frame - low;
            final blink =
                math.sin(_blink.value * math.pi).clamp(0.0, 1.0).toDouble();
            final transform = Matrix4.identity()
              ..setEntry(3, 2, .002)
              ..rotateY(turn * .11)
              ..rotateZ(turn * .035);
            return Transform(
              key: const ValueKey('halloween-head-turn'),
              transform: transform,
              alignment: Alignment.bottomCenter,
              child: Stack(fit: StackFit.expand, children: [
                Image.asset('$_root/${poses[low]}.png',
                    fit: BoxFit.contain, filterQuality: FilterQuality.high),
                // Composite over an opaque base so the silhouette never thins
                // out during a transition between independently drawn poses.
                if (high != low && blend > 0)
                  Opacity(
                      opacity: blend,
                      child: Image.asset('$_root/${poses[high]}.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high)),
                Opacity(
                    key: const ValueKey('halloween-blink'),
                    opacity: blink,
                    child: Image.asset('$_root/skeleton_head_front_blink.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high)),
              ]),
            );
          }),
    );
  }
}
