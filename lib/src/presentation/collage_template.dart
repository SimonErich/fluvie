import 'package:flutter/material.dart';

/// A template for creating common video layouts.
///
/// Use [CollageTemplate.splitScreen] to create a side-by-side layout.
class CollageTemplate extends StatelessWidget {
  /// The widgets to display in the collage.
  final List<Widget> children;
  final String type;

  /// Creates a split-screen layout with two children side-by-side.
  const CollageTemplate.splitScreen({super.key, required this.children})
    : type = 'splitScreen';

  @override
  Widget build(BuildContext context) {
    return Row(children: children);
  }
}
