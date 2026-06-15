import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';

/// A solid block, bar, or divider — animatable like anything else:
///
/// ```dart
/// Box(color: Colors.white, size: Size(0.5, 0.01))     // a thin rule
///     .animate([Animation.from(const Keyframe(scaleX: 0))]);   // grows in
/// ```
///
/// [size] components are **always fractions of the parent**:
/// `Size(0.5, 0.01)` is half the parent's width by 1% of its
/// height, and `null` expands to the whole parent. There is no "values above
/// one are pixels" heuristic — for absolute dimensions wrap a plain
/// [SizedBox], exactly like the rest of the layout story uses Flutter's
/// real widgets.
///
/// An optional [shared] anchor wraps the box in a `SharedElement` so it morphs
/// across the boundary it shares with the same anchor in the adjacent scene;
/// `null` mounts no `SharedElement`.
final class Box extends StatelessWidget {
  /// Creates a block filling [size] of its parent with [color] or
  /// [decoration] (at most one; neither paints a transparent spacer).
  const Box({this.color, this.size, this.decoration, this.shared, super.key})
    : assert(
        color == null || decoration == null,
        'Box takes color: or decoration:, not both — put the color inside '
        'the BoxDecoration instead.',
      );

  /// The fill color, or `null` when [decoration] (or nothing) paints.
  final Color? color;

  /// The parent-fraction size (width fraction × height fraction), or `null` to
  /// expand to the whole parent.
  final Size? size;

  /// The fill decoration, or `null` when [color] (or nothing) paints.
  final BoxDecoration? decoration;

  /// An optional hero anchor: when non-null the box morphs across the boundary
  /// it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  @override
  Widget build(BuildContext context) {
    final fill = decoration != null
        ? DecoratedBox(decoration: decoration!)
        : color != null
        ? ColoredBox(color: color!)
        : const SizedBox.expand();
    final fraction = size;
    final sized = fraction == null
        ? SizedBox.expand(child: fill)
        : FractionallySizedBox(
            widthFactor: fraction.width,
            heightFactor: fraction.height,
            child: fill,
          );
    return shared == null ? sized : SharedElement(anchor: shared, child: sized);
  }
}
