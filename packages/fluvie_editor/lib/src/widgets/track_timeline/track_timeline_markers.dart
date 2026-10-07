part of 'track_timeline.dart';

// obers_ui upstream candidate (part of track_timeline.dart): ruler marker
// gestures — select, drag to move, drag off to remove, double tap to
// insert — falling back to the scrub everywhere else.

/// Pixels around a marker line that grab the marker instead of scrubbing.
const double _markerSlop = 4;

/// How far the pointer may leave the ruler strip vertically before a
/// dragged marker arms for removal.
const double _markerOffBand = 8;

/// One in-flight marker drag; leaving the ruler strip arms removal.
final class _MarkerDrag {
  _MarkerDrag(this.marker);

  final TimelineMarker marker;
  bool off = false;
}

extension _TrackTimelineMarkers on _TrackTimelineState {
  /// The frame under ruler pixel [dx], clamped to the timeline.
  double _frameAt(double dx) => ((dx + _scrollX) / _pixelsPerFrame).clamp(0.0, widget.totalFrames);

  void _scrubTo(double dx) => widget.navigation.onScrub?.call(_frameAt(dx));

  /// The marker whose line sits within [_markerSlop] of [dx], or `null`.
  TimelineMarker? _hitMarker(double dx) {
    final x = dx + _scrollX;
    for (final marker in widget.markers.reversed) {
      if ((x - marker.frame * _pixelsPerFrame).abs() <= _markerSlop) return marker;
    }
    return null;
  }

  /// A ruler tap: a marker selects, a double tap on empty space inserts a
  /// marker (the manual 350 ms check — a real double-tap recognizer would
  /// delay every scrub), anything else scrubs.
  void _rulerTapDown(Offset local) {
    // A shift-press belongs to the range gesture (or is a no-op): it never
    // scrubs, so a shift-drag's initial press cannot move the playhead.
    if (HardwareKeyboard.instance.isShiftPressed && widget.navigation.onRangeSelected != null) {
      return;
    }
    final marker = _hitMarker(local.dx);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (marker == null &&
        widget.overlays.onMarkerInserted != null &&
        now - _lastRulerTapMs < 350 &&
        (local.dx - _lastRulerTapDx).abs() <= 6) {
      _lastRulerTapMs = 0;
      final frame = ((local.dx + _scrollX) / _pixelsPerFrame).clamp(0.0, widget.totalFrames);
      widget.overlays.onMarkerInserted!(frame);
      return;
    }
    _lastRulerTapMs = now;
    _lastRulerTapDx = local.dx;
    if (marker != null) {
      // Focus the lanes so Delete can remove the selected marker.
      _lanesFocus.requestFocus();
      widget.overlays.onMarkerTapped?.call(marker.id);
      return;
    }
    _scrubTo(local.dx);
  }

  void _rulerDragStart(Offset local) {
    // Shift-drag selects a range — it beats markers and the scrub, so a
    // range can start on top of a marker line. The lanes take focus so
    // Escape can clear the selection right away.
    if (HardwareKeyboard.instance.isShiftPressed && widget.navigation.onRangeSelected != null) {
      _lanesFocus.requestFocus();
      _rangeDragAnchor = _frameAt(local.dx);
      return;
    }
    final marker = _hitMarker(local.dx);
    if (marker != null) {
      _markerDrag = _MarkerDrag(marker);
      widget.edit.onDragStarted?.call(marker.id);
      return;
    }
    _scrubTo(local.dx);
  }

  void _rulerDragUpdate(DragUpdateDetails details) {
    if (_rangeDragAnchor case final double anchor) {
      final other = _frameAt(details.localPosition.dx);
      widget.navigation.onRangeSelected!(math.min(anchor, other), math.max(anchor, other));
      return;
    }
    final drag = _markerDrag;
    if (drag == null) {
      _scrubTo(details.localPosition.dx);
      return;
    }
    drag.off =
        details.localPosition.dy < -_markerOffBand ||
        details.localPosition.dy > widget.appearance.rulerHeight + _markerOffBand;
    if (drag.off) return;
    final frame = ((details.localPosition.dx + _scrollX) / _pixelsPerFrame).clamp(
      0.0,
      widget.totalFrames,
    );
    widget.overlays.onMarkerMoved?.call(drag.marker.id, frame);
  }

  void _rulerDragEnd() {
    if (_rangeDragAnchor != null) {
      _rangeDragAnchor = null;
      return;
    }
    final drag = _markerDrag;
    if (drag == null) return;
    _markerDrag = null;
    if (drag.off) widget.overlays.onMarkerRemoved?.call(drag.marker.id);
    widget.edit.onDragEnded?.call(drag.marker.id);
  }
}
