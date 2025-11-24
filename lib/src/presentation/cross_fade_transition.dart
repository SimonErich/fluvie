import 'package:flutter/material.dart';

/// A transition that cross-fades between two children.
///
/// The transition lasts for [durationInFrames].
class CrossFadeTransition extends StatelessWidget {
  /// Duration of the cross-fade in frames.
  final int durationInFrames;

  /// The widget fading out.
  final Widget child1;

  /// The widget fading in.
  final Widget child2;

  const CrossFadeTransition({
    super.key,
    required this.durationInFrames,
    required this.child1,
    required this.child2,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [child1, child2]);
  }
}
