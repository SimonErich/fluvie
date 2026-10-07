part of 'track_timeline.dart';

/// Reads lane viewport geometry and reports the lazy visible frame span.
extension _TrackTimelineLaneGeometry on _TrackTimelineState {
  static const double _edgeSlop = _TrackTimelineLanes._edgeSlop;

  /// A payload from outside the timeline dropped on the lanes: reads the
  /// pointer through the lanes' own geometry, so a host hears the same bar
  /// and frame a tap there would name.
  void _foreignDrop(DragTargetDetails<Object> details, List<TimelineTrack> visible) {
    final box = _lanesFocus.context?.findRenderObject();
    if (box is! RenderBox) return;
    final local = box.globalToLocal(details.offset);
    final frame = ((local.dx + _scrollX) / _pixelsPerFrame).clamp(0.0, widget.totalFrames);
    final row = _rows.rowAt(local.dy + _scrollY);
    if (row == null) return;
    final barId = _hitBar(local, visible)?.bar.id;
    if (widget.edit.onForeignLaneDrop case final callback?) {
      callback(details.data, visible[row].id, barId, frame);
    } else {
      widget.edit.onForeignDrop?.call(details.data, barId, frame);
    }
  }

  /// Tells the host which frames the lanes can show, once per change.
  ///
  /// Reported from layout rather than from build, because it is the width and
  /// the zoom together that decide it, and a host that heard the same span
  /// twice would decode it twice.
  void _announceVisibleSpan() {
    final listener = widget.onFilmstripNeeded;
    if (listener == null || _pixelsPerFrame <= 0) return;
    final from = (_scrollX / _pixelsPerFrame).floor().clamp(0, widget.totalFrames.floor());
    final to = ((_scrollX + _laneSize.width) / _pixelsPerFrame).ceil().clamp(
      from,
      widget.totalFrames.ceil(),
    );
    if (_announcedSpan?.from == from && _announcedSpan?.to == to) return;
    _announcedSpan = (from: from, to: to);
    // After the frame: layout is no place to call a host that will rebuild us.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) listener(from, to);
    });
  }

  void _hover(Offset? local, List<TimelineTrack> visible) {
    final id = local == null ? null : _hitBar(local, visible)?.bar.id;
    if (id != _hoverBarId) _rebuild(() => _hoverBarId = id);
  }

  /// The bar (and grab mode) under [local], or `null` over empty lane space.
  _BarHit? _hitBar(Offset local, List<TimelineTrack> visible) {
    final row = _rows.rowAt(local.dy + _scrollY);
    if (row == null) return null;
    final track = visible[row];
    final x = local.dx + _scrollX;
    for (final bar in track.bars.reversed) {
      final startPx = bar.start * _pixelsPerFrame;
      final endPx = bar.end * _pixelsPerFrame;
      if (x < startPx - _edgeSlop || x > endPx + _edgeSlop) continue;
      final _DragMode mode;
      if (x <= startPx + _edgeSlop) {
        mode = _DragMode.resizeStart;
      } else if (x >= endPx - _edgeSlop) {
        mode = _DragMode.resizeEnd;
      } else {
        mode = _DragMode.move;
      }
      return _BarHit(track: track, bar: bar, mode: mode);
    }
    return null;
  }

  /// The id of the lane at local [dy], clamped to the first and last rows.
  ///
  /// Clamping rather than refusing: a pointer dragged off the top of the
  /// lanes is unambiguously aimed at the topmost one, and returning the source
  /// lane there would make the bar snap back under a pointer that never left.
  String _laneUnder(double dy, List<TimelineTrack> visible) =>
      visible[_rows.clampedRowAt(dy + _scrollY)].id;

  /// Every bar [band] (in lane-local pixels) touches.
  ///
  /// Touching is enough: a band has to swallow nothing, because an author
  /// sweeping across a row means the rows they swept, not the bars that
  /// happened to fit entirely inside the sweep.
  Set<String> _barsIn(Rect band, List<TimelineTrack> visible) {
    final ids = <String>{};
    for (var row = 0; row < visible.length; row++) {
      final top = _rows.topOf(row) - _scrollY;
      if (top > band.bottom || top + _rows.heightOf(row) < band.top) continue;
      for (final bar in visible[row].bars) {
        final left = bar.start * _pixelsPerFrame - _scrollX;
        final right = bar.end * _pixelsPerFrame - _scrollX;
        if (left <= band.right && right >= band.left) ids.add(bar.id);
      }
    }
    return ids;
  }

  /// Whether [local] sits strictly inside any bar's trim zone — where the
  /// edge keeps its priority over diamonds and links alike.
  bool _insideTrimZone(Offset local, List<TimelineTrack> visible) {
    final hit = _hitBar(local, visible);
    return hit != null && hit.mode != _DragMode.move;
  }
}
