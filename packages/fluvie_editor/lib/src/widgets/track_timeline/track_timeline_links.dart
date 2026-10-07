part of 'track_timeline.dart';

// obers_ui upstream candidate (part of track_timeline.dart): link
// connectors — geometry, hit testing, the drag handle, and painting.

/// Pixels around a connector line that grab the link.
const double _linkSlop = 4;

/// Half the size of the square zone the link handle occupies at a bar's
/// top-center.
const double _handleSlop = 5;

/// One in-flight link-creation drag: the source bar and the pointer's
/// lane-local position.
final class _LinkDrag {
  const _LinkDrag({required this.bar, required this.point});

  final TimelineBar bar;
  final Offset point;
}

extension _TrackTimelineLinks on _TrackTimelineState {
  /// The bar whose link handle sits under [local], or `null`. The handle is
  /// a small zone at the bar's top-center — never inside the edge trim
  /// zones (the bar must be at least 24 px wide) and above the diamonds'
  /// row-center band. Only live when the host listens for drops.
  TimelineBar? _hitLinkHandle(Offset local, List<TimelineTrack> visible) {
    if (widget.overlays.onLinkDropped == null) return null;
    final row = _rows.rowAt(local.dy + _scrollY);
    if (row == null) return null;
    final x = local.dx + _scrollX;
    final y = local.dy + _scrollY - _rows.topOf(row);
    for (final bar in visible[row].bars.reversed) {
      if ((bar.end - bar.start) * _pixelsPerFrame < 24) continue;
      final center = (bar.start + bar.end) / 2 * _pixelsPerFrame;
      if ((x - center).abs() <= _handleSlop && (y - 4).abs() <= _handleSlop) return bar;
    }
    return null;
  }

  /// The link whose connector runs under [local], or `null`.
  TimelineLink? _hitLink(Offset local, List<TimelineTrack> visible) {
    final point = Offset(local.dx + _scrollX, local.dy + _scrollY);
    for (final link in widget.links.reversed) {
      final points = _linkPolyline(link, visible, _pixelsPerFrame, _rows);
      if (points == null) continue;
      for (var i = 0; i < points.length - 1; i++) {
        if (_segmentDistance(point, points[i], points[i + 1]) <= _linkSlop) return link;
      }
    }
    return null;
  }
}

/// The connector polyline of [link] in unscrolled lane coordinates, ending
/// at the source bar's start edge, or `null` when either bar is hidden.
List<Offset>? _linkPolyline(
  TimelineLink link,
  List<TimelineTrack> visible,
  double pixelsPerFrame,
  TimelineLaneRows rows,
) {
  final from = _barPosition(link.fromBarId, visible);
  final to = _barPosition(link.toBarId, visible);
  if (from == null || to == null) return null;
  final sx = from.bar.start * pixelsPerFrame;
  final sy = rows.topOf(from.row) + rows.heightOf(from.row) / 2;
  final tx = (link.toEdge == TimelineLinkEdge.end ? to.bar.end : to.bar.start) * pixelsPerFrame;
  final ty = rows.topOf(to.row) + rows.heightOf(to.row) / 2;
  if (from.row == to.row) {
    if (tx <= sx - 8) return [Offset(tx, ty), Offset(sx, sy)];
    final top = rows.topOf(from.row) + 3.0;
    return [Offset(tx, ty), Offset(tx, top), Offset(sx, top), Offset(sx, sy)];
  }
  return [Offset(tx, ty), Offset(tx, sy), Offset(sx, sy)];
}

/// The handle center of [bar] on row [row], in unscrolled lane coordinates.
Offset _handleCenter(TimelineBar bar, int row, double pixelsPerFrame, TimelineLaneRows rows) =>
    Offset((bar.start + bar.end) / 2 * pixelsPerFrame, rows.topOf(row) + 4);

({TimelineBar bar, int row})? _barPosition(String barId, List<TimelineTrack> visible) {
  for (var row = 0; row < visible.length; row++) {
    for (final bar in visible[row].bars) {
      if (bar.id == barId) return (bar: bar, row: row);
    }
  }
  return null;
}

/// The distance from [point] to the segment [a]..[b].
double _segmentDistance(Offset point, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
  if (lengthSquared == 0) return (point - a).distance;
  final t = (((point - a).dx * ab.dx + (point - a).dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
  return (point - (a + ab * t)).distance;
}

/// Paints every visible link connector: the polyline, an arrowhead into the
/// source bar, and the optional label beside the first bend. The selected
/// link draws thicker.
void _paintLinks(
  Canvas canvas, {
  required List<TimelineLink> links,
  required List<TimelineTrack> tracks,
  required String? selectedLinkId,
  required double pixelsPerFrame,
  required TimelineLaneRows rows,
  required Offset scroll,
  required TextStyle labelStyle,
}) {
  for (final link in links) {
    final points = _linkPolyline(link, tracks, pixelsPerFrame, rows);
    if (points == null) continue;
    final selected = link.id == selectedLinkId;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2.5 : 1.5
      ..color = link.color;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i] - scroll;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
    _paintArrowhead(canvas, points[points.length - 2] - scroll, points.last - scroll, link.color);
    final label = link.label;
    if (label != null) {
      final anchor = points.first - scroll;
      TextPainter(
          text: TextSpan(
            text: label,
            style: labelStyle.copyWith(color: link.color),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )
        ..layout()
        ..paint(canvas, anchor + const Offset(3, 3))
        ..dispose();
    }
  }
}

/// A small triangle at [tip] pointing along the segment [from]..[tip].
void _paintArrowhead(Canvas canvas, Offset from, Offset tip, Color color) {
  final direction = tip - from;
  final unit = direction.distance == 0 ? const Offset(1, 0) : direction / direction.distance;
  final normal = Offset(-unit.dy, unit.dx);
  final base = tip - unit * 5;
  canvas.drawPath(
    Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + normal.dx * 3, base.dy + normal.dy * 3)
      ..lineTo(base.dx - normal.dx * 3, base.dy - normal.dy * 3)
      ..close(),
    Paint()..color = color,
  );
}

/// Paints the link handle on [bar] (a ring at its top-center) and, mid
/// drag, the rubber band from the handle to the pointer.
void _paintLinkHandle(
  Canvas canvas, {
  required TimelineBar bar,
  required int row,
  required double pixelsPerFrame,
  required TimelineLaneRows rows,
  required Offset scroll,
  required Offset? dragPoint,
  required Color color,
  required Color fill,
}) {
  final center = _handleCenter(bar, row, pixelsPerFrame, rows) - scroll;
  if (dragPoint != null) {
    canvas
      ..drawLine(
        center,
        dragPoint,
        Paint()
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: 0.8),
      )
      ..drawCircle(dragPoint, 3, Paint()..color = color);
  }
  canvas
    ..drawCircle(center, 4, Paint()..color = fill)
    ..drawCircle(
      center,
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color,
    );
}
