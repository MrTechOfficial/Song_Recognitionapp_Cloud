import 'dart:math' as math;
import 'package:flutter/material.dart';

@immutable
class SnowmanSkatingPose {
  const SnowmanSkatingPose(
      {required this.feet,
      required this.width,
      required this.lean,
      required this.facing,
      required this.strideBlend,
      required this.lift,
      required this.depth,
      required this.speed,
      this.stridePhase = 0,
      this.scarfPhase = 0});
  final Offset feet;
  final double width, lean, facing, strideBlend, lift, depth, speed;
  final double stridePhase, scarfPhase;
  bool get moving => speed > .1;
  // Kept for callers inspecting orientation; the renderer never flattens the PNG edge-on.
  double get yaw => facing < 0 ? math.pi : 0;
  double get shadowOpacity => .055 + .12 * depth;
  double get reflectionOpacity => .025 + .105 * depth;
  double get shadowWidth => width * (.24 + .20 * depth);
  factory SnowmanSkatingPose.at(double seconds, Rect visible) =>
      ChristmasSkatingRoute(visible).sample(seconds);
}

/// A closed artwork-space route. Only viewport cropping can change its bounds.
class ChristmasSkatingRoute {
  ChristmasSkatingRoute(this.visible) {
    // Authored lake coordinates, independent of scrolling foreground controls.
    final far = math.max(810.0, visible.top + 105);
    final near = math.max(far + 70, math.min(1380.0, visible.bottom - 100));
    // The ice narrows toward the foreground. Inset the whole near turn, not
    // just the feet, so the larger sprite clears both snowy banks and trees.
    final left = math.max(visible.left + 145, 145.0);
    final right = math.min(visible.right - 145, 795.0);
    final span = math.max(1.0, right - left);
    Offset p(double x, double y) =>
        Offset(left + span * x, far + (near - far) * y);
    _points = [
      p(.10, .08),
      p(.48, 0),
      p(.90, .14),
      p(.86, .53),
      p(.82, 1),
      p(.22, .98),
      p(.22, .65),
      p(.40, .36)
    ];
    _starts = [0];
    for (final duration in _durations) {
      _starts.add(_starts.last + duration);
    }
    // Integrate depth-dependent cadence, including occasional longer coasts.
    _stride = [0];
    for (var i = 1; i <= _samples; i++) {
      final t = (i - .5) * period / _samples;
      final depth = _depth(_position(t).dy);
      final coast =
          math.pow(math.max(0, math.cos(t * math.pi * 2 / 24)), 10).toDouble();
      final rate = (.27 + .26 * depth) * (1 - .58 * coast);
      _stride.add(_stride.last + rate * period / _samples);
    }
    // Even count: both the pose and its cadence join at the clock seam.
    final factor = 32 / _stride.last;
    for (var i = 0; i < _stride.length; i++) {
      _stride[i] *= factor;
    }
  }
  static const double period = 96;
  static const double startingPhase = 64;
  static const _samples = 768;
  static const _durations = [18.0, 20.0, 10.0, 8.0, 10.0, 10.0, 10.0, 10.0];
  final Rect visible;
  late final List<Offset> _points;
  late final List<double> _starts;
  late final List<double> _stride;

  static double _smooth(double x) {
    x = x.clamp(0, 1);
    return x * x * (3 - 2 * x);
  }

  double _depth(double y) => ((y - 780) / 550).clamp(0, 1);
  Offset _velocityAtNode(int i) {
    final previous = (i + 7) % 8, next = (i + 1) % 8;
    return (_points[next] - _points[previous]) /
        (_durations[previous] + _durations[i]);
  }

  Offset _position(double seconds) {
    final t = (seconds % period + period) % period;
    var i = 0;
    while (i < 7 && t >= _starts[i + 1]) {
      i++;
    }
    final u = (t - _starts[i]) / _durations[i];
    final u2 = u * u, u3 = u2 * u;
    final next = (i + 1) % 8;
    return _points[i] * (2 * u3 - 3 * u2 + 1) +
        _velocityAtNode(i) * _durations[i] * (u3 - 2 * u2 + u) +
        _points[next] * (-2 * u3 + 3 * u2) +
        _velocityAtNode(next) * _durations[i] * (u3 - u2);
  }

  SnowmanSkatingPose sample(double elapsed) {
    // Open on a larger near-shore pass instead of hiding the first half minute
    // of skating behind the environment cards. The route remains clock-only.
    final t = ((elapsed + startingPhase) % period + period) % period;
    final feet = _position(t);
    final velocity = (_position(t + .015) - _position(t - .015)) / .03;
    final depth = _depth(feet.dy);
    final index = t / period * _samples;
    final low = index.floor().clamp(0, _samples - 1);
    final cycle =
        _stride[low] + (_stride[low + 1] - _stride[low]) * (index - low);
    final phase = cycle % 1;
    final push = math.sin(math.pi * (phase / .27).clamp(0, 1));
    final switchAmount = _smooth(phase / .22);
    final blend = cycle.floor().isEven ? 1 - switchAmount : switchAmount;
    final facing = velocity.dx / math.max(velocity.distance, .01);
    final speed = velocity.distance;
    final forwardLean = velocity.dx.sign * .018 * (speed / 32).clamp(0, 1);
    return SnowmanSkatingPose(
      feet: feet,
      width: 104 + 124 * (.5 - .5 * math.cos(math.pi * depth)),
      lean: (blend - .5) * (.009 + depth * .016) + forwardLean * push * .4,
      facing: facing,
      strideBlend: blend,
      lift: push * (.05 + .20 * depth),
      depth: depth,
      speed: speed,
      stridePhase: cycle * math.pi,
      scarfPhase: elapsed * math.pi * 2 / 2,
    );
  }
}
