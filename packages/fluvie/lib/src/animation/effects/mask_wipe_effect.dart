import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/core/wipe_shape.dart';

/// The reveal effect behind `Animation.maskWipeIn`: a growing clip mask that
/// uncovers its child as progress runs `0 → 1`.
///
/// A transform-class effect — it wraps the child in a [ClipPath] (no
/// saveLayer), so it composes with keyframe animations like any other
/// widget-level transform. At progress `0` the child is fully hidden; at `1`
/// (or beyond, for springs) the clip is dropped entirely and the child
/// renders untouched. Geometry is a pure function of shape, origin, progress,
/// and the child's size — fully deterministic.
///
/// Shapes ([WipeShape]):
///
/// * [WipeShape.circle] — a circle growing from [origin] whose radius reaches
///   the farthest corner exactly at progress `1`.
/// * [WipeShape.rect] — an axis-aligned rectangle expanding from [origin]
///   toward every edge proportionally.
/// * [WipeShape.diagonal] — a straight diagonal sweep from the top-left
///   corner to the bottom-right; [origin] is not used by this shape.
final class MaskWipeEffect implements AnimationEffect {
  /// Creates a mask wipe revealing through [shape], growing from [origin].
  const MaskWipeEffect({
    this.shape = WipeShape.circle,
    this.origin = Alignment.center,
    this.reverse = false,
  });

  /// The reveal geometry; defaults to [WipeShape.circle].
  final WipeShape shape;

  /// Where the mask grows from, as an alignment within the child's bounds;
  /// defaults to [Alignment.center]. Ignored by [WipeShape.diagonal].
  final Alignment origin;

  /// Runs the wipe backwards: the mask shrinks, hiding the element as
  /// progress runs `0 → 1` (the `maskWipeOut` exit).
  final bool reverse;

  @override
  Widget build(Widget child, double progress) {
    final reveal = reverse ? 1 - progress : progress;
    if (reveal >= 1) return child;
    final clamped = reveal < 0 ? 0.0 : reveal;
    return ClipPath(
      clipper: _WipeClipper(shape: shape, origin: origin, progress: clamped),
      child: child,
    );
  }

  @override
  String toString() =>
      'MaskWipeEffect(${shape.name}, origin: $origin${reverse ? ', reverse' : ''})';
}

/// Computes the wipe's clip path for one (shape, origin, progress) triple.
final class _WipeClipper extends CustomClipper<Path> {
  const _WipeClipper({required this.shape, required this.origin, required this.progress});

  final WipeShape shape;
  final Alignment origin;
  final double progress;

  @override
  Path getClip(Size size) => switch (shape) {
    WipeShape.circle => _circle(size),
    WipeShape.rect => _rect(size),
    WipeShape.diagonal => _diagonal(size),
  };

  /// A circle around the origin point; its radius spans the distance to the
  /// farthest corner at progress 1, so the whole child is covered.
  Path _circle(Size size) {
    final center = origin.alongSize(size);
    final farthest = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((corner) => (corner - center).distance).reduce(math.max);
    return Path()..addOval(Rect.fromCircle(center: center, radius: progress * farthest));
  }

  /// An axis-aligned rect whose four edges each travel from the origin point
  /// to the matching child edge proportionally with progress.
  Path _rect(Size size) {
    final center = origin.alongSize(size);
    return Path()..addRect(
      Rect.fromLTRB(
        center.dx * (1 - progress),
        center.dy * (1 - progress),
        center.dx + progress * (size.width - center.dx),
        center.dy + progress * (size.height - center.dy),
      ),
    );
  }

  /// The half-plane below-left of a diagonal line sweeping from the top-left
  /// corner to the bottom-right: a point is revealed once
  /// `x/width + y/height ≤ 2·progress`.
  Path _diagonal(Size size) {
    final reach = 2 * progress;
    final path = Path()..moveTo(0, 0);
    if (reach <= 1) {
      path
        ..lineTo(reach * size.width, 0)
        ..lineTo(0, reach * size.height);
    } else {
      path
        ..lineTo(size.width, 0)
        ..lineTo(size.width, (reach - 1) * size.height)
        ..lineTo((reach - 1) * size.width, size.height)
        ..lineTo(0, size.height);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_WipeClipper oldClipper) =>
      oldClipper.shape != shape || oldClipper.origin != origin || oldClipper.progress != progress;
}
