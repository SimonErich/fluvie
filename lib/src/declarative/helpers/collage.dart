import 'package:flutter/widgets.dart';

import '../animations/core/animated_prop.dart';
import '../animations/core/prop_animation.dart';

/// Layout type for collages.
enum CollageLayout {
  /// 2x2 grid layout.
  grid2x2,

  /// 3x3 grid layout.
  grid3x3,

  /// Horizontal split (2 items side by side).
  splitHorizontal,

  /// Vertical split (2 items stacked).
  splitVertical,

  /// Featured layout with one large item and thumbnails.
  featured,

  /// Masonry-style layout.
  masonry,
}

/// A widget that arranges children in predefined collage layouts.
///
/// [Collage] provides common multi-element layouts with optional
/// entry animations and stagger effects.
///
/// Example:
/// ```dart
/// Collage.grid2x2(
///   spacing: 8,
///   children: [
///     Image.asset('photo1.jpg'),
///     Image.asset('photo2.jpg'),
///     Image.asset('photo3.jpg'),
///     Image.asset('photo4.jpg'),
///   ],
/// )
/// ```
class Collage extends StatelessWidget {
  /// The children to arrange in the collage.
  final List<Widget> children;

  /// The layout style.
  final CollageLayout layout;

  /// Spacing between items.
  final double spacing;

  /// Optional entry animation for items.
  final PropAnimation? entryAnimation;

  /// Delay between each item's animation in frames.
  final int staggerDelay;

  /// Duration of each item's animation in frames.
  final int animationDuration;

  /// The frame at which animations start.
  final int startFrame;

  /// Border radius for items.
  final double itemBorderRadius;

  /// Creates a collage.
  const Collage({
    super.key,
    required this.children,
    required this.layout,
    this.spacing = 8,
    this.entryAnimation,
    this.staggerDelay = 5,
    this.animationDuration = 20,
    this.startFrame = 0,
    this.itemBorderRadius = 0,
  })  : _left = null,
        _right = null;

  /// Creates a 2x2 grid collage.
  const Collage.grid2x2({
    super.key,
    required this.children,
    this.spacing = 8,
    this.entryAnimation,
    this.staggerDelay = 5,
    this.animationDuration = 20,
    this.startFrame = 0,
    this.itemBorderRadius = 0,
  })  : layout = CollageLayout.grid2x2,
        _left = null,
        _right = null;

  /// Creates a 3x3 grid collage.
  const Collage.grid3x3({
    super.key,
    required this.children,
    this.spacing = 8,
    this.entryAnimation,
    this.staggerDelay = 5,
    this.animationDuration = 20,
    this.startFrame = 0,
    this.itemBorderRadius = 0,
  })  : layout = CollageLayout.grid3x3,
        _left = null,
        _right = null;

  /// Creates a horizontal split collage.
  const Collage.splitHorizontal({
    super.key,
    required Widget left,
    required Widget right,
    this.spacing = 8,
    this.entryAnimation,
    this.staggerDelay = 5,
    this.animationDuration = 20,
    this.startFrame = 0,
    this.itemBorderRadius = 0,
  })  : children = const [],
        layout = CollageLayout.splitHorizontal,
        // Store left and right in children via the build method
        _left = left,
        _right = right;

  /// Creates a vertical split collage.
  const Collage.splitVertical({
    super.key,
    required Widget top,
    required Widget bottom,
    this.spacing = 8,
    this.entryAnimation,
    this.staggerDelay = 5,
    this.animationDuration = 20,
    this.startFrame = 0,
    this.itemBorderRadius = 0,
  })  : children = const [],
        layout = CollageLayout.splitVertical,
        _left = top, // Reuse _left for top
        _right = bottom; // Reuse _right for bottom

  /// Creates a featured collage with one main item and thumbnails.
  const Collage.featured({
    super.key,
    required Widget main,
    required List<Widget> thumbnails,
    this.spacing = 8,
    this.entryAnimation,
    this.staggerDelay = 5,
    this.animationDuration = 20,
    this.startFrame = 0,
    this.itemBorderRadius = 0,
  })  : children = thumbnails,
        layout = CollageLayout.featured,
        _left = main,
        _right = null;

  // Internal storage for split layouts
  final Widget? _left;
  final Widget? _right;

