import 'package:flutter/material.dart';
import 'layer.dart';

/// A video composition stack that provides video-specific layer management.
///
/// Unlike a plain [Stack], LayerStack offers:
/// - Support for [Layer] widgets with time-based visibility
/// - Automatic z-index sorting when layers specify [Layer.zIndex]
/// - Background and overlay layer convenience constructors
///
/// You can mix [Layer] widgets with regular widgets. Regular widgets
/// are treated as always-visible layers without any special behavior.
///
/// Example:
/// ```dart
/// LayerStack(
///   children: [
///     Layer.background(
///       fadeInFrames: 15,
///       child: GradientBackground(),
///     ),
///     Layer(
///       id: 'title',
///       startFrame: 30,
///       endFrame: 120,
///       fadeInFrames: 15,
///       fadeOutFrames: 15,
///       child: TitleWidget(),
///     ),
///     Layer.overlay(
///       blendMode: BlendMode.screen,
///       child: Watermark(),
///     ),
///   ],
/// )
/// ```
class LayerStack extends StatelessWidget {
  /// The layers in this stack.
  ///
  /// Can be [Layer] widgets or regular widgets. Regular widgets are
  /// treated as always-visible layers.
  final List<Widget> children;

  /// Optional alignment for all children.
  ///
  /// Defaults to [AlignmentDirectional.topStart] like Flutter's [Stack].
  final AlignmentGeometry alignment;

  /// How to size non-positioned children.
  final StackFit fit;

  /// Text direction for alignment.
  final TextDirection? textDirection;

  /// Clip behavior for the stack.
  final Clip clipBehavior;

  /// Creates a layer stack.
  const LayerStack({
    super.key,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.fit = StackFit.loose,
    this.textDirection,
    this.clipBehavior = Clip.hardEdge,
  });

  @override
  Widget build(BuildContext context) {
    // Sort children by z-index if any Layer widgets have zIndex set
    final sortedChildren = _sortByZIndex(children);

    return Stack(
      alignment: alignment,
      fit: fit,
      textDirection: textDirection,
      clipBehavior: clipBehavior,
      children: sortedChildren,
    );
  }

  /// Sorts children by z-index, keeping relative order for widgets
  /// without explicit z-index.
  List<Widget> _sortByZIndex(List<Widget> widgets) {
    // Check if any Layer has a zIndex set
    final hasZIndex = widgets.any((w) => w is Layer && w.zIndex != null);

    if (!hasZIndex) {
      // No sorting needed, return as-is
      return widgets;
    }

    // Create indexed list to preserve original order for equal z-indices
    final indexed = widgets.asMap().entries.toList();

    // Sort by z-index, using original index as tiebreaker
    indexed.sort((a, b) {
      final aZIndex = a.value is Layer ? (a.value as Layer).zIndex ?? 0 : 0;
      final bZIndex = b.value is Layer ? (b.value as Layer).zIndex ?? 0 : 0;

      if (aZIndex != bZIndex) {
        return aZIndex.compareTo(bZIndex);
      }
      // Keep original order for equal z-indices
      return a.key.compareTo(b.key);
    });

    return indexed.map((e) => e.value).toList();
  }
}
