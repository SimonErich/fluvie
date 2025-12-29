import 'package:flutter/material.dart';
import 'sequence.dart';
import '../domain/render_config.dart';

/// A sequence that renders a video asset.
///
/// Use this to include external video files in your composition.
/// The video can be trimmed using [trimStartFrame] and [trimDurationInFrames].
///
/// Example:
/// ```dart
/// VideoSequence(
///   startFrame: 0,
///   durationInFrames: 150,
///   assetPath: 'assets/intro.mp4',
///   trimStartFrame: 30, // Skip first second (at 30fps)
///   trimDurationInFrames: 120, // Use 4 seconds of source video
/// )
/// ```
class VideoSequence extends Sequence {
  /// Path to the video asset (e.g., 'assets/video.mp4').
  final String assetPath;

  /// The frame in the source video to start playing from.
  ///
  /// Defaults to 0 (start of video).
  final int trimStartFrame;

  /// The duration of the source video to play in frames.
  ///
  /// If 0, plays to the end of the source video.
  final int trimDurationInFrames;

  /// Creates a video sequence from an asset file.
  const VideoSequence({
    super.key,
    required super.startFrame,
    required super.durationInFrames,
    required this.assetPath,
    this.trimStartFrame = 0,
    this.trimDurationInFrames = 0,
    super.child = const SizedBox(),
  });

  @override
  SequenceConfig toSequenceConfig() {
    return SequenceConfig.video(
      startFrame: startFrame,
      durationInFrames: durationInFrames,
      assetPath: assetPath,
      trimStartFrame: trimStartFrame,
      trimDurationInFrames: trimDurationInFrames,
    );
  }
}
