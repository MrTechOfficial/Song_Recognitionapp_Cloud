import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'halloween_motion.dart';
import 'seasonal_scene_support.dart';

/// Decorative only. Recognition, native integration and foreground controls
/// continue to live in the existing app, above this illustration.
class HalloweenLayeredSceneV2 extends StatefulWidget {
  const HalloweenLayeredSceneV2({super.key, this.randomSeed});
  final int? randomSeed;
  @override
  State<HalloweenLayeredSceneV2> createState() =>
      _HalloweenLayeredSceneV2State();
}

class _HalloweenLayeredSceneV2State
    extends SeasonalSceneState<HalloweenLayeredSceneV2> {
  static const root = 'assets/seasonal/halloween_v2';
  late final math.Random _random;
  late final AnimationController _blink,
      _look,
      _tree,
      _leaf,
      _bats,
      _cloud,
      _candle,
      _fog;
  Timer? _blinkTimer,
      _lookTimer,
      _treeTimer,
      _batTimer,
      _faceTimer,
      _faceResetTimer;
  final _sways = HalloweenSwayCounter();
  bool _looking = false,
      _blinking = false,
      _treeMoving = false,
      _leafFalling = false,
      _batsFlying = false;
  bool _assetsStarted = false;
  double _lookDirection = 1, _treeAmplitude = 3;
  int _face = 0, _lastAlternateFace = 0, _leafGeneration = 0;
  List<HalloweenBatFlight> _flights = const [];
  HalloweenLeafFlight? _fall;
  ui.Image? _treeImage, _cloudImage;
  ui.ImageShader? _treeTexture;
  HalloweenMoonOcclusion? _moon;

  // Read-only counters make the exact third-sway rule inspectable in tests.
  int get completedTreeSways => _sways.completed;
  int get releasedLeaves => _sways.leavesReleased;
  bool get layersReady =>
      _treeTexture != null && _cloudImage != null && _moon != null;

  double _between(double low, double high) =>
      low + _random.nextDouble() * (high - low);
  Duration _delay(double low, double high) =>
      Duration(milliseconds: (_between(low, high) * 1000).round());
  bool get _static => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void initState() {
    super.initState();
    _random = math.Random(widget.randomSeed);
    _blink = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 190));
    _look = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 6200));
    _tree =
        AnimationController(vsync: this, duration: const Duration(seconds: 6));
    _leaf =
        AnimationController(vsync: this, duration: const Duration(seconds: 8));
    _bats =
        AnimationController(vsync: this, duration: const Duration(seconds: 12));
    _cloud = AnimationController(
        vsync: this, duration: const Duration(seconds: 180), value: .04);
    _candle =
        AnimationController(vsync: this, duration: const Duration(seconds: 43));
    _fog =
        AnimationController(vsync: this, duration: const Duration(seconds: 67));
    _blink.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _blinking = false;
      _blink.reset();
      if (motionEnabled) _scheduleBlink();
    });
    _look.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _looking = false;
      _look.reset();
      if (motionEnabled) {
        _scheduleLook();
        _scheduleBlink(_delay(2.8, 4.2));
      }
    });
    _tree.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _treeMoving = false;
      if (_sways.complete()) _releaseLeaf();
      _tree.reset();
      if (motionEnabled) _scheduleTree();
    });
    _leaf.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _leafFalling = false;
      _leaf.reset();
    });
    _bats.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _batsFlying = false;
      _bats.reset();
      if (motionEnabled) _scheduleBats();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assetsStarted) return;
    _assetsStarted = true;
    _loadLayers();
    for (final asset in [
      'skeleton_head_front',
      'skeleton_eyes_closed_overlay',
      'skeleton_head_left_1',
      'skeleton_head_left_2',
      'skeleton_head_right_1',
      'skeleton_head_right_2',
      'pumpkin_classic',
      'pumpkin_surprised',
      'pumpkin_closed',
      'pumpkin_classic_light_mask',
      'pumpkin_surprised_light_mask',
      'pumpkin_closed_light_mask',
      'bat_body',
      'bat_left_wing',
      'bat_right_wing',
      'leaf_01',
      'leaf_02',
      'fog_far',
      'fog_near'
    ]) {
      precacheImage(AssetImage('$root/$asset.png'), context);
    }
  }

  Future<ui.Image> _decode(String name) async {
    final data = await rootBundle.load('$root/$name.png');
    final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  Future<void> _loadLayers() async {
    ui.Image? tree, cloud;
    try {
      await precacheImage(
          const AssetImage('$root/background_tree_clear.png'), context);
      if (!mounted) return;
      tree = await _decode('tree_isolated');
      cloud = await _decode('moon_cloud_clean');
      final rgba = await cloud.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (!mounted) {
        tree.dispose();
        cloud.dispose();
        return;
      }
      final moon = rgba == null
          ? null
          : HalloweenMoonOcclusion.fromRgba(
              rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
              cloud.width,
              cloud.height);
      final texture = ui.ImageShader(
          tree, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage);
      setState(() {
        _treeImage = tree;
        _treeTexture = texture;
        _cloudImage = cloud;
        _moon = moon;
      });
    } catch (error) {
      tree?.dispose();
      cloud?.dispose();
      // The untouched original illustration remains a safe static fallback.
      debugPrint('Halloween layers unavailable: $error');
    }
  }

  @override
  void onMotionChanged(bool enabled) {
    _cancelTimers();
    if (!enabled) {
      for (final controller in [
        _blink,
        _look,
        _tree,
        _leaf,
        _bats,
        _cloud,
        _candle,
        _fog
      ]) {
        controller.stop();
      }
      return;
    }
    _cloud.repeat();
    _candle.repeat();
    _fog.repeat();
    if (_looking) {
      _look.forward();
    } else {
      _scheduleLook(_delay(10, 13));
    }
    if (_blinking) {
      _blink.forward();
    } else {
      _scheduleBlink(_delay(3, 5));
    }
    if (_treeMoving) {
      _tree.forward();
    } else {
      _scheduleTree(_delay(1.5, 2.8));
    }
    if (_leafFalling) _leaf.forward();
    if (_batsFlying) {
      _bats.forward();
    } else {
      _scheduleBats(_delay(5, 8));
    }
    if (_face != 0) {
      _scheduleFaceReset();
    } else {
      _scheduleFace(_delay(8, 13));
    }
  }

  void _scheduleBlink([Duration? delay]) {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(delay ?? _delay(6, 13.5), () {
      if (!mounted || !motionEnabled) return;
      if (_looking || _blinking) {
        _scheduleBlink(_delay(1.1, 2.1));
        return;
      }
      _blinking = true;
      _blink.forward(from: 0);
    });
  }

  void _scheduleLook([Duration? delay]) {
    _lookTimer?.cancel();
    _lookTimer = Timer(delay ?? _delay(16, 28), () {
      if (!mounted || !motionEnabled) return;
      if (_blinking) {
        _scheduleLook(const Duration(milliseconds: 350));
        return;
      }
      _blinkTimer?.cancel();
      _lookDirection = (_random.nextBool() ? 1 : -1) * _between(.82, 1);
      _look.duration = _delay(5.6, 7.1);
      _looking = true;
      _look.forward(from: 0);
    });
  }

  void _scheduleTree([Duration? delay]) {
    _treeTimer?.cancel();
    _treeTimer = Timer(delay ?? _delay(2.5, 4.8), () {
      if (!mounted || !motionEnabled) return;
      _treeAmplitude = (_random.nextBool() ? 1 : -1) *
          (_random.nextInt(5) == 0 ? _between(4, 5) : _between(2.2, 3.5));
      _tree.duration = _delay(5.4, 7.4);
      _treeMoving = true;
      _tree.forward(from: 0);
    });
  }

  void _releaseLeaf() {
    const boughs = [
      Offset(145, 235),
      Offset(197, 221),
      Offset(234, 313),
      Offset(210, 361),
      Offset(132, 355)
    ];
    final origin = boughs[_random.nextInt(boughs.length)];
    _fall = HalloweenLeafFlight(
        origin: origin,
        landingY: _between(614, 653),
        drift: _between(-40, 85),
        phase: _between(0, math.pi * 2),
        duration: _between(6.5, 8.5),
        width: _between(9, 13),
        assetIndex: _random.nextInt(2) + 1);
    _leaf.duration = Duration(milliseconds: (_fall!.duration * 1000).round());
    _leafGeneration++;
    _leafFalling = true;
    if (motionEnabled) _leaf.forward(from: 0);
  }

  void _scheduleBats([Duration? delay]) {
    _batTimer?.cancel();
    _batTimer = Timer(delay ?? _delay(13, 23), () {
      if (!mounted || !motionEnabled) return;
      final rightward = _random.nextBool();
      final duration = _between(10, 14);
      _flights = List.generate(
          _random.nextInt(3) == 0 ? 2 : 1,
          (i) => HalloweenBatFlight(
              rightward: rightward,
              width: i == 0 ? _between(21, 29) : _between(15, 20),
              duration: duration + i * .5,
              delay: i * .9,
              altitude: i == 0 ? _between(-18, 8) : _between(5, 25),
              bend: _between(-12, 17),
              flapPeriod: _between(.58, .92),
              flapPhase: _between(0, math.pi * 2)));
      _bats.duration = Duration(
          milliseconds:
              ((_flights.last.delay + _flights.last.duration) * 1000).round());
      _batsFlying = true;
      _bats.forward(from: 0);
    });
  }

  void _scheduleFace([Duration? delay]) {
    _faceTimer?.cancel();
    _faceTimer = Timer(delay ?? _delay(11, 23), () {
      if (!mounted || !motionEnabled) return;
      setState(() {
        _face = _lastAlternateFace == 0
            ? 1 + _random.nextInt(2)
            : 3 - _lastAlternateFace;
        _lastAlternateFace = _face;
      });
      _scheduleFaceReset();
    });
  }

  void _scheduleFaceReset() {
    _faceResetTimer?.cancel();
    _faceResetTimer = Timer(_delay(3, 5.5), () {
      if (!mounted || !motionEnabled) return;
      setState(() => _face = 0);
      _scheduleFace();
    });
  }

  void _cancelTimers() {
    for (final timer in [
      _blinkTimer,
      _lookTimer,
      _treeTimer,
      _batTimer,
      _faceTimer,
      _faceResetTimer
    ]) {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    for (final controller in [
      _blink,
      _look,
      _tree,
      _leaf,
      _bats,
      _cloud,
      _candle,
      _fog
    ]) {
      controller.dispose();
    }
    _treeTexture?.dispose();
    _treeImage?.dispose();
    _cloudImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SeasonalSceneCanvas(
        sourceSize: const Size(406, 696),
        builder: (context, visible) => TickerMode(
            enabled: motionEnabled,
            child: Stack(fit: StackFit.expand, children: [
              RepaintBoundary(
                  child: Image(
                      image: AssetImage(
                          '$root/${_treeTexture == null ? 'background' : 'background_tree_clear'}.png'),
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high)),
              if (_treeTexture != null)
                RepaintBoundary(
                    child: AnimatedBuilder(
                        animation: _tree,
                        builder: (context, _) => HalloweenTreeLayer(
                            texture: _treeTexture!,
                            phase: _static || !_treeMoving ? 0 : _tree.value,
                            amplitude: _treeAmplitude))),
              _fogLayer(visible),
              if (_cloudImage != null && !_static)
                RepaintBoundary(
                    child: AnimatedBuilder(
                        animation: _cloud,
                        builder: (context, _) => CustomPaint(
                            painter: _CloudPainter(
                                _cloudImage!,
                                HalloweenMotion.cloudRect(
                                    _cloud.value, visible))))),
              if (!_static)
                RepaintBoundary(
                    child: AnimatedBuilder(
                        animation: _bats,
                        builder: (context, _) => Stack(children: [
                              if (_batsFlying)
                                for (final flight in _flights)
                                  _bat(flight, visible)
                            ]))),
              if (!_static)
                AnimatedBuilder(
                    animation: _leaf,
                    builder: (context, _) => _leafFalling && _fall != null
                        ? HalloweenFallingLeaf(
                            key: const ValueKey('halloween-falling-leaf'),
                            flight: _fall!,
                            progress: _leaf.value,
                            generation: _leafGeneration)
                        : const SizedBox.shrink()),
              _pumpkin(visible),
              _skeleton(visible),
              if (_moon != null && !_static)
                AnimatedBuilder(
                    animation: _cloud,
                    builder: (context, _) => Opacity(
                        key: const ValueKey('halloween-moon-dimming'),
                        opacity: _moon!.dimming(
                            HalloweenMotion.cloudRect(_cloud.value, visible)),
                        child: const ColoredBox(color: Color(0xFF05040D)))),
            ])),
      );

  Widget _fogLayer(Rect visible) => RepaintBoundary(
      child: AnimatedBuilder(
          animation: _fog,
          builder: (context, _) {
            final t = _static ? 0.0 : _fog.value * math.pi * 2;
            return Stack(children: [
              for (var i = 0; i < 2; i++)
                Positioned(
                    left: visible.left - 35 + math.sin(t + i * 1.6) * 13,
                    top: i == 0 ? 422 : 548,
                    width: visible.width + 70,
                    child: Opacity(
                        opacity: i == 0 ? .055 : .04,
                        child: Image.asset(
                            '$root/fog_${i == 0 ? 'far' : 'near'}.png',
                            fit: BoxFit.fitWidth)))
            ]);
          }));

  Widget _bat(HalloweenBatFlight flight, Rect visible) {
    final pose = flight.sample(
        _bats.value * _bats.duration!.inMilliseconds / 1000, visible);
    if (!pose.visible) return const SizedBox.shrink();
    return Positioned(
        left: pose.center.dx - flight.width / 2,
        top: pose.center.dy - flight.width * .25,
        width: flight.width,
        height: flight.width * .5,
        child: Transform.rotate(
            angle: pose.bank,
            child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                    width: 80,
                    height: 40,
                    child: Stack(children: [
                      Positioned(
                          left: 0,
                          top: 7,
                          width: 34,
                          height: 24,
                          child: Transform.rotate(
                              angle: -.08 + pose.flap,
                              alignment: Alignment.centerRight,
                              child: Image.asset('$root/bat_left_wing.png',
                                  fit: BoxFit.fill))),
                      Positioned(
                          right: 0,
                          top: 7,
                          width: 34,
                          height: 24,
                          child: Transform.rotate(
                              angle: .08 - pose.flap,
                              alignment: Alignment.centerLeft,
                              child: Image.asset('$root/bat_right_wing.png',
                                  fit: BoxFit.fill))),
                      Positioned(
                          left: 30,
                          top: 6,
                          width: 20,
                          height: 30,
                          child: Image.asset('$root/bat_body.png',
                              fit: BoxFit.contain)),
                    ])))));
  }

  Widget _pumpkin(Rect visible) {
    final width = math.min(visible.width * .27, 105.0);
    const faces = ['classic', 'surprised', 'closed'];
    final face = faces[_static ? 0 : _face];
    return Positioned(
        left: visible.left + 14,
        bottom: 27,
        width: width,
        height: width * 96 / 115,
        child: RepaintBoundary(
            child: AnimatedSwitcher(
                duration:
                    _static ? Duration.zero : const Duration(milliseconds: 320),
                child: _CandlePumpkin(
                    key: ValueKey(face),
                    face: face,
                    candle: _candle,
                    staticScene: _static))));
  }

  Widget _skeleton(Rect visible) {
    final width = math.min(visible.width * .18, 70.0);
    return Positioned(
        left: visible.right - width - 16,
        bottom: 30,
        width: width,
        height: width * 88 / 84,
        child: RepaintBoundary(
            child: AnimatedBuilder(
                animation: Listenable.merge([_look, _blink]),
                builder: (context, _) => HalloweenPaintedHead(
                    key: const ValueKey('halloween-head-turn'),
                    turn: _static || !_looking
                        ? 0
                        : HalloweenMotion.headTurn(_look.value, _lookDirection),
                    blink: _static || !_blinking
                        ? 0
                        : HalloweenMotion.blink(_blink.value)))));
  }
}

