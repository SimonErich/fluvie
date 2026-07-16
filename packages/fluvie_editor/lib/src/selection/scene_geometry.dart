import 'dart:math' as math;
import 'dart:ui';

import 'package:fluvie/fluvie.dart' show Placement, decodePlacement;
import 'package:fluvie_editor/src/document/editor_document.dart';

/// One element's place on the canvas: its unrotated layout rect and its
/// rotation. The shape it occupies is [corners] — the rect turned around
/// its own center, exactly how `Placed` renders it.
final class ElementGeometry {
  ElementGeometry._(this.id, this.rect, this.rotation);

  /// The element this geometry belongs to.
  final String id;

  /// The unrotated layout home (the `Placement.rectFor` result).
  final Rect rect;

  /// Clockwise rotation around the rect center, in degrees.
  final double rotation;

  /// The rotated shape's corners, clockwise from what was the top-left.
  List<Offset> get corners {
    final radians = rotation * math.pi / 180;
    final cosine = math.cos(radians);
    final sine = math.sin(radians);
    final center = rect.center;
    Offset rotate(Offset corner) {
      final local = corner - center;
      return center +
          Offset(local.dx * cosine - local.dy * sine, local.dx * sine + local.dy * cosine);
    }

    return [
      rotate(rect.topLeft),
      rotate(rect.topRight),
      rotate(rect.bottomRight),
      rotate(rect.bottomLeft),
    ];
  }

  /// Whether the rotated shape contains [point].
  bool contains(Offset point) {
    final radians = -rotation * math.pi / 180;
    final cosine = math.cos(radians);
    final sine = math.sin(radians);
    final local = point - rect.center;
    final unrotated = Offset(
      local.dx * cosine - local.dy * sine,
      local.dx * sine + local.dy * cosine,
    );
    return unrotated.dx.abs() <= rect.width / 2 && unrotated.dy.abs() <= rect.height / 2;
  }
}

/// The document's answer to "what is where" on one slide — resolved through
/// the same `Placement` mapping `Placed` renders with, never through the
/// widget tree.
///
/// Intrinsic-sized elements (no `w`/`h`, or no `transform` at all) only get
/// geometry once their laid-out size arrives through the `intrinsicSizes`
/// map (the canvas's geometry reporter feeds it); until then they have no
/// rect and cannot be hit.
final class SceneGeometry {
  SceneGeometry._(this._geometries);

  /// Resolves the geometry of slide [slide] in [document].
  factory SceneGeometry.of(
    EditorDocument document,
    int slide, {
    Map<String, Size> intrinsicSizes = const {},
  }) {
    final size = document.spec.size;
    final canvas = Size(size.width.toDouble(), size.height.toDouble());
    final geometries = <ElementGeometry>[];
    for (final id in document.elementIdsInScene(slide)) {
      final transform = document.elementJson(id)?['transform'];
      final placement = transform == null
          ? const Placement(x: 0.5, y: 0.5)
          : decodePlacement(transform);
      final rect = placement.rectFor(canvas, childSize: intrinsicSizes[id]);
      if (rect == null) continue;
      geometries.add(ElementGeometry._(id, rect, placement.rotation));
    }
    return SceneGeometry._(geometries);
  }

  final List<ElementGeometry> _geometries;

  /// The unrotated layout rect of [id], or null while its size is unknown.
  Rect? rectOf(String id) => _byId(id)?.rect;

  /// The rotation of [id] in degrees, or null while its size is unknown.
  double? rotationOf(String id) => _byId(id)?.rotation;

  /// The rotated shape corners of [id], or null while its size is unknown.
  List<Offset>? cornersOf(String id) => _byId(id)?.corners;

  /// The topmost element whose shape contains [point], or null.
  String? hitTest(Offset point) {
    for (final geometry in _geometries.reversed) {
      if (geometry.contains(point)) return geometry.id;
    }
    return null;
  }

  /// Every element whose shape intersects [marquee].
  Set<String> hitTestMarquee(Rect marquee) => {
    for (final geometry in _geometries)
      if (_intersects(marquee, geometry)) geometry.id,
  };

  ElementGeometry? _byId(String id) {
    for (final geometry in _geometries) {
      if (geometry.id == id) return geometry;
    }
    return null;
  }
}

/// Separating-axis intersection between an axis-aligned [marquee] and a
/// rotated rect: four candidate axes, overlap required on every one.
bool _intersects(Rect marquee, ElementGeometry geometry) {
  final quad = geometry.corners;
  final box = [marquee.topLeft, marquee.topRight, marquee.bottomRight, marquee.bottomLeft];
  final radians = geometry.rotation * math.pi / 180;
  final axes = [
    const Offset(1, 0),
    const Offset(0, 1),
    Offset(math.cos(radians), math.sin(radians)),
    Offset(-math.sin(radians), math.cos(radians)),
  ];
  for (final axis in axes) {
    if (!_overlaps(_project(box, axis), _project(quad, axis))) return false;
  }
  return true;
}

({double min, double max}) _project(List<Offset> points, Offset axis) {
  var low = double.infinity;
  var high = double.negativeInfinity;
  for (final point in points) {
    final dot = point.dx * axis.dx + point.dy * axis.dy;
    if (dot < low) low = dot;
    if (dot > high) high = dot;
  }
  return (min: low, max: high);
}

bool _overlaps(({double min, double max}) a, ({double min, double max}) b) =>
    a.max >= b.min && b.max >= a.min;
