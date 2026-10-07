import 'dart:ui' show Offset, Rect, Size;

import 'package:fluvie_editor/src/snapping/manual_guide.dart';
import 'package:fluvie_editor/src/snapping/snap_line.dart';
import 'package:fluvie_editor/src/snapping/snap_result.dart';

export 'package:fluvie_editor/src/snapping/snap_result.dart';

part 'snap_spacing.dart';

// obers_ui upstream candidate: a pure, framework-free snapping engine any
// canvas editor can feed rects into.

/// A candidate line: its position, what it is, and which moving-rect
/// features it matches (bit 1 the edges, bit 2 the center).
typedef _Candidate = ({double position, SnapKind kind, int features});

/// The pure snapping math of one gesture: built at pointer-down from the
/// non-dragged elements' rects, the slide, the manual guides, and the
/// optional grid, then asked per pointer update.
///
/// All positions are canvas pixels ([tolerance] included — divide a
/// screen-pixel tolerance by the zoom). Everything works on unrotated
/// layout rects, the same rects the gizmo and the geometry use. The
/// nearest candidate wins; on an exact tie the earlier one in evaluation
/// order does (guides, slide, elements in z-order, spacing, grid).
final class SnapEngine {
  /// An engine over [slide] with the other elements' [candidates] (z-order,
  /// a group is one rect), the slide's [guides], and an optional grid every
  /// [gridSpacing] canvas pixels.
  SnapEngine({
    required Size slide,
    List<Rect> candidates = const [],
    List<ManualGuide> guides = const [],
    this.gridSpacing,
    this.tolerance = defaultTolerance,
  }) : _candidates = candidates,
       _vertical = _linesFor(SnapOrientation.vertical, slide, candidates, guides),
       _horizontal = _linesFor(SnapOrientation.horizontal, slide, candidates, guides);

  /// The default snap distance in canvas pixels at zoom 1.
  static const double defaultTolerance = 6;

  /// How close (canvas pixels) a candidate must be to snap.
  final double tolerance;

  /// The grid step in canvas pixels, or null for no grid.
  final double? gridSpacing;

  final List<Rect> _candidates;
  final List<_Candidate> _vertical;
  final List<_Candidate> _horizontal;

  /// The candidate lines along one axis, in tie-break order: guides first,
  /// then the slide's edges and center, then each element's edges and
  /// center. Edge lines match the moving rect's edges, center lines its
  /// center, guide lines everything.
  static List<_Candidate> _linesFor(
    SnapOrientation orientation,
    Size slide,
    List<Rect> candidates,
    List<ManualGuide> guides,
  ) {
    final vertical = orientation == SnapOrientation.vertical;
    final extent = vertical ? slide.width : slide.height;
    return [
      for (final guide in guides)
        if (guide.orientation == orientation)
          (position: guide.position * extent, kind: SnapKind.guide, features: 3),
      (position: 0.0, kind: SnapKind.edge, features: 1),
      (position: extent / 2, kind: SnapKind.center, features: 2),
      (position: extent, kind: SnapKind.edge, features: 1),
      for (final rect in candidates) ...[
        (position: vertical ? rect.left : rect.top, kind: SnapKind.edge, features: 1),
        (position: vertical ? rect.center.dx : rect.center.dy, kind: SnapKind.center, features: 2),
        (position: vertical ? rect.right : rect.bottom, kind: SnapKind.edge, features: 1),
      ],
    ];
  }

  /// Snaps a body drag: [moving] is the dragged selection's bounding rect.
  /// Returns the rect shifted onto the nearest candidates within
  /// [tolerance], or unchanged (with no lines) when nothing is close or
  /// [disabled] is set (the bypass modifier).
  SnapResult snapMove(Rect moving, {bool disabled = false}) {
    if (disabled) return SnapResult(moving, const []);
    final x = _moveAxis(SnapOrientation.vertical, moving);
    final y = _moveAxis(SnapOrientation.horizontal, moving);
    final xLine = x.line;
    final yLine = y.line;
    if (xLine == null && yLine == null) return SnapResult(moving, const []);
    return SnapResult(moving.shift(Offset(x.shift, y.shift)), [?xLine, ?yLine]);
  }

