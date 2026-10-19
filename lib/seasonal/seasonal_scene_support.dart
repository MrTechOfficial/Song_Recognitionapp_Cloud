import 'dart:math' as math;
import 'package:flutter/material.dart';

/// One BoxFit.cover transform for scenery and every animated overlay.
@immutable
class SeasonalSceneGeometry {
  const SeasonalSceneGeometry(this.source, this.viewport);
  final Size source;
  final Size viewport;
  double get scale =>
      math.max(viewport.width / source.width, viewport.height / source.height);
  Rect get visibleSourceRect {
    final width = viewport.width / scale;
    final height = viewport.height / scale;
    return Rect.fromLTWH((source.width - width) / 2,
        (source.height - height) / 2, width, height);
  }
}

/// Decorative artwork never participates in hit testing or accessibility.
class SeasonalSceneCanvas extends StatelessWidget {
  const SeasonalSceneCanvas(
      {super.key, required this.sourceSize, required this.builder});
  final Size sourceSize;
  final Widget Function(BuildContext context, Rect visibleSourceRect) builder;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(child: RepaintBoundary(child: LayoutBuilder(
          builder: (context, constraints) {
            final media = MediaQuery.sizeOf(context);
            final size = Size(
              constraints.hasBoundedWidth ? constraints.maxWidth : media.width,
              constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : media.height,
            );
            if (size.isEmpty) return const SizedBox.shrink();
            final geometry = SeasonalSceneGeometry(sourceSize, size);
            return SizedBox.fromSize(
                size: size,
                child: ClipRect(
                    child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox.fromSize(
                      size: sourceSize,
                      child: builder(context, geometry.visibleSourceRect)),
                )));
          },
        ))),
      );
}

/// Shared lifecycle gate for controllers AND occasional gesture timers.
abstract class SeasonalSceneState<T extends StatefulWidget> extends State<T>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _appActive = true;
  bool _motionEnabled = false;
  bool get motionEnabled => _motionEnabled;
  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appActive = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    final enabled = _appActive &&
        TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (enabled == _motionEnabled) return;
    _motionEnabled = enabled;
    onMotionChanged(enabled);
    if (mounted) setState(() {});
  }

  void onMotionChanged(bool enabled);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
