import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Measurements only: this does not lay out, recolor, or move the real UI.
enum ChristmasSceneRegionId { cards, instructions, heading }

class ChristmasSceneRegions extends ChangeNotifier {
  ChristmasSceneRegions(this.rootKey);
  final GlobalKey rootKey;
  final Map<ChristmasSceneRegionId, RenderBox> _boxes = {};
  Map<ChristmasSceneRegionId, Rect> _rects = {};
  Map<ChristmasSceneRegionId, Rect> get rects => _rects;
  bool _scheduled = false;
  bool _disposed = false;

  void register(ChristmasSceneRegionId id, RenderBox box) {
    _boxes[id] = box;
    scheduleMeasurement();
  }

  void unregister(ChristmasSceneRegionId id, RenderBox box) {
    if (_boxes[id] == box) _boxes.remove(id);
    scheduleMeasurement();
  }

  void scheduleMeasurement() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      final root = rootKey.currentContext?.findRenderObject();
      if (root is! RenderBox || !root.attached) return;
      final next = <ChristmasSceneRegionId, Rect>{};
      for (final entry in _boxes.entries) {
        if (!entry.value.attached || !entry.value.hasSize) continue;
        next[entry.key] = MatrixUtils.transformRect(
            entry.value.getTransformTo(root), Offset.zero & entry.value.size);
      }
      if (next.length == _rects.length &&
          next.entries.every((e) => _rects[e.key] == e.value)) {
        return;
      }
      _rects = next;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _boxes.clear();
    super.dispose();
  }
}

class ChristmasSceneLayout extends InheritedWidget {
  const ChristmasSceneLayout(
      {super.key, required this.regions, required super.child});
  final ChristmasSceneRegions regions;
  static ChristmasSceneRegions? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ChristmasSceneLayout>()
      ?.regions;
  @override
  bool updateShouldNotify(ChristmasSceneLayout oldWidget) =>
      regions != oldWidget.regions;
}

/// On every other theme this returns the original child unchanged.
class ChristmasSceneRegion extends StatelessWidget {
  const ChristmasSceneRegion(
      {super.key, required this.id, required this.child});
  final ChristmasSceneRegionId id;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final regions = ChristmasSceneLayout.maybeOf(context);
    return regions == null
        ? child
        : _RegionMarker(regions: regions, id: id, child: child);
  }
}

class _RegionMarker extends SingleChildRenderObjectWidget {
  const _RegionMarker(
      {required this.regions, required this.id, required super.child});
  final ChristmasSceneRegions regions;
  final ChristmasSceneRegionId id;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RegionBox(regions, id);
  @override
  void updateRenderObject(
      BuildContext context, covariant _RegionBox renderObject) {
    renderObject.configure(regions, id);
  }
}

class _RegionBox extends RenderProxyBox {
  _RegionBox(this.regions, this.id);
  ChristmasSceneRegions regions;
  ChristmasSceneRegionId id;
  void configure(ChristmasSceneRegions next, ChristmasSceneRegionId nextId) {
    if (regions == next && id == nextId) return;
    if (attached) regions.unregister(id, this);
    regions = next;
    id = nextId;
    if (attached) regions.register(id, this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    regions.register(id, this);
  }

  @override
  void detach() {
    regions.unregister(id, this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    regions.scheduleMeasurement();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    regions.scheduleMeasurement();
  }
}
