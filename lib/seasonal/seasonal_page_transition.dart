import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Exposes the route's own controller to its back gesture. The navigator owns
/// the pop, so focus, route observers and cancelled swipes behave normally.
class RecztPageRoute<T> extends MaterialPageRoute<T> {
  RecztPageRoute(
      {required super.builder, super.settings, super.allowSnapshotting = true});

  bool _dragging = false;
  bool get canStartBackSwipe =>
      isCurrent &&
      popGestureEnabled &&
      !navigator!.userGestureInProgress &&
      secondaryAnimation!.isDismissed;

  bool beginBackSwipe() {
    if (!canStartBackSwipe) return false;
    _dragging = true;
    navigator!.didStartUserGesture();
    return true;
  }

  void updateBackSwipe(double fraction) {
    if (_dragging && isActive) {
      controller!.value = (controller!.value - fraction).clamp(0.0, 1.0);
    }
  }

  void endBackSwipe(double velocity, {bool cancelled = false}) {
    if (!_dragging) return;
    final nav = navigator!;
    final complete = !cancelled &&
        isCurrent &&
        (velocity.abs() >= 1 ? velocity > 0 : controller!.value < .5);
    if (complete) nav.pop();
    final target = complete || !isActive ? 0.0 : 1.0;
    if (controller!.value == target) {
      _stopGesture(nav);
    } else {
      final settling = target == 0
          ? controller!.animateBack(0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic)
          : controller!.animateTo(1,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic);
      settling.whenCompleteOrCancel(() => _stopGesture(nav));
    }
  }

  void _stopGesture(NavigatorState nav) {
    if (!_dragging) return;
    _dragging = false;
    if (nav.mounted) nav.didStopUserGesture();
  }
}

/// Taps fade only page controls over the persistent scene. During a swipe the
/// same fade tracks the finger; the painted background never slides or clones.
class SeasonalPageTransitionsBuilder extends PageTransitionsBuilder {
  const SeasonalPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    Widget content = child;
    if (!MediaQuery.disableAnimationsOf(context)) {
      final interactive = route.popGestureInProgress;
      final incoming = animation.drive(CurveTween(
          curve: interactive
              ? Curves.linear
              : const Interval(.30, 1, curve: Curves.easeOutCubic)));
      final outgoing = secondaryAnimation.drive(CurveTween(
          curve: interactive
              ? Curves.linear
              : const Interval(0, .65, curve: Curves.easeInCubic)));
      content = FadeTransition(
          opacity: incoming,
          child: FadeTransition(
              opacity: ReverseAnimation(outgoing), child: child));
    }
    if (route is RecztPageRoute<T>) {
      return _SeasonalBackSwipe<T>(route: route, child: content);
    }
    return content;
  }
}

class _SeasonalBackSwipe<T> extends StatefulWidget {
  const _SeasonalBackSwipe({required this.route, required this.child});
  final RecztPageRoute<T> route;
  final Widget child;
  @override
  State<_SeasonalBackSwipe<T>> createState() => _SeasonalBackSwipeState<T>();
}

class _SeasonalBackSwipeState<T> extends State<_SeasonalBackSwipe<T>> {
  late final HorizontalDragGestureRecognizer _recognizer;
  bool _started = false;
  double get _direction =>
      Directionality.of(context) == TextDirection.rtl ? -1 : 1;
  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = (_) {
        _started = widget.route.beginBackSwipe();
      }
      ..onUpdate = (details) {
        if (_started) {
          widget.route.updateBackSwipe(
              details.primaryDelta! * _direction / context.size!.width);
        }
      }
      ..onEnd = (details) {
        if (_started) {
          widget.route.endBackSwipe(details.velocity.pixelsPerSecond.dx *
              _direction /
              context.size!.width);
        }
        _started = false;
      }
      ..onCancel = () {
        if (_started) widget.route.endBackSwipe(0, cancelled: true);
        _started = false;
      };
  }

  @override
  void dispose() {
    _recognizer.dispose();
    if (_started) {
      final route = widget.route;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => route.endBackSwipe(0, cancelled: true));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
      // The recognizer participates in the gesture arena: vertical lists and
      // child horizontal controls retain their own gestures. Both edges and
      // unused page space can begin a back swipe.
      onPointerDown: (event) {
        if (widget.route.canStartBackSwipe) _recognizer.addPointer(event);
      },
      behavior: HitTestBehavior.translucent,
      child: widget.child);
}
