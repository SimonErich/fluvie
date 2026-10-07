part of 'track_timeline.dart';

// obers_ui upstream candidate (part of track_timeline.dart): the lane
// surface — bar, diamond, link, and lane gestures over the painted lanes.

extension _TrackTimelineLanes on _TrackTimelineState {
  /// Pixels around a bar edge that grab the edge instead of the body.
  static const double _edgeSlop = 5;

  /// The ruler plus the painted lanes, sharing the horizontal scroll.
  Widget _lanes(BuildContext context, List<TimelineTrack> visible) {
    final colors = context.colors;
    final labelStyle = context.textTheme.caption.copyWith(
      color: colors.textSubtle,
      fontSize: 9,
      height: 1,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        _laneSize = Size(
          constraints.maxWidth,
          math.max(0, constraints.maxHeight - widget.appearance.rulerHeight),
        );
        _announceVisibleSpan();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ruler(context, labelStyle),
            Expanded(
              child: _TimelineLaneSurface(
                state: this,
                visible: visible,
                colors: colors,
                labelStyle: labelStyle,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Whether a modifier asked to add to the selection rather than replace it.
  static bool get _additiveHeld =>
      HardwareKeyboard.instance.isShiftPressed ||
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;

  /// Whether Shift asked a rubber band to extend rather than replace.
  static bool get _shiftHeld => HardwareKeyboard.instance.isShiftPressed;

  void _laneTap(Offset local, List<TimelineTrack> visible) {
    _lanesFocus.requestFocus();
    final diamond = _hitDiamond(local, visible);
    if (diamond != null) {
      widget.overlays.onDiamondTapped?.call(diamond.bar.id, diamond.diamond.id);
      return;
    }
    if (!_insideTrimZone(local, visible)) {
      final link = _hitLink(local, visible);
      if (link != null) {
        widget.overlays.onLinkTapped?.call(link.id);
        return;
      }
    }
    final hit = _hitBar(local, visible);
    if (hit != null) {
      widget.navigation.onBarTapped?.call(hit.bar.id, additive: _additiveHeld);
      final curve = hit.bar.easing;
      final row = _rows.rowAt(local.dy + _scrollY);
      final width = hit.bar.durationFrames * _pixelsPerFrame - 6;
      if (curve != null && row != null && width >= 18 && hit.mode == _DragMode.move) {
        final left = hit.bar.start * _pixelsPerFrame - _scrollX + 3;
        final top = _rows.topOf(row) - _scrollY + 7;
        final height = _rows.heightOf(row) - 14;
        final t = ((local.dx - left) / width).clamp(0.0, 1.0);
        final y = top + height * (1 - curve.transform(t));
        if ((local.dy - y).abs() <= 5) widget.edit.onEasingTapped?.call(hit.bar.id);
      }
      return;
    }
    final row = _rows.rowAt(local.dy + _scrollY);
    if (row == null) return;
    final frame = ((local.dx + _scrollX) / _pixelsPerFrame).clamp(0.0, widget.totalFrames);
    widget.navigation.onTrackTapped?.call(visible[row].id, frame);
  }

  void _dragStart(Offset local, List<TimelineTrack> visible) {
    final handleBar = _hitLinkHandle(local, visible);
    if (handleBar != null) {
      _rebuild(() => _linkDrag = _LinkDrag(bar: handleBar, point: local));
      return;
    }
    final diamond = _hitDiamond(local, visible);
    if (diamond != null) {
      _drag = _BarDrag(bar: diamond.bar, mode: _DragMode.diamond, diamond: diamond.diamond);
      widget.edit.onDragStarted?.call(diamond.diamond.id);
      return;
    }
    final hit = _hitBar(local, visible);
    if (hit == null) {
      _drag = null;
      _marqueeAnchor = local;
      _rebuild(() => _marquee = Rect.fromPoints(local, local));
      return;
    }
    _drag = _BarDrag(bar: hit.bar, mode: hit.mode);
    widget.edit.onDragStarted?.call(hit.bar.id);
  }

  void _dragUpdate(DragUpdateDetails details, List<TimelineTrack> visible) {
    final linkDrag = _linkDrag;
    if (linkDrag != null) {
      _rebuild(() => _linkDrag = _LinkDrag(bar: linkDrag.bar, point: details.localPosition));
      return;
    }
    final anchor = _marqueeAnchor;
    if (anchor != null) {
      _rebuild(() => _marquee = Rect.fromPoints(anchor, details.localPosition));
      return;
    }
    final drag = _drag;
    if (drag == null) return;
    drag.travelled += details.delta.dx;
    final bar = drag.bar;
    final delta = drag.travelled / _pixelsPerFrame;
    switch (drag.mode) {
      case _DragMode.move:
        widget.edit.onBarMoved?.call(
          bar.id,
          math.max(0, bar.start + delta),
          _laneUnder(details.localPosition.dy, visible),
        );
      case _DragMode.resizeStart:
        final newStart = (bar.start + delta).clamp(0.0, bar.end - 1);
        widget.edit.onBarResized?.call(bar.id, newStart, bar.end);
      case _DragMode.resizeEnd:
        final newEnd = math.max(bar.start + 1, bar.end + delta);
        widget.edit.onBarResized?.call(bar.id, bar.start, newEnd);
      case _DragMode.diamond:
        final diamond = drag.diamond!;
        final frame = (diamond.frame + delta).clamp(bar.start, bar.end);
        widget.overlays.onDiamondMoved?.call(bar.id, diamond.id, frame);
    }
  }

  void _dragEnd(List<TimelineTrack> visible) {
    final linkDrag = _linkDrag;
    if (linkDrag != null) {
      _rebuild(() => _linkDrag = null);
      final target = _hitBar(linkDrag.point, visible);
      if (target != null && target.bar.id != linkDrag.bar.id) {
        widget.overlays.onLinkDropped?.call(linkDrag.bar.id, target.bar.id);
      }
      return;
    }
    final band = _marquee;
    if (band != null) {
      _marqueeAnchor = null;
      _rebuild(() => _marquee = null);
      widget.navigation.onBarsMarqueed?.call(_barsIn(band, visible), additive: _shiftHeld);
      return;
    }
    final drag = _drag;
    if (drag == null) return;
    _drag = null;
    widget.edit.onDragEnded?.call(drag.dragId);
  }
}
