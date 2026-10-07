import 'package:fluvie/rendering.dart';
import 'package:meta/meta.dart';

/// One audio track ready for the native mixer: a materialized local [path] plus
/// the timing and gain the encoder applies.
///
/// Built from a Fluvie [ResolvedAudioTrack] once its `source` has been
/// materialized to a local file (see `MobileAudioMaterializer`). All times are in
/// seconds; [delayMs] shifts a sound effect later. The native side decodes the
/// file, trims, delays, gains, and fades it, then mixes it with the other tracks.
@immutable
final class MobileAudioTrack {
  /// Creates a track over the materialized [path].
  const MobileAudioTrack({
    required this.path,
    this.delayMs = 0,
    this.volume = 1,
    this.volumeEnvelope = const [],
    this.endSeconds,
    this.trimStartSeconds,
    this.trimEndSeconds,
    this.fadeInSeconds,
    this.fadeOutSeconds,
    this.fadeOutStartSeconds = 0,
    this.loop = false,
    this.tempo = 1,
    this.timeMap,
  });

  /// Builds a track from a resolved Fluvie [track] materialized to local [path].
  factory MobileAudioTrack.fromResolved(ResolvedAudioTrack track, {required String path}) =>
      MobileAudioTrack(
        path: path,
        delayMs: track.delayMs,
        volume: track.volume,
        volumeEnvelope: track.volumeEnvelope,
        endSeconds: track.endSeconds,
        trimStartSeconds: track.trimStartSeconds,
        trimEndSeconds: track.trimEndSeconds,
        fadeInSeconds: track.fadeInSeconds,
        fadeOutSeconds: track.fadeOutSeconds,
        fadeOutStartSeconds: track.fadeOutStartSeconds,
        loop: track.loop,
        tempo: track.tempo,
        timeMap: track.timeMap,
      );

  /// The materialized local audio file to decode and mix.
  final String path;

  /// The playback-rate multiplier the native mixer applies (`1` leaves the
  /// stream alone) — a retimed clip's audio must move with its picture.
  final double tempo;

  /// Integrated output-to-source clock for positive speed ramps.
  final AudioTimeMap? timeMap;

  /// How far to shift the track later, in milliseconds (`0` plays at the start).
  final int delayMs;

  /// Linear gain applied to the track (`1` plays the file as authored).
  final double volume;

  /// Gain samples relative to the audible start, shared with FFmpeg.
  final List<AudioVolumePoint> volumeEnvelope;

  /// Exclusive composition end of a scene-owned track.
  final double? endSeconds;

  /// Where playback begins in the source file, in seconds; `null` plays from 0.
  final double? trimStartSeconds;

  /// Where playback ends in the source file, in seconds; `null` plays to the end.
  final double? trimEndSeconds;

  /// How long the track ramps in from silence, in seconds; `null` for no fade.
  final double? fadeInSeconds;

  /// How long the track ramps out to silence, in seconds; `null` for no fade.
  final double? fadeOutSeconds;

  /// When the fade-out begins, in seconds (only used with [fadeOutSeconds]).
  final double fadeOutStartSeconds;

  /// Whether the track repeats to fill the render window.
  final bool loop;

  /// The argument map handed to the platform method channel.
  Map<String, Object?> toArguments() => {
    'path': path,
    'delayMs': delayMs,
    'volume': volume,
    'trimStartSeconds': trimStartSeconds,
    'trimEndSeconds': trimEndSeconds,
    'fadeInSeconds': fadeInSeconds,
    'fadeOutSeconds': fadeOutSeconds,
    'fadeOutStartSeconds': fadeOutStartSeconds,
    'loop': loop,
    'tempo': tempo,
    if (timeMap != null) 'timeMap': {'fps': timeMap!.fps, 'sourceSeconds': timeMap!.sourceSeconds},
    if (volumeEnvelope.isNotEmpty)
      'volumeEnvelope': [
        for (final point in volumeEnvelope) {'seconds': point.seconds, 'value': point.value},
      ],
    if (endSeconds != null) 'endSeconds': endSeconds,
  };
}
