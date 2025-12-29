import 'package:flutter/widgets.dart';

import 'audio_source.dart';
import 'audio_track.dart';
import 'video_composition.dart';

/// Convenience widget for adding background music that spans the full timeline.
///
/// All time values are in frames for consistency with the video timeline.
///
/// Example:
/// ```dart
/// VideoComposition(
///   fps: 30,
///   durationInFrames: 300,
///   child: BackgroundAudio(
///     source: AudioSource.asset('audio/music.mp3'),
///     fadeInFrames: 30,  // 1 second fade in
///     fadeOutFrames: 60, // 2 second fade out
///     volume: 0.5,
///     child: MyContent(),
///   ),
/// )
/// ```
class BackgroundAudio extends StatelessWidget {
  /// The audio source for the background music.
  final AudioSource source;

  /// Trim offset at the beginning of the source audio, in frames.
  final int trimStartFrame;

  /// Optional trim offset at the end of the source audio, in frames.
  final int? trimEndFrame;

  /// Volume multiplier (0.0 = silent, 1.0 = original volume).
  final double volume;

  /// Duration of fade-in from silence, in frames.
  final int fadeInFrames;

  /// Duration of fade-out to silence, in frames.
  final int fadeOutFrames;

  /// Whether to loop the audio (defaults to true for background music).
  final bool loop;

  /// Child widget to display.
  final Widget child;

  const BackgroundAudio({
    super.key,
    required this.source,
    this.trimStartFrame = 0,
    this.trimEndFrame,
    this.volume = 1.0,
    this.fadeInFrames = 0,
    this.fadeOutFrames = 0,
    this.loop = true,
    this.child = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    final composition = VideoComposition.of(context);
    if (composition == null) {
      throw StateError(
        'BackgroundAudio must be placed inside a VideoComposition.',
      );
    }

    return AudioTrack(
      source: source,
      startFrame: 0,
      durationInFrames: composition.durationInFrames,
      trimStartFrame: trimStartFrame,
      trimEndFrame: trimEndFrame,
      volume: volume,
      fadeInFrames: fadeInFrames,
      fadeOutFrames: fadeOutFrames,
      loop: loop,
      child: child,
    );
  }
}
