import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One shared device policy. Native thermal/Low Power changes arrive as events,
/// rather than a polling loop. Recording/searching reserves work for audio.
class SceneEnergyPolicy extends ChangeNotifier {
  static final instance = SceneEnergyPolicy();
  static const channel = MethodChannel('reczt/scene_energy');
  int _deviceFps = 24;
  bool _busy = false, _started = false, _idle = false;
  Timer? _idleTimer;
  int _owners = 0;
  int get activeScenes => _owners;
  int get fps => (_busy || _idle) && _deviceFps > 12 ? 12 : _deviceFps;
  void noteInteraction() {
    _idleTimer?.cancel();
    if (_idle) {
      _idle = false;
      notifyListeners();
    }
    _idleTimer = Timer(const Duration(seconds: 45), () {
      _idle = true;
      _idleTimer = null;
      notifyListeners();
    });
  }

  void attach() {
    if (_owners++ == 0) {
      noteInteraction();
    }
  }

  void detach() {
    _owners--;
    if (_owners == 0) {
      _idleTimer?.cancel();
      _idleTimer = null;
      _idle = false;
    }
  }

  void setBusy(bool busy) {
    if (_busy == busy) return;
    _busy = busy;
    notifyListeners();
  }

  void apply(Map<Object?, Object?> state) {
    final thermal = state['thermal'] as int? ?? 0;
    final next = thermal >= 3
        ? 0
        : thermal >= 2
            ? 8
            : state['lowPower'] == true
                ? 12
                : 24;
    if (_deviceFps == next) return;
    _deviceFps = next;
    notifyListeners();
  }

  Future<void> start() async {
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _started = true;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'policy' && call.arguments is Map) {
        apply(Map<Object?, Object?>.from(call.arguments as Map));
      }
    });
    try {
      final value = await channel.invokeMapMethod<Object?, Object?>('policy');
      if (value != null) apply(value);
    } on MissingPluginException {
      /* Older native builds retain the 24 fps cap. */
    } on PlatformException {/* Keep the conservative default. */}
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }
}

/// A timer-driven decoration clock: no continuously scheduled display ticker.
/// 24 fps normally, 12 while recording/Low Power, 8 when hot, stopped at critical.
/// Scene time freezes while stopped; missed background events never catch up.
class SceneFrameClock extends ChangeNotifier {
  SceneFrameClock({this.period = 384, SceneEnergyPolicy? policy})
      : policy = policy ?? SceneEnergyPolicy.instance {
    this.policy.addListener(_reschedule);
    this.policy.attach();
    unawaited(this.policy.start());
  }
  final double period;
  final SceneEnergyPolicy policy;
  Timer? _timer;
  double seconds = 0;
  int frames = 0;
  bool _enabled = false, _disposed = false;
  double get value => (seconds % period) / period;
  bool get isAnimating => _timer != null;
  void repeat() {
    _enabled = true;
    _reschedule();
  }

  void stop() {
    _enabled = false;
    _timer?.cancel();
    _timer = null;
  }

  void _reschedule() {
    _timer?.cancel();
    _timer = null;
    if (!_enabled || _disposed) return;
    if (policy.fps == 0) {
      // Paint one quiet frame and clear decorative dimming, then stop. Posting
      // outside the policy callback also avoids notifying during widget build.
      scheduleMicrotask(() {
        if (!_disposed) {
          notifyListeners();
        }
      });
      return;
    }
    final interval = Duration(microseconds: (1000000 / policy.fps).round());
    var lastTick = 0;
    _timer = Timer.periodic(interval, (timer) {
      seconds += (timer.tick - lastTick) * interval.inMicroseconds / 1000000;
      lastTick = timer.tick;
      frames++;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    policy.removeListener(_reschedule);
    policy.detach();
    super.dispose();
  }
}
