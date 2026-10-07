part of 'guide_layer.dart';

/// The layer's interactive strips and painting: the two ruler strips (a
/// drag off one creates a guide) and the thin grab zones over each guide.
extension _GuideLayerStrips on _GuideLayerState {
  Widget _rulerStrip(Axis axis) {
    final orientation = axis == Axis.horizontal
        ? SnapOrientation.horizontal
        : SnapOrientation.vertical;
    return Positioned(
      left: 0,
      top: axis == Axis.horizontal ? 0 : CanvasRuler.thickness,
      right: axis == Axis.horizontal ? 0 : null,
      bottom: axis == Axis.horizontal ? null : 0,
      width: axis == Axis.horizontal ? null : CanvasRuler.thickness,
      height: axis == Axis.horizontal ? CanvasRuler.thickness : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // .down keeps the arena-winning motion: the first update carries the
        // whole delta since the press instead of being eaten as the start.
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (_) => _beginDrag(-1, orientation, null),
        onPanUpdate: (details) => _updateDrag(details.globalPosition),
        onPanEnd: (_) => _endDrag(),
        onPanCancel: _endDrag,
        child: CanvasRuler(axis: axis, viewport: widget.viewport),
      ),
    );
  }

  /// The 8px grab zone over guide [index], draggable along its axis.
  Widget _guideStrip(int index) {
    final guide = widget.guides[index];
    final vertical = guide.orientation == SnapOrientation.vertical;
    final canvasPosition = _livePosition(index);
    final viewportPosition = vertical
        ? widget.viewport.toViewport(Offset(canvasPosition, 0)).dx
        : widget.viewport.toViewport(Offset(0, canvasPosition)).dy;
    return Positioned(
      left: vertical ? viewportPosition - 4 : 0,
      top: vertical ? 0 : viewportPosition - 4,
      right: vertical ? null : 0,
      bottom: vertical ? 0 : null,
      width: vertical ? 8 : null,
      height: vertical ? null : 8,
      child: MouseRegion(
        cursor: vertical ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (_) => _beginDrag(index, guide.orientation, canvasPosition),
          onPanUpdate: (details) => _updateDrag(details.globalPosition),
          onPanEnd: (_) => _endDrag(),
          onPanCancel: _endDrag,
        ),
      ),
    );
  }

  /// The guide lines (live drag preview included) in viewport space.
  _GuidePainter _guidePainter(BuildContext context) {
    final vertical = <double>[];
    final horizontal = <double>[];
    void add(SnapOrientation orientation, double canvasPosition) {
      if (orientation == SnapOrientation.vertical) {
        vertical.add(widget.viewport.toViewport(Offset(canvasPosition, 0)).dx);
      } else {
        horizontal.add(widget.viewport.toViewport(Offset(0, canvasPosition)).dy);
      }
    }

    for (var i = 0; i < widget.guides.length; i++) {
      add(widget.guides[i].orientation, _livePosition(i));
    }
    final drag = _drag;
    if (drag != null && drag.index < 0 && drag.position != null) {
      add(drag.orientation, drag.position!);
    }
    return _GuidePainter(
      vertical: vertical,
      horizontal: horizontal,
      color: context.colors.accent.base.withValues(alpha: 0.7),
    );
  }
}

final class _GuidePainter extends CustomPainter {
  const _GuidePainter({required this.vertical, required this.horizontal, required this.color});

  final List<double> vertical;
  final List<double> horizontal;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final x in vertical) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (final y in horizontal) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) =>
      !listEquals(oldDelegate.vertical, vertical) ||
      !listEquals(oldDelegate.horizontal, horizontal) ||
      oldDelegate.color != color;
}
