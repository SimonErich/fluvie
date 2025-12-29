import 'package:flutter/widgets.dart';
import '../../presentation/fade.dart';
import '../../presentation/time_consumer.dart';
import '../../utils/interpolate.dart';
import 'stagger_config.dart';
import 'video_timing_mixin.dart';

/// A video-aware Row widget with timing, fade, and stagger properties.
///
/// [VRow] extends Flutter's [Row] with video-specific properties like
/// startFrame, endFrame, fade transitions, and staggered child animations.
///
/// Example:
/// ```dart
/// VRow(
///   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
///   stagger: StaggerConfig.slideUp(delay: 10),
///   children: [
///     StatCard(value: 42, label: 'Stats'),
///     StatCard(value: 100, label: 'More'),
///   ],
/// )
/// ```
class VRow extends StatelessWidget with VideoTimingMixin {
  /// The widgets below this widget in the tree.
  final List<Widget> children;

  /// How the children should be placed along the main axis.
  final MainAxisAlignment mainAxisAlignment;

  /// How the children should be placed along the cross axis.
  final CrossAxisAlignment crossAxisAlignment;

  /// How much space should be occupied in the main axis.
  final MainAxisSize mainAxisSize;

  /// The direction to use as the main axis.
  final TextDirection? textDirection;

  /// Determines the order to lay children out vertically and how to interpret
  /// `start` and `end` in the vertical direction.
  final VerticalDirection verticalDirection;

  /// If aligning items according to their baseline, which baseline to use.
  final TextBaseline? textBaseline;

  /// Configuration for staggered child animations.
  ///
  /// When set, children will animate in sequence with the specified delay
  /// between each child's animation start.
  final StaggerConfig? stagger;

  /// The spacing between children.
  final double spacing;

  // Video timing properties
  @override
  final int? startFrame;

  @override
  final int? endFrame;

  @override
  final int fadeInFrames;

  @override
  final int fadeOutFrames;

  @override
  final Curve fadeInCurve;

  @override
  final Curve fadeOutCurve;

  /// Creates a video-aware Row.
  const VRow({
    super.key,
    this.children = const <Widget>[],
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.stagger,
    this.spacing = 0,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> effectiveChildren;

    if (stagger != null) {
      effectiveChildren = _buildStaggeredChildren(context);
    } else if (spacing > 0) {
      effectiveChildren = _buildSpacedChildren();
    } else {
      effectiveChildren = children;
    }

    final row = Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      children: effectiveChildren,
    );

    return wrapWithTiming(row);
  }

  /// Builds children with spacing between them.
  List<Widget> _buildSpacedChildren() {
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(SizedBox(width: spacing));
      }
    }
    return result;
  }

  /// Builds children with staggered animations.
  List<Widget> _buildStaggeredChildren(BuildContext context) {
    final config = stagger!;
    final result = <Widget>[];

    for (int i = 0; i < children.length; i++) {
      Widget child = _StaggeredChild(
        index: i,
        config: config,
        child: children[i],
      );

      result.add(child);

      if (spacing > 0 && i < children.length - 1) {
        result.add(SizedBox(width: spacing));
      }
    }

    return result;
  }
}

/// Internal widget that applies stagger animation to a single child.
class _StaggeredChild extends StatelessWidget {
  final int index;
  final StaggerConfig config;
  final Widget child;

  const _StaggeredChild({
    required this.index,
    required this.config,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, globalProgress) {
        final startFrame = config.startFrameForIndex(index);
        final endFrame = config.endFrameForIndex(index);

        // Before animation starts
        if (frame < startFrame) {
          return Opacity(opacity: 0, child: child);
        }

        // After animation completes
        if (frame >= endFrame) {
          return child;
        }

        // During animation
        final progress = (frame - startFrame) / config.effectiveDuration;
        final curvedProgress = config.curve.transform(progress.clamp(0.0, 1.0));

        Widget result = child;

        // Apply transforms
        if (config.scaleIn) {
          final scale = lerpValue(curvedProgress, config.scaleStart, 1.0);
          result = Transform.scale(scale: scale, child: result);
        }

        if (config.slideIn) {
          final offsetX = lerpValue(curvedProgress, config.slideOffset.dx, 0.0);
          final offsetY = lerpValue(curvedProgress, config.slideOffset.dy, 0.0);
          result = Transform.translate(
            offset: Offset(offsetX, offsetY),
            child: result,
          );
        }

        if (config.fadeIn) {
          final opacity = lerpValue(curvedProgress, 0.0, 1.0);
          result = Fade(opacity: opacity, child: result);
        }

        return result;
      },
    );
  }
}
