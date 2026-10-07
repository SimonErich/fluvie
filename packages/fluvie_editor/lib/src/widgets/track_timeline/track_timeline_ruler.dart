part of 'track_timeline.dart';

// obers_ui upstream candidate (part of track_timeline.dart): the ruler
// strip — its gesture surface and the seconds painter with markers.

extension _TrackTimelineRuler on _TrackTimelineState {
  /// The ruler strip: seconds ticks, markers, the playhead handle, and the
  /// scrub/marker gestures.
  Widget _ruler(BuildContext context, TextStyle labelStyle) {
    final colors = context.colors;
    return SizedBox(
      height: widget.appearance.rulerHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onTapDown: (details) => _rulerTapDown(details.localPosition),
        onHorizontalDragStart: (details) => _rulerDragStart(details.localPosition),
        onHorizontalDragUpdate: _rulerDragUpdate,
        onHorizontalDragEnd: (_) => _rulerDragEnd(),
        onHorizontalDragCancel: _rulerDragEnd,
        child: ClipRect(
          child: CustomPaint(
            size: Size.infinite,
            painter: _RulerPainter(
              scrollX: _scrollX,
              pixelsPerFrame: _pixelsPerFrame,
              fps: widget.fps,
              totalFrames: widget.totalFrames,
              playhead: widget.playhead,
              range: widget.selection.rangeSelection,
              markers: widget.markers,
              selectedMarkerId: widget.selection.selectedMarkerId,
              background: colors.surface,
              tick: colors.textSubtle,
              playheadColor: colors.accent.base,
              markerColor: colors.info.base,
              labelStyle: labelStyle,
            ),
          ),
        ),
      ),
    );
  }
}
