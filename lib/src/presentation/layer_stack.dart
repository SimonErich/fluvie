import 'package:flutter/material.dart';

/// A widget that positions its children relative to the edges of its box.
///
/// Similar to Flutter's [Stack], but designed for video composition.
/// Children are layered on top of each other.
class LayerStack extends StatelessWidget {
  /// The widgets below this widget in the tree.
  final List<Widget> children;

  const LayerStack({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(children: children);
  }
}
