import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/core/placement.dart';
import 'package:fluvie/src/elements/placed_overrides.dart';

/// Positions [child] on the scene canvas by a fractional [Placement] — the
/// widget behind the spec's `transform` key, and the layout home a canvas
/// editor reads and writes.
///
/// The placement resolves through [Placement.rectFor], the one shared
/// fraction-to-pixel mapping. A sized placement constrains the child to its
/// fractional rect; an intrinsic one lets the child size itself and centers
/// its anchor point on the placement point. Rotation turns the child around
/// its own center after layout.
///
/// ```dart
/// Placed(
///   placement: Placement(x: 0.25, y: 0.5, width: 0.5, height: 0.25),
///   child: Chart.bar(data: revenue),
/// )
/// ```
final class Placed extends StatelessWidget implements CollectibleChildren {
  /// Lays [child] out at [placement] on the canvas.
  const Placed({required this.placement, required this.child, this.id, super.key});

  /// Where the child sits, in canvas fractions.
  final Placement placement;

  /// The element id an editing tool addresses this placement by, or null for
  /// an anonymous element. [PlacedOverrides] keys off it.
  final String? id;

  /// The element being placed.
  final Widget child;

  /// The structural walk (media collectors, timeline introspection) sees
  /// through the placement to the element itself.
  @override
  Iterable<Widget> get collectibleChildren => [child];

  @override
  Widget build(BuildContext context) {
    final elementId = id;
    final effective =
        (elementId == null ? null : PlacedOverrides.of(context, elementId)) ?? placement;
    var content = child;
    if (effective.rotation != 0) {
      content = Transform.rotate(
        angle: effective.rotation * math.pi / 180,
        child: content,
      );
    }
    if (effective.opacity != 1) {
      content = Opacity(opacity: effective.opacity, child: content);
    }
    return CustomSingleChildLayout(
      delegate: _PlacedLayout(effective),
      child: content,
    );
  }
}

/// Expands to the canvas and drops the child on its placement rect.
final class _PlacedLayout extends SingleChildLayoutDelegate {
  const _PlacedLayout(this.placement);

  final Placement placement;

  @override
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final rect = placement.rectFor(constraints.biggest);
    // Intrinsic children still size within the canvas (fluvie's fractional
    // primitives need a bounded parent), they just pick their own size.
    if (rect == null) return BoxConstraints.loose(constraints.biggest);
    return BoxConstraints.tight(rect.size);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      placement.rectFor(size, childSize: childSize)!.topLeft;

  @override
  bool shouldRelayout(_PlacedLayout oldDelegate) => oldDelegate.placement != placement;
}
