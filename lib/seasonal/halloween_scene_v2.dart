import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'halloween_motion.dart';
import 'halloween_characters.dart';
import 'seasonal_scene_support.dart';
export 'halloween_characters.dart' show HalloweenPaintedHead, HalloweenPumpkin;

/// The same moon shadow reaches the illustration and real controls, without
/// rebuilding the foreground or intercepting taps.
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
        HalloweenLayeredSceneV2(moonShade: _shade),
        widget.child,
        IgnorePointer(
            child: ExcludeSemantics(
                child: AnimatedBuilder(
          animation: _shade,
          builder: (context, _) => Opacity(
              key: const ValueKey('halloween-ui-moon-dimming'),
              opacity: _shade.value,
              child: const ColoredBox(color: Color(0xFF080615))),
        ))),
      ]);
  @override
  void dispose() {
    _shade.dispose();
    super.dispose();
  }
}

/// Decorative only. Recognition, native integration and foreground controls
/// continue to live in the existing app, above this illustration.
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
  late final math.Random _random;
  late final AnimationController _blink,
      _look,
      _tree,
      _leaf,
      _bats,
      _cloud,
      _candle,
      _fog,
      _expression,
      _pumpkinBlink;
  Timer? _blinkTimer,
      _lookTimer,
      _treeTimer,
      _batTimer,
      _faceTimer,
      _pumpkinBlinkTimer;
  final _sways = HalloweenSwayCounter();
  bool _looking = false,
      _blinking = false,
      _treeMoving = false,
      _leafFalling = false,
      _batsFlying = false,
      _pumpkinBlinking = false;
  bool _assetsStarted = false;
  double _lookDirection = 1, _treeAmplitude = 3;
  int _face = 0, _lastAlternateFace = 0, _leafGeneration = 0;
  int _launchedBats = 0;
  List<HalloweenBatFlight> _flights = const [];
  HalloweenLeafFlight? _fall;
  ui.Image? _treeImage,
      _cloudImage,
      _cloudBankImage,
      _skullImage,
      _pumpkinShell;
  ui.ImageShader? _treeTexture, _skullTexture;
  HalloweenMoonOcclusion? _moon, _bankMoon;
  Rect? _visible;

  // Read-only counters make the exact third-sway rule inspectable in tests.
  int get completedTreeSways => _sways.completed;
  int get releasedLeaves => _sways.leavesReleased;
  int get launchedBats => _launchedBats;
  bool get layersReady =>
      _treeTexture != null &&
      _cloudImage != null &&
      _moon != null &&
      _bankMoon != null &&
      _skullTexture != null &&
      _pumpkinShell != null;

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
        vsync: this, duration: const Duration(seconds: 180));
    _candle =
        AnimationController(vsync: this, duration: const Duration(seconds: 11));
    _fog = AnimationController(
        vsync: this, duration: const Duration(seconds: 110));
    _expression = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4900));
    _pumpkinBlink = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 240));
    _cloud.addListener(_updateMoonShade);
    _expression.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      setState(() => _face = 0);
      _expression.reset();
      if (motionEnabled) _scheduleFace();
    });
    _pumpkinBlink.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _pumpkinBlinking = false;
      _pumpkinBlink.reset();
      if (motionEnabled) _schedulePumpkinBlink();
    });
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateMoonShade();
    });
    if (_assetsStarted) return;
    _assetsStarted = true;
    _loadLayers();
    for (final asset in [
      'pumpkin_classic',
      'skeleton_skull_rig',
      'bat_body',
      'bat_left_wing',
      'bat_right_wing',
      'leaf_01',
      'leaf_02',
      'fog_far_clean',
      'fog_near_clean'
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
    final images = <ui.Image>[];
    final shaders = <ui.ImageShader>[];
    var installed = false;
    Future<ui.Image> load(String name) async {
      final image = await _decode(name);
      images.add(image);
      return image;
    }

    Future<HalloweenMoonOcclusion> mask(ui.Image image) async {
      final rgba =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      return HalloweenMoonOcclusion.fromRgba(
          rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
          image.width,
          image.height);
    }

    try {
      await precacheImage(
          const AssetImage('$root/background_tree_clear.png'), context);
      if (!mounted) return;
      final tree = await load('tree_isolated');
      final cloud = await load('moon_cloud_clean');
      final bank = await load('moon_cloud_bank');
      final skull = await load('skeleton_skull_rig');
      final shell = await load('pumpkin_shell');
      final moon = await mask(cloud), bankMoon = await mask(bank);
      if (!mounted) return;
      final texture = ui.ImageShader(
          tree, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage);
      shaders.add(texture);
      final skullTexture = ui.ImageShader(
          skull, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage);
      shaders.add(skullTexture);
      setState(() {
        _treeImage = tree;
        _treeTexture = texture;
        _cloudImage = cloud;
        _moon = moon;
        _cloudBankImage = bank;
        _bankMoon = bankMoon;
        _skullImage = skull;
        _skullTexture = skullTexture;
        _pumpkinShell = shell;
      });
      installed = true;
      _updateMoonShade();
    } catch (error) {
      // The untouched original illustration remains a safe static fallback.
      debugPrint('Halloween layers unavailable: $error');
    } finally {
      if (!installed) {
        for (final shader in shaders) {
          shader.dispose();
        }
        for (final image in images) {
          image.dispose();
        }
      }
    }
  }

  double _moonShade(Rect visible) {
    if (_static || _moon == null || _bankMoon == null) return 0;
    var transmission = 1.0;
    for (final cloud in HalloweenCloudFlight.sky) {
      final coverage = (cloud.bank ? _bankMoon! : _moon!)
          .coverage(cloud.sample(_cloud.value, visible));
      transmission *= 1 - coverage * cloud.opacity;
    }
    return HalloweenMoonOcclusion.shadeForCoverage(1 - transmission);
  }

  void _updateMoonShade() {
    if (!mounted || widget.moonShade == null || _visible == null) return;
    final value = _moonShade(_visible!);
    if ((value == 0 && widget.moonShade!.value != 0) ||
        (widget.moonShade!.value - value).abs() > .0005) {
      widget.moonShade!.value = value;
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
        _fog,
        _expression,
        _pumpkinBlink
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
      _scheduleLook(_delay(6, 9));
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
      _scheduleBats(_delay(1.5, 3));
    }
    if (_face != 0) {
      _expression.forward();
    } else {
      _scheduleFace(_delay(4, 7));
    }
    if (_pumpkinBlinking) {
      _pumpkinBlink.forward();
    } else {
      _schedulePumpkinBlink(_delay(3, 6));
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
    _lookTimer = Timer(delay ?? _delay(11, 19), () {
      if (!mounted || !motionEnabled) return;
      if (_blinking) {
        _scheduleLook(const Duration(milliseconds: 350));
        return;
      }
      _blinkTimer?.cancel();
      _lookDirection = (_random.nextBool() ? 1 : -1) * _between(.82, 1);
      _look.duration = _delay(4.8, 6.2);
      _looking = true;
      _look.forward(from: 0);
    });
  }

  void _scheduleTree([Duration? delay]) {
    _treeTimer?.cancel();
    _treeTimer = Timer(delay ?? _delay(2.5, 4.8), () {
      if (!mounted || !motionEnabled) return;
      _treeAmplitude = (_random.nextBool() ? 1 : -1) *
          (_random.nextInt(5) == 0 ? _between(15, 18) : _between(8, 12));
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
    _batTimer = Timer(delay ?? _delay(3, 7), () {
      if (!mounted || !motionEnabled) return;
      final rightward = _random.nextBool();
      final duration = _between(7, 10);
      _flights = List.generate(
          3 + _random.nextInt(3),
          (i) => HalloweenBatFlight(
              rightward: rightward,
              width: i == 0 ? _between(24, 31) : _between(16, 26),
              duration: duration + i * .5,
              delay: i * .55,
              altitude: i == 0 ? _between(-24, 8) : _between(-35, 40),
              bend: _between(-17, 24),
              flapPeriod: _between(.58, .92),
              flapPhase: _between(0, math.pi * 2)));
      _launchedBats += _flights.length;
      _bats.duration = Duration(
          milliseconds:
              ((_flights.last.delay + _flights.last.duration) * 1000).round());
      _batsFlying = true;
      _bats.forward(from: 0);
    });
  }

  void _scheduleFace([Duration? delay]) {
    _faceTimer?.cancel();
    _faceTimer = Timer(delay ?? _delay(7, 13), () {
      if (!mounted || !motionEnabled) return;
      setState(() {
        _face = _lastAlternateFace == 0
            ? 1 + _random.nextInt(2)
            : 3 - _lastAlternateFace;
        _lastAlternateFace = _face;
      });
      _expression.duration = _delay(4.3, 5.7);
      _expression.forward(from: 0);
    });
  }

  void _schedulePumpkinBlink([Duration? delay]) {
    _pumpkinBlinkTimer?.cancel();
    _pumpkinBlinkTimer = Timer(delay ?? _delay(7, 13), () {
      if (!mounted || !motionEnabled) return;
      _pumpkinBlinking = true;
      _pumpkinBlink.forward(from: 0);
    });
  }

  void _cancelTimers() {
    for (final timer in [
      _blinkTimer,
      _lookTimer,
      _treeTimer,
      _batTimer,
      _faceTimer,
      _pumpkinBlinkTimer
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
      _fog,
      _expression,
      _pumpkinBlink
    ]) {
      controller.dispose();
    }
    _treeTexture?.dispose();
    _treeImage?.dispose();
    _cloudImage?.dispose();
    _cloudBankImage?.dispose();
    _skullTexture?.dispose();
    _skullImage?.dispose();
    _pumpkinShell?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SeasonalSceneCanvas(
        sourceSize: const Size(406, 696),
        builder: (context, visible) {
          if (_visible != visible) {
            _visible = visible;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updateMoonShade();
            });
          }
          return TickerMode(
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
                              painter: _CloudPainter(_cloudImage!,
                                  _cloudBankImage!, _cloud.value, visible)))),
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
                if (widget.moonShade == null && _moon != null && !_static)
                  AnimatedBuilder(
                      animation: _cloud,
                      builder: (context, _) => Opacity(
                          key: const ValueKey('halloween-moon-dimming'),
                          opacity: _moonShade(visible),
                          child: const ColoredBox(color: Color(0xFF080615)))),
              ]));
        },
      );

  Widget _fogLayer(Rect visible) => RepaintBoundary(
      child: AnimatedBuilder(
          animation: _fog,
          builder: (context, _) {
            final t = _static ? 0.0 : _fog.value * math.pi * 2;
            return Stack(children: [
              for (var i = 0; i < 3; i++)
                Positioned(
                    left: visible.left - 95 + math.sin(t + i * 1.6) * 55,
                    top: [435.0, 523.0, 601.0][i] + math.sin(t + i) * 3,
                    width: visible.width + 190,
                    child: Opacity(
                        opacity: [.17, .24, .15][i],
                        child: Image.asset(
                            '$root/fog_${i == 0 ? 'far' : 'near'}_clean.png',
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
    return Positioned(
        left: visible.left + 14,
        bottom: 27,
        width: width,
        height: width * 96 / 115,
        child: RepaintBoundary(
            child: AnimatedBuilder(
                animation:
                    Listenable.merge([_expression, _pumpkinBlink, _candle]),
                builder: (context, _) => HalloweenPumpkin(
                      shell: _pumpkinShell,
                      face: _static ? 0 : _face,
                      expression: _static || _face == 0
                          ? 0
                          : HalloweenMotion.expression(_expression.value),
                      blink: _static || !_pumpkinBlinking
                          ? 0
                          : HalloweenMotion.blink(_pumpkinBlink.value),
                      candle:
                          _static ? .68 : HalloweenMotion.candle(_candle.value),
                      breath: _static
                          ? 0
                          : math.sin(_candle.value * math.pi * 4) +
                              (_face == 0
                                  ? 0
                                  : math.sin(_expression.value * math.pi * 2)),
                    ))));
  }

  Widget _skeleton(Rect visible) {
    return Positioned.fromRect(
        rect: HalloweenMotion.skullRect,
        child: RepaintBoundary(
            child: AnimatedBuilder(
                animation: Listenable.merge([_look, _blink]),
                builder: (context, _) => HalloweenPaintedHead(
                      key: const ValueKey('halloween-head-turn'),
                      texture: _skullTexture,
                      turn: _static || !_looking
                          ? 0
                          : HalloweenMotion.headTurn(
                              _look.value, _lookDirection),
                      blink: _static || !_blinking
                          ? 0
                          : HalloweenMotion.blink(_blink.value),
                      nod: _static || !_looking
                          ? 0
                          : math.sin(_look.value * math.pi * 4),
                    ))));
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
  const _CloudPainter(this.image, this.bank, this.clock, this.visible);
  final ui.Image image, bank;
  final double clock;
  final Rect visible;
  @override
  void paint(Canvas canvas, Size size) {
    for (final cloud in HalloweenCloudFlight.sky.reversed) {
      final texture = cloud.bank ? bank : image;
      canvas.drawImageRect(
          texture,
          Rect.fromLTWH(
              0, 0, texture.width.toDouble(), texture.height.toDouble()),
          cloud.sample(clock, visible),
          Paint()
            ..color = Color.fromRGBO(255, 255, 255, cloud.opacity)
            ..filterQuality = FilterQuality.high);
    }
  }

  @override
  bool shouldRepaint(_CloudPainter old) =>
      image != old.image ||
      bank != old.bank ||
      clock != old.clock ||
      visible != old.visible;
}
