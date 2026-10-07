import 'package:fluvie_editor/src/widgets/track_timeline/timeline_track.dart';

// obers_ui upstream candidate: the row geometry of a multi-track timeline.

/// Where each lane row sits, given lanes that may each set their own height.
///
/// One answer for every surface that asks it: the labels column, the lane
/// painter, the hit test and the drag targeting all read here, so they cannot
/// disagree about where a row starts. Computed once per build — the tops are
/// a running sum, so asking is a lookup rather than a walk.
final class TimelineLaneRows {
  /// The rows of [tracks], each as tall as it asks or [defaultHeight].
  TimelineLaneRows({required List<TimelineTrack> tracks, required double defaultHeight})
    : _heights = [for (final track in tracks) track.height ?? defaultHeight],
      _tops = List.filled(tracks.length + 1, 0) {
    for (var i = 0; i < _heights.length; i++) {
      _tops[i + 1] = _tops[i] + _heights[i];
    }
  }

  final List<double> _heights;
  final List<double> _tops;

  /// How many rows there are.
  int get length => _heights.length;

  /// Row [row]'s height.
  double heightOf(int row) => _heights[row];

  /// Row [row]'s top edge, measured from the first row.
  double topOf(int row) => _tops[row];

  /// How tall every row is together.
  double get totalHeight => _tops.last;

  /// The row holding [y], or null above the first row and below the last.
  int? rowAt(double y) {
    if (y < 0 || y >= totalHeight) return null;
    for (var row = 0; row < _heights.length; row++) {
      if (y < _tops[row + 1]) return row;
    }
    return null;
  }

  /// The row holding [y], clamped to the first or last row past the ends.
  ///
  /// Where [rowAt] answers "which row is this", this answers "which row does
  /// the pointer mean": a drag off the top of the lanes is unambiguously aimed
  /// at the topmost one.
  int clampedRowAt(double y) => rowAt(y) ?? (y < 0 ? 0 : _heights.length - 1);

  /// The first and last row a viewport [height] tall scrolled to [scrollY]
  /// touches, or null when there are no rows at all.
  ///
  /// What makes a long project cost what the screen costs rather than what the
  /// document costs: the rows outside this range are never built or painted.
  ({int first, int last})? visibleRange(double scrollY, double height) {
    if (_heights.isEmpty) return null;
    final last = _heights.length - 1;
    return (
      first: rowAt(scrollY) ?? (scrollY < 0 ? 0 : last),
      last: rowAt(scrollY + height) ?? (scrollY + height < 0 ? 0 : last),
    );
  }
}
