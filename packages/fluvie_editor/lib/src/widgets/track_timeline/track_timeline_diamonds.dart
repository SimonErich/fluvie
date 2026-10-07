part of 'track_timeline.dart';

// obers_ui upstream candidate (part of track_timeline.dart): diamond
// markers — hit testing, keyboard deletion, and painting.

/// Pixels around a diamond center that grab the diamond before the bar.
const double _diamondSlop = 6;

/// A diamond hit: the bar it rides and the diamond itself.
final class _DiamondHit {
  const _DiamondHit({required this.bar, required this.diamond});

  final TimelineBar bar;
  final TimelineDiamond diamond;
}

extension _TrackTimelineDiamonds on _TrackTimelineState {
  /// The grabbable diamond under [local], or `null` — checked before every
  /// bar grab.
  ///
  /// Priority against the bar's own zones: over the bar body a diamond
  /// always wins; strictly *inside* an edge's trim zone the edge keeps its
  /// grab (zoom in to reach a stop parked next to the edge); on or beyond
  /// the boundary pixel a boundary stop wins over the edge.
  _DiamondHit? _hitDiamond(Offset local, List<TimelineTrack> visible) {
    final row = _rows.rowAt(local.dy + _scrollY);
    if (row == null) return null;
    final x = local.dx + _scrollX;
    for (final bar in visible[row].bars.reversed) {
      const trim = _TrackTimelineLanes._edgeSlop;
      final startPx = bar.start * _pixelsPerFrame;
      final endPx = bar.end * _pixelsPerFrame;
      final insideTrimZone =
          (x > startPx && x <= startPx + trim) || (x < endPx && x >= endPx - trim);
      if (insideTrimZone) continue;
      for (final diamond in bar.diamonds.reversed) {
        if ((x - diamond.frame * _pixelsPerFrame).abs() <= _diamondSlop) {
          return _DiamondHit(bar: bar, diamond: diamond);
        }
      }
    }
    return null;
  }

  /// Delete/Backspace removes the host-selected diamond, then marker, then
  /// link, and Escape clears the range selection, while the lanes hold
  /// focus; every other key passes through.
  KeyEventResult _onLanesKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.selection.rangeSelection == null || widget.navigation.onRangeCleared == null) {
        return KeyEventResult.ignored;
      }
      widget.navigation.onRangeCleared!();
      return KeyEventResult.handled;
    }
    final isDelete =
        event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace;
    if (!isDelete) return KeyEventResult.ignored;
    final selected = widget.selection.selectedDiamondId;
    if (selected != null) {
      for (final track in widget.tracks) {
        for (final bar in track.bars) {
          for (final diamond in bar.diamonds) {
            if (diamond.id == selected) {
              widget.overlays.onDiamondDeleted?.call(bar.id, diamond.id);
              return KeyEventResult.handled;
            }
          }
        }
      }
      return KeyEventResult.ignored;
    }
    final marker = widget.selection.selectedMarkerId;
    if (marker != null && widget.markers.any((m) => m.id == marker)) {
      widget.overlays.onMarkerRemoved?.call(marker);
      return KeyEventResult.handled;
    }
    final link = widget.selection.selectedLinkId;
    if (link != null && widget.links.any((l) => l.id == link)) {
      widget.overlays.onLinkDeleted?.call(link);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

/// Paints one diamond centered on [center]: a rotated square with an
/// outline, drawn larger in the selected state.
void _paintDiamond(
  Canvas canvas,
  Offset center, {
  required bool selected,
  required Color fill,
  required Color selectedFill,
  required Color outline,
}) {
  final half = selected ? 5.0 : 3.5;
  final path = Path()
    ..moveTo(center.dx, center.dy - half)
    ..lineTo(center.dx + half, center.dy)
    ..lineTo(center.dx, center.dy + half)
    ..lineTo(center.dx - half, center.dy)
    ..close();
  canvas
    ..drawPath(path, Paint()..color = selected ? selectedFill : fill)
    ..drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = outline,
    );
}
