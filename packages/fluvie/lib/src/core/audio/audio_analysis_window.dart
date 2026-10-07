import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:meta/meta.dart';

/// One audible source interval placed on the composition clock.
/// Separate tracks can use the same source with different trims and delays.
@immutable
final class AudioAnalysisWindow {
  /// Creates an interval; all times are resolved before analysis.
  AudioAnalysisWindow({
    required this.source,
    required this.sourceStart,
    required this.sourceFrames,
    required this.startFrame,
    required this.endFrame,
    required this.fps,
    this.loop = false,
  }) {
    if (fps < 1 ||
        sourceStart.isNegative ||
        sourceFrames < 1 ||
        startFrame < 0 ||
        endFrame <= startFrame) {
      throw ArgumentError('Audio analysis needs a positive source and composition interval.');
    }
  }

  /// Authored source, materialized by the repository.
  final AudioSource source;

  /// Trim start in source time.
  final Duration sourceStart;

  /// Maximum source frames needed, before loop repetition.
  final int sourceFrames;

  /// Inclusive audible start on the composition clock.
  final int startFrame;

  /// Exclusive audible end on the composition clock.
  final int endFrame;

  /// Composition frames per second.
  final int fps;

  /// Whether the decoded interval repeats until [endFrame].
  final bool loop;

  @override
  bool operator ==(Object other) =>
      other is AudioAnalysisWindow &&
      source == other.source &&
      sourceStart == other.sourceStart &&
      sourceFrames == other.sourceFrames &&
      startFrame == other.startFrame &&
      endFrame == other.endFrame &&
      fps == other.fps &&
      loop == other.loop;
  @override
  int get hashCode =>
      Object.hash(source, sourceStart, sourceFrames, startFrame, endFrame, fps, loop);
}
