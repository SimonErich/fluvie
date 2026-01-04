import 'package:flutter/material.dart';
import 'layer.dart';
import 'time_consumer.dart';

/// A layer with built-in animation support via [TimeConsumer].
///
/// Simplifies creating animated layers without manually wrapping in
/// [TimeConsumer]. The [builder] callback receives the current frame
/// and progress, allowing you to animate any property.
///
/// Example:
/// ```dart
/// AnimatedLayer(
///   id: 'bouncing-ball',
///   startFrame: 0,
///   endFrame: 60,
///   fadeInFrames: 10,
///   builder: (context, frame, progress) {
///     final y = 100 + (progress * 200);
///     return Positioned(
///       top: y,
///       left: 100,
///       child: CircleAvatar(radius: 20),
///     );
///   },
/// )
/// ```
class AnimatedLayer extends StatelessWidget {
  /// Unique identifier for this layer.
  final String? id;

  /// Builder function called with the current frame and progress.
  ///
  /// The `progress` is a value from 0.0 to 1.0 representing the
  /// position within the layer's duration.
  final Widget Function(BuildContext context, int frame, double progress)
      builder;

  /// Frame at which this layer becomes visible.
  final int? startFrame;

  /// Frame at which this layer becomes invisible.
  final int? endFrame;

  /// Duration of fade-in transition in frames.
  final int fadeInFrames;

  /// Duration of fade-out transition in frames.
  final int fadeOutFrames;

  /// Blend mode for compositing.
  final BlendMode blendMode;

  /// Whether this layer is enabled.
  final bool enabled;

  /// Z-index for explicit ordering.
  final int? zIndex;

  /// Creates an animated layer.
  const AnimatedLayer({
    super.key,
    this.id,
    required this.builder,
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = 0,
    this.fadeOutFrames = 0,
    this.blendMode = BlendMode.srcOver,
    this.enabled = true,
    this.zIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Layer(
      id: id,
      startFrame: startFrame,
      endFrame: endFrame,
      fadeInFrames: fadeInFrames,
      fadeOutFrames: fadeOutFrames,
      blendMode: blendMode,
      enabled: enabled,
      zIndex: zIndex,
      child: TimeConsumer(builder: builder),
    );
  }
}

/// Groups multiple layers for coordinated effects.
///
/// All child layers share the group's visibility timing and opacity.
/// This is useful when you have multiple elements that should appear
/// and disappear together.
///
/// Example:
/// ```dart
/// LayerGroup(
///   id: 'stats-section',
///   startFrame: 100,
///   endFrame: 300,
///   fadeInFrames: 20,
///   fadeOutFrames: 20,
///   children: [
///     StatCard(value: 42, label: 'Projects'),
///     StatCard(value: 1000, label: 'Hours'),
///     StatCard(value: 365, label: 'Days'),
///   ],
/// )
/// ```
class LayerGroup extends StatelessWidget {
  /// Unique identifier for this group.
  final String? id;

  /// The widgets in this group.
  final List<Widget> children;

  /// Frame at which this group becomes visible.
  final int? startFrame;

  /// Frame at which this group becomes invisible.
  final int? endFrame;

  /// Duration of fade-in transition in frames.
  final int fadeInFrames;

  /// Duration of fade-out transition in frames.
  final int fadeOutFrames;

  /// Base opacity of the group.
  final double opacity;

  /// Whether this group is enabled.
  final bool enabled;

  /// Z-index for explicit ordering.
  final int? zIndex;

  /// Alignment for the internal stack.
  final AlignmentGeometry alignment;

  /// Creates a layer group.
  const LayerGroup({
    super.key,
    this.id,
    required this.children,
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = 0,
    this.fadeOutFrames = 0,
    this.opacity = 1.0,
    this.enabled = true,
    this.zIndex,
    this.alignment = AlignmentDirectional.topStart,
  });

  @override
  Widget build(BuildContext context) {
    return Layer(
      id: id,
      startFrame: startFrame,
      endFrame: endFrame,
      fadeInFrames: fadeInFrames,
      fadeOutFrames: fadeOutFrames,
      opacity: opacity,
      enabled: enabled,
      zIndex: zIndex,
      child: Stack(alignment: alignment, children: children),
    );
  }
}
