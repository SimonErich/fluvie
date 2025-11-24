import 'package:flutter/material.dart';
import '../domain/renderable.dart';
import '../domain/render_config.dart';

/// A fundamental building block for video content.
///
/// A [Clip] defines a segment of video that starts at a specific [startFrame]
/// and lasts for [durationInFrames].
class Clip extends StatelessWidget implements Renderable {
  /// The frame number where this clip begins relative to its parent.
  final int startFrame;

  /// The duration of this clip in frames.
  final int durationInFrames;

  /// The content of the clip.
  final Widget child;

  const Clip({
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
    // Clip itself doesn't produce a full RenderConfig, but contributes to one.
    throw UnimplementedError('Clip should return ClipConfig, not RenderConfig');
  }

  ClipConfig toClipConfig() {
    return ClipConfig(
      startFrame: startFrame,
      durationInFrames: durationInFrames,
      // Child clips can be added here in the future.
    );
  }
}
