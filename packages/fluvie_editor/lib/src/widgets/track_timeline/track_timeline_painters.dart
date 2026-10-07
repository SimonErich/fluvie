part of 'track_timeline.dart';

// obers_ui upstream candidate (part of track_timeline.dart): the lanes
// painter.

/// The lanes: row separators, phase-colored bars with easing sketches,
/// badges, diamonds, and violation outlines, link connectors, marker lines,
/// the beyond-the-end shade, and the playhead line.
final class _LanesPainter extends CustomPainter {
  _LanesPainter({
    required this.tracks,
    required this.selectedTrackIds,
    required this.selectedBarIds,
    required this.marquee,
    required this.rows,
    required this.pixelsPerFrame,
    required this.scrollX,
    required this.scrollY,
    required this.totalFrames,
    required this.playhead,
    required this.range,
    required this.snapFrame,
    required this.overlays,
    required this.background,
    required this.rowLine,
    required this.detail,
    required this.playheadColor,
    required this.selectionFill,
    required this.snapColor,
    required this.violationColor,
    required this.endShade,
    required this.badgeStyle,
    required this.snapPulse,
  }) : super(repaint: snapPulse);

  final List<TimelineTrack> tracks;
  final Set<String> selectedTrackIds;
  final Set<String> selectedBarIds;
  final Rect? marquee;
  final TimelineLaneRows rows;
  final double pixelsPerFrame;
  final double scrollX;
  final double scrollY;
  final double totalFrames;
  final double playhead;
  final ({double start, double end})? range;
  final double? snapFrame;
  final _LaneOverlays overlays;
  final Color background;
  final Color rowLine;
  final Color detail;
  final Color playheadColor;
  final Color selectionFill;
  final Color snapColor;
  final Color violationColor;
  final Color endShade;
  final TextStyle badgeStyle;

  /// The guide's flash: one at rest, zero at the start of a fresh catch.
  final Animation<double> snapPulse;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final line = Paint()
      ..color = rowLine
      ..strokeWidth = 1;
    // Only the rows the viewport crosses: a long project costs what the
    // screen costs rather than what the document holds.
    final band = rows.visibleRange(scrollY, size.height);
    for (var i = band?.first ?? 0; band != null && i <= band.last; i++) {
      final top = rows.topOf(i) - scrollY;
      final height = rows.heightOf(i);
      if (selectedTrackIds.contains(tracks[i].id)) {
        canvas.drawRect(Rect.fromLTWH(0, top, size.width, height), Paint()..color = selectionFill);
      }
      canvas.drawLine(Offset(0, top + height), Offset(size.width, top + height), line);
      for (final bar in tracks[i].bars) {
        _bar(canvas, size, bar, top, height);
      }
      _envelope(canvas, size, tracks[i], top, height);
    }
    overlays.paintOver(
      canvas,
      size,
      tracks: tracks,
      pixelsPerFrame: pixelsPerFrame,
      rows: rows,
      scroll: Offset(scrollX, scrollY),
      detail: detail,
      accent: playheadColor,
      background: background,
      labelStyle: badgeStyle,
    );
    final endX = totalFrames * pixelsPerFrame - scrollX;
    if (endX < size.width) {
      canvas.drawRect(
        Rect.fromLTRB(math.max(0, endX), 0, size.width, size.height),
        Paint()..color = endShade,
      );
    }
    if (range case final selected?) {
      final left = selected.start * pixelsPerFrame - scrollX;
      final right = selected.end * pixelsPerFrame - scrollX;
      if (right >= 0 && left <= size.width) {
        canvas.drawRect(
          Rect.fromLTRB(math.max(0, left), 0, math.min(size.width, right), size.height),
          Paint()..color = playheadColor.withValues(alpha: 0.1),
        );
      }
    }
    if (marquee case final band?) {
      canvas
        ..drawRect(band, Paint()..color = selectionFill)
        ..drawRect(
          band,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = playheadColor,
        );
    }
    if (snapFrame case final frame?) {
      // Under the playhead, never over it: the playhead is where you are and
      // the guide is only where a drag would land. It is deliberately not the
      // accent colour either — two amber hairlines a few frames apart are one
      // hairline as far as the eye is concerned.
      final snapX = frame * pixelsPerFrame - scrollX;
      if (snapX >= 0 && snapX <= size.width) {
        // A fresh catch flashes wider and fades to a hairline, the same brief
        // announcement the canvas guides make.
        final width = 1 + 2 * (1 - snapPulse.value);
        canvas.drawRect(
          Rect.fromLTWH(snapX - width / 2, 0, width, size.height),
          Paint()..color = snapColor,
        );
      }
    }
    final x = playhead * pixelsPerFrame - scrollX;
    if (x >= 0 && x <= size.width) {
      canvas.drawRect(Rect.fromLTWH(x - 0.5, 0, 1, size.height), Paint()..color = playheadColor);
    }
  }

  @override
  bool shouldRepaint(_LanesPainter oldDelegate) =>
      oldDelegate.tracks != tracks ||
      !setEquals(oldDelegate.selectedTrackIds, selectedTrackIds) ||
      !setEquals(oldDelegate.selectedBarIds, selectedBarIds) ||
      oldDelegate.marquee != marquee ||
      oldDelegate.selectionFill != selectionFill ||
      oldDelegate.rows != rows ||
      oldDelegate.pixelsPerFrame != pixelsPerFrame ||
      oldDelegate.scrollX != scrollX ||
      oldDelegate.scrollY != scrollY ||
      oldDelegate.totalFrames != totalFrames ||
      oldDelegate.playhead != playhead ||
      oldDelegate.range != range ||
      oldDelegate.snapFrame != snapFrame ||
      oldDelegate.snapColor != snapColor ||
      oldDelegate.overlays != overlays ||
      oldDelegate.background != background ||
      oldDelegate.rowLine != rowLine ||
      oldDelegate.detail != detail ||
      oldDelegate.playheadColor != playheadColor ||
      oldDelegate.violationColor != violationColor ||
      oldDelegate.endShade != endShade ||
      oldDelegate.badgeStyle != badgeStyle;
}
