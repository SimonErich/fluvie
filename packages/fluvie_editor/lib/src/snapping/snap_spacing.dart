part of 'snap_engine.dart';

/// The equal-spacing hints: when two or more candidates align with the
/// moving rect across the axis (a row for x, a column for y), the moving
/// rect can equalize the gaps — centered inside a pair's gap, or continuing
/// the sequence before or after it at the same gap. Three or more elements
/// end up equally spaced either way.
extension _SpacingCandidates on SnapEngine {
  /// Offers every spacing position along [orientation] for [moving] to
  /// [consider] (a candidate position paired with the moving feature it
  /// targets).
  void _forEachSpacing(
    SnapOrientation orientation,
    Rect moving,
    void Function(double position, double feature) consider,
  ) {
    final vertical = orientation == SnapOrientation.vertical;
    final crossStart = vertical ? moving.top : moving.left;
    final crossEnd = vertical ? moving.bottom : moving.right;
    final aligned = <Rect>[];
    for (final rect in _candidates) {
      final start = vertical ? rect.top : rect.left;
      final end = vertical ? rect.bottom : rect.right;
      if (start < crossEnd && crossStart < end) aligned.add(rect);
    }
    if (aligned.length < 2) return;
    aligned.sort(
      (a, b) => (vertical ? a.left : a.top).compareTo(vertical ? b.left : b.top),
    );
    final extent = vertical ? moving.width : moving.height;
    final movingStart = vertical ? moving.left : moving.top;
    final movingEnd = vertical ? moving.right : moving.bottom;
    final movingMid = (movingStart + movingEnd) / 2;
    for (var i = 0; i < aligned.length - 1; i++) {
      final first = aligned[i];
      final second = aligned[i + 1];
      final firstStart = vertical ? first.left : first.top;
      final firstEnd = vertical ? first.right : first.bottom;
      final secondStart = vertical ? second.left : second.top;
      final secondEnd = vertical ? second.right : second.bottom;
      final gap = secondStart - firstEnd;
      if (gap <= 0) continue;
      // Centered in the gap: equal space on both sides.
      if (gap >= extent) consider((firstEnd + secondStart) / 2, movingMid);
      // Continuing the sequence at the same gap, after and before the pair.
      consider(secondEnd + gap, movingStart);
      consider(firstStart - gap, movingEnd);
    }
  }
}
