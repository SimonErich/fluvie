import 'package:flutter/material.dart';
import '../domain/renderable.dart';
import '../domain/render_config.dart';

/// A fundamental building block for video content.
///
/// A [Sequence] defines a segment of video that starts at a specific [startFrame]
/// and lasts for [durationInFrames]. Sequences can be nested and combined
/// to create complex video compositions.
///
/// Example:
/// ```dart
/// Sequence(
///   startFrame: 0,
///   durationInFrames: 60, // 2 seconds at 30fps
///   child: Center(
///     child: Text('Hello World'),
///   ),
/// )
/// ```
class Sequence extends StatelessWidget implements Renderable {
  /// The frame number where this sequence begins relative to its parent.
  final int startFrame;

  /// The duration of this sequence in frames.
  final int durationInFrames;

  /// The content of the sequence.
  final Widget child;

  /// Creates a new video sequence.
  ///
  /// The [startFrame] defines when this sequence starts relative to its parent.
  /// The [durationInFrames] defines how long this sequence lasts.
  /// The [child] is the widget content rendered during this sequence.
  const Sequence({
    super.key,
    required this.startFrame,
    required this.durationInFrames,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }

  @override
  RenderConfig toConfig() {
    // Sequence itself doesn't produce a full RenderConfig, but contributes to one.
    throw UnimplementedError(
      'Sequence should return SequenceConfig via toSequenceConfig(), not RenderConfig',
    );
  }

  /// Converts this sequence to a serializable configuration object.
  SequenceConfig toSequenceConfig() {
    return SequenceConfig.base(
      startFrame: startFrame,
      durationInFrames: durationInFrames,
    );
  }
}
