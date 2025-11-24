import 'package:flutter/material.dart';
import 'clip.dart';

/// A clip that renders a video asset.
///
/// Use this to include external video files in your composition.
class VideoClip extends Clip {
  /// Path to the video asset (e.g., 'assets/video.mp4').
  final String assetPath;

  /// The frame in the source video to start playing from.
  final int trimStartFrame;

  /// The duration of the source video to play.
  final int trimDurationInFrames;

  const VideoClip({
    super.key,
    required super.startFrame,
    required super.durationInFrames,
    required this.assetPath,
    this.trimStartFrame = 0,
    this.trimDurationInFrames = 0,
    super.child = const SizedBox(),
  });
}