  /// Snaps a resize: only the dragged edges participate ([movingX] and
  /// [movingY] are the handle's alignment components, -1/0/1), the pinned
  /// edges stay put, and spacing hints are not offered. The caller skips
  /// rotated, aspect-locked, and from-center resizes.
  SnapResult snapResize(
    Rect rect, {
    required double movingX,
    required double movingY,
    bool disabled = false,
  }) {
    if (disabled) return SnapResult(rect, const []);
    final x = movingX == 0
        ? null
        : _edgeAxis(SnapOrientation.vertical, movingX < 0 ? rect.left : rect.right);
    final y = movingY == 0
        ? null
        : _edgeAxis(SnapOrientation.horizontal, movingY < 0 ? rect.top : rect.bottom);
    final xLine = x?.line;
    final yLine = y?.line;
    if (xLine == null && yLine == null) return SnapResult(rect, const []);
    return SnapResult(
      Rect.fromLTRB(
        rect.left + (xLine != null && movingX < 0 ? x!.shift : 0),
        rect.top + (yLine != null && movingY < 0 ? y!.shift : 0),
        rect.right + (xLine != null && movingX > 0 ? x!.shift : 0),
        rect.bottom + (yLine != null && movingY > 0 ? y!.shift : 0),
      ),
      [?xLine, ?yLine],
    );
  }

  /// The best snap for a move along one axis: every candidate line against
  /// the features it matches, then the spacing hints, then the grid.
  _AxisBest _moveAxis(SnapOrientation orientation, Rect moving) {
    final vertical = orientation == SnapOrientation.vertical;
    final start = vertical ? moving.left : moving.top;
    final end = vertical ? moving.right : moving.bottom;
    final mid = (start + end) / 2;
    final best = _AxisBest(orientation, tolerance);
    for (final line in vertical ? _vertical : _horizontal) {
      if (line.features & 1 != 0) {
        best
          ..consider(line.position, line.kind, start)
          ..consider(line.position, line.kind, end);
      }
      if (line.features & 2 != 0) best.consider(line.position, line.kind, mid);
    }
    _forEachSpacing(
      orientation,
      moving,
      (position, feature) => best.consider(position, SnapKind.spacing, feature),
    );
    final grid = gridSpacing;
    if (grid != null) {
      best
        ..consider(_nearestMultiple(start, grid), SnapKind.grid, start)
        ..consider(_nearestMultiple(end, grid), SnapKind.grid, end);
    }
    return best;
  }

  /// The best snap for one dragged edge: the single [feature] against every
  /// candidate line kind and the grid (no spacing).
  _AxisBest _edgeAxis(SnapOrientation orientation, double feature) {
    final best = _AxisBest(orientation, tolerance);
    for (final line in orientation == SnapOrientation.vertical ? _vertical : _horizontal) {
      best.consider(line.position, line.kind, feature);
    }
    final grid = gridSpacing;
    if (grid != null) best.consider(_nearestMultiple(feature, grid), SnapKind.grid, feature);
    return best;
  }

  static double _nearestMultiple(double value, double step) =>
      (value / step).roundToDouble() * step;
}

/// The running winner along one axis: nearest wins, first wins exact ties.
final class _AxisBest {
  _AxisBest(this._orientation, this._tolerance);

  final SnapOrientation _orientation;
  final double _tolerance;
  double _distance = double.infinity;

  /// How far the moving rect must shift to land on [line].
  double shift = 0;

  /// The winning line, or null while nothing is within tolerance.
  SnapLine? line;

  /// Offers a candidate [position] of [kind] for the moving [feature].
  void consider(double position, SnapKind kind, double feature) {
    final distance = (position - feature).abs();
    if (distance > _tolerance || distance >= _distance) return;
    _distance = distance;
    shift = position - feature;
    line = SnapLine(kind: kind, orientation: _orientation, position: position);
  }
}