  @override
  Widget build(BuildContext context) {
    switch (layout) {
      case CollageLayout.grid2x2:
        return _buildGrid(2);
      case CollageLayout.grid3x3:
        return _buildGrid(3);
      case CollageLayout.splitHorizontal:
        return _buildSplitHorizontal();
      case CollageLayout.splitVertical:
        return _buildSplitVertical();
      case CollageLayout.featured:
        return _buildFeatured();
      case CollageLayout.masonry:
        return _buildMasonry();
    }
  }

  Widget _buildGrid(int columns) {
    final rows = (children.length / columns).ceil();
    final wrappedChildren = _wrapWithAnimations(children);

    return Column(
      children: List.generate(rows, (rowIndex) {
        final startIndex = rowIndex * columns;
        final endIndex = (startIndex + columns).clamp(
          0,
          wrappedChildren.length,
        );
        final rowChildren = wrappedChildren.sublist(
          startIndex,
          endIndex,
        );

        return Expanded(
          child: Row(
            children: [
              for (int i = 0; i < rowChildren.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: _wrapItem(rowChildren[i])),
              ],
              // Fill empty cells
              for (int i = rowChildren.length; i < columns; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                const Expanded(child: SizedBox()),
              ],
            ],
          ),
        );
      })
          .expand((row) sync* {
            yield row;
            yield SizedBox(height: spacing);
          })
          .take(rows * 2 - 1)
          .toList(),
    );
  }

  Widget _buildSplitHorizontal() {
    final wrappedLeft = _wrapWithAnimation(_left!, 0);
    final wrappedRight = _wrapWithAnimation(_right!, 1);

    return Row(
      children: [
        Expanded(child: _wrapItem(wrappedLeft)),
        SizedBox(width: spacing),
        Expanded(child: _wrapItem(wrappedRight)),
      ],
    );
  }

  Widget _buildSplitVertical() {
    final wrappedTop = _wrapWithAnimation(_left!, 0);
    final wrappedBottom = _wrapWithAnimation(_right!, 1);

    return Column(
      children: [
        Expanded(child: _wrapItem(wrappedTop)),
        SizedBox(height: spacing),
        Expanded(child: _wrapItem(wrappedBottom)),
      ],
    );
  }

  Widget _buildFeatured() {
    final wrappedMain = _wrapWithAnimation(_left!, 0);
    final wrappedThumbnails = _wrapWithAnimations(children, startIndex: 1);

    return Row(
      children: [
        // Main large item (2/3 width)
        Expanded(flex: 2, child: _wrapItem(wrappedMain)),
        SizedBox(width: spacing),
        // Thumbnails column (1/3 width)
        Expanded(
          child: Column(
            children: wrappedThumbnails
                .expand((item) sync* {
                  yield Expanded(child: _wrapItem(item));
                  yield SizedBox(height: spacing);
                })
                .take(wrappedThumbnails.length * 2 - 1)
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMasonry() {
    // Simple masonry: alternating 2-column layout
    final wrappedChildren = _wrapWithAnimations(children);
    final leftColumn = <Widget>[];
    final rightColumn = <Widget>[];

    for (int i = 0; i < wrappedChildren.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(wrappedChildren[i]);
      } else {
        rightColumn.add(wrappedChildren[i]);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: leftColumn
                .expand((item) sync* {
                  yield _wrapItem(item);
                  yield SizedBox(height: spacing);
                })
                .take(leftColumn.length * 2 - 1)
                .toList(),
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: Column(
            children: rightColumn
                .expand((item) sync* {
                  yield _wrapItem(item);
                  yield SizedBox(height: spacing);
                })
                .take(rightColumn.length * 2 - 1)
                .toList(),
          ),
        ),
      ],
    );
  }

  List<Widget> _wrapWithAnimations(List<Widget> items, {int startIndex = 0}) {
    if (entryAnimation == null) return items;

    return List.generate(items.length, (index) {
      return _wrapWithAnimation(items[index], startIndex + index);
    });
  }

  Widget _wrapWithAnimation(Widget child, int index) {
    if (entryAnimation == null) return child;

    return AnimatedProp(
      animation: entryAnimation!,
      startFrame: startFrame + (index * staggerDelay),
      duration: animationDuration,
      child: child,
    );
  }

  Widget _wrapItem(Widget child) {
    if (itemBorderRadius <= 0) return child;

    return ClipRRect(
      borderRadius: BorderRadius.circular(itemBorderRadius),
      child: child,
    );
  }
}
