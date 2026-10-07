part of 'gradient_editor.dart';

/// The handles' horizontal inset, so an edge stop's circle stays visible.
const double _handleInset = 8;

/// The bar's full hit box height (the strip plus handle room).
const double _barHeight = 36;

/// How far below the bar a dragged handle must travel to read as removal.
const double _removeBeyond = 24;

/// The stops bar: the live gradient strip with one draggable handle per
/// stop. Tap empty run to add, drag to move (committed on release), drag
/// past the bottom to remove.
final class _GradientStopsBar extends StatefulWidget {
  const _GradientStopsBar({
    required this.value,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
    required this.onPreview,
    required this.onCommit,
  });

  final GradientEditorValue value;
  final int selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<double> onAdd;
  final ValueChanged<GradientEditorValue> onPreview;
  final ValueChanged<GradientEditorValue?> onCommit;

  @override
  State<_GradientStopsBar> createState() => _GradientStopsBarState();
}

final class _GradientStopsBarState extends State<_GradientStopsBar> {
  int? _dragging;
  bool _removing = false;

  double _fractionAt(double dx, double width) =>
      ((dx - _handleInset) / (width - 2 * _handleInset)).clamp(0.0, 1.0);

  double _xOf(double offset, double width) => _handleInset + offset * (width - 2 * _handleInset);

  int? _hitStop(double dx, double width) {
    int? nearest;
    var nearestDistance = 10.0;
    for (final (i, stop) in widget.value.stops.indexed) {
      final distance = (dx - _xOf(stop.offset, width)).abs();
      if (distance <= nearestDistance) {
        nearest = i;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  void _tap(TapUpDetails details, double width) {
    final hit = _hitStop(details.localPosition.dx, width);
    if (hit != null) {
      widget.onSelect(hit);
    } else {
      widget.onAdd(_fractionAt(details.localPosition.dx, width));
    }
  }

  void _panStart(DragStartDetails details, double width) {
    final hit = _hitStop(details.localPosition.dx, width);
    _dragging = hit;
    _removing = false;
    if (hit != null) widget.onSelect(hit);
  }

  void _panUpdate(DragUpdateDetails details, double width) {
    final dragging = _dragging;
    if (dragging == null) return;
    setState(() => _removing = details.localPosition.dy > _barHeight + _removeBeyond);
    widget.onPreview(
      gradientStopMoved(widget.value, dragging, _fractionAt(details.localPosition.dx, width)),
    );
  }

  void _panEnd() {
    final dragging = _dragging;
    _dragging = null;
    if (dragging == null) return;
    if (_removing) {
      setState(() => _removing = false);
      widget.onCommit(gradientStopRemoved(widget.value, dragging));
      return;
    }
    widget.onCommit(widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The fixed-height box wraps the LayoutBuilder (not the other way
    // round), so intrinsic-height passes (golden tables) never reach it.
    return SizedBox(
      height: _barHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            key: const ValueKey('gradient-stops-bar'),
            behavior: HitTestBehavior.opaque,
            // Down, not start: the handle hit-test needs the press position,
            // before the touch slop swallows the first stretch of the drag.
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: (details) => _tap(details, width),
            onPanStart: (details) => _panStart(details, width),
            onPanUpdate: (details) => _panUpdate(details, width),
            onPanEnd: (_) => _panEnd(),
            onPanCancel: _panEnd,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: _handleInset,
                  right: _handleInset,
                  top: 8,
                  height: 20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: colors.borderSubtle),
                      gradient: LinearGradient(
                        colors: [for (final stop in widget.value.stops) stop.color],
                        stops: [for (final stop in widget.value.stops) stop.offset],
                      ),
                    ),
                  ),
                ),
                for (final (i, stop) in widget.value.stops.indexed)
                  Positioned(
                    key: ValueKey('gradient-stop-$i'),
                    left: _xOf(stop.offset, width) - 7,
                    top: 11,
                    width: 14,
                    height: 14,
                    child: Opacity(
                      opacity: _removing && _dragging == i ? 0.4 : 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: stop.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == widget.selected ? colors.accent.base : colors.border,
                            width: i == widget.selected ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
