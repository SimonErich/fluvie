import 'dart:ui' show Offset, Path, PathMetric, Tangent;

import 'package:flutter/widgets.dart' show Transform, Widget;
import 'package:fluvie/src/animation/animation_effect.dart';

/// The effect behind `Animation.along`: the child travels [path] as progress
/// runs `0 → 1`, measured by arc length.
///
/// Path coordinates are **logical pixels relative to the element's natural
/// position** — `(0, 0)` is "exactly where layout put it" — applied via
/// `Transform.translate`. With [orient], the child also rotates to face the
/// path's tangent direction.
///
/// The path's metrics are computed once on first use and cached, so [path]
/// **must not be mutated after construction** — a mutated path would
/// desynchronise frames and break determinism. Progress outside `[0, 1]`
/// clamps to the path's endpoints.
final class PathEffect implements AnimationEffect {
  /// Creates an effect travelling [path]; [orient] adds tangent rotation.
  PathEffect(this.path, {this.orient = true});

  /// The path to travel, in logical px relative to the natural position.
  final Path path;

  /// Whether the child rotates to face the direction of travel.
  final bool orient;

  late final List<PathMetric> _metrics = path.computeMetrics().toList();
  late final double _totalLength = _metrics.fold(0, (sum, metric) => sum + metric.length);

  @override
  Widget build(Widget child, double progress) {
    if (_totalLength == 0) return child;
    final tangent = _tangentAt(progress);
    var result = child;
    if (orient) {
      // Tangent.angle is counterclockwise-positive (math coords); negate it
      // for Flutter's clockwise-positive screen rotation.
      result = Transform.rotate(angle: -tangent.angle, child: result);
    }
    return Transform.translate(offset: tangent.position, child: result);
  }

  /// The position/direction at `clamp(progress) × total arc length`, walking
  /// the cached contours cumulatively.
  Tangent _tangentAt(double progress) {
    var distance = progress.clamp(0.0, 1.0) * _totalLength;
    for (final metric in _metrics) {
      if (distance <= metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) return tangent;
        break;
      }
      distance -= metric.length;
    }
    return const Tangent(Offset.zero, Offset(1, 0));
  }

  @override
  String toString() => 'PathEffect(orient: $orient)';
}
