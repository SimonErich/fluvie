part of 'track_timeline.dart';

// obers_ui upstream candidate (part of track_timeline.dart): the overlay
// model the lanes paint over their bars, and its paint layer.

/// The overlay state of the lanes: links, marker lines, the selected
/// diamond and link, the hovered bar's link handle, and the in-flight link
/// drag. A value, so the painter can compare it in `shouldRepaint`.
@immutable
final class _LaneOverlays {
  const _LaneOverlays({
    required this.links,
    required this.markers,
    required this.selectedDiamondId,
    required this.selectedLinkId,
    required this.hoverBarId,
    required this.linkDragBarId,
    required this.linkDragPoint,
  });

  final List<TimelineLink> links;
  final List<TimelineMarker> markers;
  final String? selectedDiamondId;
  final String? selectedLinkId;
  final String? hoverBarId;
  final String? linkDragBarId;
  final Offset? linkDragPoint;

  /// Marker lines, link connectors, and the link handle, over the bars.
  void paintOver(
    Canvas canvas,
    Size size, {
    required List<TimelineTrack> tracks,
    required double pixelsPerFrame,
    required TimelineLaneRows rows,
    required Offset scroll,
    required Color detail,
    required Color accent,
    required Color background,
    required TextStyle labelStyle,
  }) {
    final markerPaint = Paint()..color = detail.withValues(alpha: 0.3);
    for (final marker in markers) {
      final x = marker.frame * pixelsPerFrame - scroll.dx;
      if (x < -1 || x > size.width + 1) continue;
      canvas.drawRect(Rect.fromLTWH(x - 0.5, 0, 1, size.height), markerPaint);
    }
    _paintLinks(
      canvas,
      links: links,
      tracks: tracks,
      selectedLinkId: selectedLinkId,
      pixelsPerFrame: pixelsPerFrame,
      rows: rows,
      scroll: scroll,
      labelStyle: labelStyle,
    );
    final handleBarId = linkDragBarId ?? hoverBarId;
    if (handleBarId == null) return;
    final position = _barPosition(handleBarId, tracks);
    if (position == null || (position.bar.end - position.bar.start) * pixelsPerFrame < 24) return;
    _paintLinkHandle(
      canvas,
      bar: position.bar,
      row: position.row,
      pixelsPerFrame: pixelsPerFrame,
      rows: rows,
      scroll: scroll,
      dragPoint: linkDragBarId == null ? null : linkDragPoint,
      color: accent,
      fill: background,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _LaneOverlays &&
      listEquals(other.links, links) &&
      listEquals(other.markers, markers) &&
      other.selectedDiamondId == selectedDiamondId &&
      other.selectedLinkId == selectedLinkId &&
      other.hoverBarId == hoverBarId &&
      other.linkDragBarId == linkDragBarId &&
      other.linkDragPoint == linkDragPoint;

  @override
  int get hashCode => Object.hash(
    _LaneOverlays,
    Object.hashAll(links),
    Object.hashAll(markers),
    selectedDiamondId,
    selectedLinkId,
    hoverBarId,
    linkDragBarId,
    linkDragPoint,
  );
}
