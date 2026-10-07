import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/snapping/manual_guide.dart';
import 'package:fluvie_editor/src/snapping/snap_line.dart';
import 'package:fluvie_editor/src/widgets/canvas_ruler.dart';
import 'package:fluvie_editor/src/widgets/canvas_viewport.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt;

part 'guide_layer_strips.dart';

/// The ruler-and-guide surface over the canvas: a top and a left
/// [CanvasRuler], the slide's manual guides, and the Figma gestures — drag
/// off a ruler to place a guide, drag a guide to move it, drop it back on
/// its ruler to remove it.
///
/// The layer is document-free: it renders [guides] and reports every change
/// as one new list through [onGuidesChanged] (the owner turns that into a
/// command, so undo applies).
final class GuideLayer extends StatefulWidget {
  /// The layer over a [slideSize] canvas under [viewport]'s camera.
  const GuideLayer({
    required this.viewport,
    required this.slideSize,
    required this.guides,
    required this.onGuidesChanged,
    super.key,
  });

  /// The camera mapping canvas to viewport pixels.
  final CanvasViewportController viewport;

  /// The slide's canvas-pixel size (guide fractions resolve against it).
  final Size slideSize;

  /// The slide's stored guides.
  final List<ManualGuide> guides;

  /// Receives the full new guide list after a create, move, or removal.
  final ValueChanged<List<ManualGuide>> onGuidesChanged;

  @override
  State<GuideLayer> createState() => _GuideLayerState();
}

final class _GuideLayerState extends State<GuideLayer> {
  /// The in-flight gesture: a new guide pulled off a ruler (`index` -1) or
  /// an existing one being moved. `position` is canvas units along the
  /// guide's axis — null while the pointer is still over the ruler, where
  /// releasing places nothing (or removes the dragged guide).
  ({int index, SnapOrientation orientation, double? position})? _drag;

  /// Opens a gesture over guide [index] (-1 for a fresh one off a ruler).
  void _beginDrag(int index, SnapOrientation orientation, double? position) =>
      setState(() => _drag = (index: index, orientation: orientation, position: position));

  double _extentOf(SnapOrientation orientation) =>
      orientation == SnapOrientation.vertical ? widget.slideSize.width : widget.slideSize.height;

  /// The pointer's layer-local position (strip gestures report global).
  Offset _layerLocal(Offset global) =>
      (context.findRenderObject()! as RenderBox).globalToLocal(global);

  bool _overRuler(SnapOrientation orientation, Offset local) =>
      (orientation == SnapOrientation.vertical ? local.dx : local.dy) < CanvasRuler.thickness;

  void _updateDrag(Offset global) {
    final drag = _drag;
    if (drag == null) return;
    final local = _layerLocal(global);
    final canvasPoint = widget.viewport.toCanvas(local);
    setState(
      () => _drag = (
        index: drag.index,
        orientation: drag.orientation,
        position: _overRuler(drag.orientation, local)
            ? null
            : (drag.orientation == SnapOrientation.vertical ? canvasPoint.dx : canvasPoint.dy),
      ),
    );
  }

  void _endDrag() {
    final drag = _drag;
    if (drag == null) return;
    setState(() => _drag = null);
    final position = drag.position;
    final guides = [...widget.guides];
    if (drag.index < 0) {
      // A creation drag released over the ruler places nothing.
      if (position == null) return;
      guides.add(
        ManualGuide(
          orientation: drag.orientation,
          position: _fraction(drag.orientation, position),
        ),
      );
    } else if (position == null) {
      guides.removeAt(drag.index);
    } else {
      guides[drag.index] = ManualGuide(
        orientation: drag.orientation,
        position: _fraction(drag.orientation, position),
      );
    }
    widget.onGuidesChanged(guides);
  }

  double _fraction(SnapOrientation orientation, double position) =>
      (position / _extentOf(orientation)).clamp(0.0, 1.0);

  /// The live canvas position of guide [index] (the drag preview wins).
  double _livePosition(int index) {
    final guide = widget.guides[index];
    final drag = _drag;
    if (drag != null && drag.index == index && drag.position != null) return drag.position!;
    return guide.position * _extentOf(guide.orientation);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewport,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: CustomPaint(size: Size.infinite, painter: _guidePainter(context)),
        ),
        for (var i = 0; i < widget.guides.length; i++) _guideStrip(i),
        _rulerStrip(Axis.horizontal),
        _rulerStrip(Axis.vertical),
      ],
    ),
  );
}