class HalloweenPaintedHead extends StatelessWidget {
  const HalloweenPaintedHead(
      {super.key, required this.turn, required this.blink});
  final double turn, blink;
  @override
  Widget build(BuildContext context) {
    const poses = ['left_2', 'left_1', 'front', 'right_1', 'right_2'];
    final frame = ((turn + 1) * 2).clamp(0.0, 4.0);
    final low = frame.floor(), high = math.min(low + 1, 4), blend = frame - low;
    Widget pose(int i) => Image.asset(
        '${_HalloweenLayeredSceneV2State.root}/skeleton_head_${poses[i]}.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high);
    return Stack(fit: StackFit.expand, children: [
      pose(low),
      if (high != low && blend > 0) Opacity(opacity: blend, child: pose(high)),
      Opacity(
          key: const ValueKey('halloween-blink'),
          opacity: blink,
          child: Image.asset(
              '${_HalloweenLayeredSceneV2State.root}/skeleton_eyes_closed_overlay.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high)),
    ]);
  }
}

class HalloweenFallingLeaf extends StatelessWidget {
  const HalloweenFallingLeaf(
      {super.key,
      required this.flight,
      required this.progress,
      required this.generation});
  final HalloweenLeafFlight flight;
  final double progress;
  final int generation;
  @override
  Widget build(BuildContext context) {
    final point = flight.position(progress);
    return Positioned(
        left: point.dx - flight.width / 2,
        top: point.dy - flight.width / 2,
        width: flight.width,
        height: flight.width,
        child: Opacity(
            opacity: flight.opacity(progress),
            child: Transform.rotate(
                angle: flight.rotation(progress),
                child: Image.asset(
                    '${_HalloweenLayeredSceneV2State.root}/leaf_0${flight.assetIndex}.png',
                    filterQuality: FilterQuality.high))));
  }
}

class HalloweenTreeLayer extends StatelessWidget {
  const HalloweenTreeLayer(
      {super.key,
      required this.texture,
      required this.phase,
      required this.amplitude});
  final ui.ImageShader texture;
  final double phase, amplitude;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _TreePainter(texture, phase, amplitude));
}

class _TreePainter extends CustomPainter {
  const _TreePainter(this.texture, this.phase, this.amplitude);
  final ui.ImageShader texture;
  final double phase, amplitude;
  static const _columns = 14, _rows = 28;
  static final _coordinates = <Offset>[
    for (var row = 0; row <= _rows; row++)
      for (var col = 0; col <= _columns; col++)
        Offset(406 * col / _columns, 696 * row / _rows)
  ];
  static final _indices = <int>[
    for (var row = 0; row < _rows; row++)
      for (var col = 0; col < _columns; col++) ...[
        row * (_columns + 1) + col,
        row * (_columns + 1) + col + 1,
        (row + 1) * (_columns + 1) + col,
        row * (_columns + 1) + col + 1,
        (row + 1) * (_columns + 1) + col + 1,
        (row + 1) * (_columns + 1) + col,
      ]
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final positions = [
      for (final point in _coordinates)
        point + HalloweenMotion.treeOffset(point.dy, phase, amplitude)
    ];
    final mesh = ui.Vertices(ui.VertexMode.triangles, positions,
        textureCoordinates: _coordinates, indices: _indices);
    canvas.drawVertices(
        mesh,
        BlendMode.srcOver,
        Paint()
          ..shader = texture
          ..filterQuality = FilterQuality.high);
    mesh.dispose();
  }

  @override
  bool shouldRepaint(_TreePainter old) =>
      texture != old.texture ||
      phase != old.phase ||
      amplitude != old.amplitude;
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter(this.image, this.rect);
  final ui.Image image;
  final Rect rect;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()
        ..color = const Color(0xA6FFFFFF)
        ..filterQuality = FilterQuality.high);
  @override
  bool shouldRepaint(_CloudPainter old) =>
      image != old.image || rect != old.rect;
}

class _CandlePumpkin extends StatelessWidget {
  const _CandlePumpkin(
      {super.key,
      required this.face,
      required this.candle,
      required this.staticScene});
  final String face;
  final Animation<double> candle;
  final bool staticScene;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: candle,
      builder: (context, _) {
        final strength =
            staticScene ? .55 : HalloweenMotion.candle(candle.value);
        final mask =
            '${_HalloweenLayeredSceneV2State.root}/pumpkin_${face}_light_mask.png';
        return Stack(fit: StackFit.expand, children: [
          Image.asset('${_HalloweenLayeredSceneV2State.root}/pumpkin_$face.png',
              fit: BoxFit.contain, filterQuality: FilterQuality.high),
          Image.asset(mask,
              fit: BoxFit.contain,
              color: Color.fromRGBO(26, 12, 7, .32 * (1 - strength)),
              colorBlendMode: BlendMode.srcIn),
          Opacity(
              opacity: .09 + strength * .12,
              child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                      sigmaX: .7 + strength, sigmaY: .7 + strength),
                  child: Image.asset(mask,
                      fit: BoxFit.contain,
                      color: const Color(0xFFFFB94C),
                      colorBlendMode: BlendMode.srcIn))),
          Image.asset(mask,
              fit: BoxFit.contain,
              color: Color.fromRGBO(255, 218, 116, strength * .10),
              colorBlendMode: BlendMode.srcIn),
        ]);
      });
}
