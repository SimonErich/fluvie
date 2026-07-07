import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/transition/transition_strategy.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/transition.dart';

/// The [TransitionKind.wipe] blend: the outgoing scene paints
/// plain below while the incoming is revealed above through a [ClipRect]
/// whose rect grows in the **direction of travel** — [Edge.right] uncovers
/// left-to-right.
final class WipeStrategy implements TransitionStrategy {
  /// Const so [strategyFor] can hand out a singleton.
  const WipeStrategy();

  @override
  List<Widget> compose({
    required Widget outgoing,
    required Widget incoming,
    required double easedProgress,
    required Transition spec,
  }) => [
    outgoing,
    ClipRect(
      clipper: _WipeClipper(direction: spec.direction ?? Edge.right, progress: easedProgress),
      child: incoming,
    ),
  ];
}

/// The reveal rect behind [WipeStrategy]: anchored at the edge the front
/// travels *away from*, spanning `progress` of the canvas along the travel
/// axis and the full canvas across it.
final class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper({required this.direction, required this.progress});

  /// The direction the wipe front travels toward.
  final Edge direction;

  /// The eased blend progress in `(0, 1]`.
  final double progress;

  @override
  Rect getClip(Size size) {
    final width = size.width * progress;
    final height = size.height * progress;
    return switch (direction) {
      Edge.right => Rect.fromLTWH(0, 0, width, size.height),
      Edge.left => Rect.fromLTWH(size.width - width, 0, width, size.height),
      Edge.bottom => Rect.fromLTWH(0, 0, size.width, height),
      Edge.top => Rect.fromLTWH(0, size.height - height, size.width, height),
    };
  }

  @override
  bool shouldReclip(_WipeClipper oldClipper) =>
      oldClipper.direction != direction || oldClipper.progress != progress;
}
