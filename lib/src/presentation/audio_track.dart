import 'package:flutter/widgets.dart';

import '../domain/audio_config.dart';
import 'audio_source.dart';

/// Declaratively attaches an audio track to the video composition.
///
/// All time values are in frames for consistency with the video timeline.
///
/// Example:
/// ```dart
/// AudioTrack(
///   source: AudioSource.asset('audio/background.mp3'),
///   startFrame: 0,
///   durationInFrames: 300, // 10 seconds at 30fps
///   trimStartFrame: 90,    // Start 3 seconds into the audio
///   fadeInFrames: 30,      // 1 second fade in
///   fadeOutFrames: 30,     // 1 second fade out
///   volume: 0.8,
/// )
/// ```
class AudioTrack extends StatelessWidget {
  /// The audio source to play.
  final AudioSource source;

  /// Frame in the video timeline where audio playback begins.
  final int startFrame;

  /// Duration of audio playback in frames.
  final int durationInFrames;

  /// Trim offset at the beginning of the source audio, in frames.
  ///
  /// For example, at 30fps, `trimStartFrame: 90` skips the first 3 seconds.
  final int trimStartFrame;

  /// Optional trim offset at the end of the source audio, in frames.
  final int? trimEndFrame;

  /// Volume multiplier (0.0 = silent, 1.0 = original volume).
  final double volume;

  /// Duration of fade-in from silence, in frames.
  final int fadeInFrames;

  /// Duration of fade-out to silence, in frames.
  final int fadeOutFrames;

  /// Whether to loop the audio if it's shorter than [durationInFrames].
  final bool loop;

  /// Optional sync configuration for timing this audio to visual elements.
  final AudioSyncConfig? sync;

  /// Optional child widget (usually not needed).
  final Widget child;

  const AudioTrack({
    super.key,
    required this.source,
    required this.startFrame,
    required this.durationInFrames,
    this.trimStartFrame = 0,
    this.trimEndFrame,
    this.volume = 1.0,
    this.fadeInFrames = 0,
    this.fadeOutFrames = 0,
    this.loop = false,
    this.sync,
    this.child = const SizedBox.shrink(),
  });

  /// Creates an audio track that syncs its start to a SyncAnchor.
  ///
  /// The audio will start when the referenced anchor starts, plus any offset.
  ///
  /// Example:
  /// ```dart
  /// AudioTrack.syncStart(
  ///   source: AudioSource.asset('intro.mp3'),
  ///   syncWithAnchor: 'intro_text',
  ///   startOffset: -15,  // Start 15 frames before the text appears
  ///   durationInFrames: 150,
  /// )
  /// ```
  factory AudioTrack.syncStart({
    Key? key,
    required AudioSource source,
    required String syncWithAnchor,
    int startOffset = 0,
    required int durationInFrames,
    int trimStartFrame = 0,
    int? trimEndFrame,
    double volume = 1.0,
    int fadeInFrames = 0,
    int fadeOutFrames = 0,
    bool loop = false,
    SyncBehavior behavior = SyncBehavior.stopWhenEnds,
    Widget child = const SizedBox.shrink(),
  }) {
    return AudioTrack(
      key: key,
      source: source,
      startFrame: 0, // Will be resolved from anchor
      durationInFrames: durationInFrames,
      trimStartFrame: trimStartFrame,
      trimEndFrame: trimEndFrame,
      volume: volume,
      fadeInFrames: fadeInFrames,
      fadeOutFrames: fadeOutFrames,
      loop: loop,
      sync: AudioSyncConfig(
        syncStartWithAnchor: syncWithAnchor,
        startOffset: startOffset,
        behavior: behavior,
      ),
      child: child,
    );
  }

  /// Creates an audio track that syncs both start and end to SyncAnchors.
  ///
  /// The audio duration is automatically calculated to span from the start
  /// anchor to the end anchor. Use [behavior] to control whether audio
  /// loops to match the duration or stops when it ends.
  ///
  /// Example:
  /// ```dart
  /// AudioTrack.syncRange(
  ///   source: AudioSource.asset('scene_music.mp3'),
  ///   syncStartWithAnchor: 'scene_start',
  ///   syncEndWithAnchor: 'scene_end',
  ///   startOffset: 0,
  ///   endOffset: 30,  // Extend 30 frames past scene end for fade out
  ///   behavior: SyncBehavior.loopToMatch,
  /// )
  /// ```
  factory AudioTrack.syncRange({
    Key? key,
    required AudioSource source,
    required String syncStartWithAnchor,
    required String syncEndWithAnchor,
    int startOffset = 0,
    int endOffset = 0,
    int trimStartFrame = 0,
    int? trimEndFrame,
    double volume = 1.0,
    int fadeInFrames = 0,
    int fadeOutFrames = 0,
    SyncBehavior behavior = SyncBehavior.stopWhenEnds,
    Widget child = const SizedBox.shrink(),
  }) {
    return AudioTrack(
      key: key,
      source: source,
      startFrame: 0, // Will be resolved from anchor
      durationInFrames: 0, // Will be resolved from anchors
      trimStartFrame: trimStartFrame,
      trimEndFrame: trimEndFrame,
      volume: volume,
      fadeInFrames: fadeInFrames,
      fadeOutFrames: fadeOutFrames,
      loop: false, // Will be set based on behavior during resolution
      sync: AudioSyncConfig(
        syncStartWithAnchor: syncStartWithAnchor,
        syncEndWithAnchor: syncEndWithAnchor,
        startOffset: startOffset,
        endOffset: endOffset,
        behavior: behavior,
      ),
      child: child,
    );
  }

  /// Exposes the serializable configuration used by the encoder.
  AudioTrackConfig toAudioConfig() => AudioTrackConfig(
    source: source.toConfig(),
    startFrame: startFrame,
    durationInFrames: durationInFrames,
    trimStartFrame: trimStartFrame,
    trimEndFrame: trimEndFrame,
    volume: volume,
    fadeInFrames: fadeInFrames,
    fadeOutFrames: fadeOutFrames,
    loop: loop,
    sync: sync,
  );

  @override
  Widget build(BuildContext context) => child;
}
