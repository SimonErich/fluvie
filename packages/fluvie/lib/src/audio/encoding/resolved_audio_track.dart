import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/audio/encoding/sfx_trigger_resolver.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:meta/meta.dart';

/// One audio track resolved to encoder-neutral numbers: the [source] to play
/// plus the timing and gain an encoder needs, with no FFmpeg in sight.
///
/// This is what `resolveAudioMix` returns for an on-device or otherwise custom
/// encoder. All times are in seconds (resolved against the render fps and
/// window); the sfx offset is [delayMs]. The FFmpeg path builds its
/// `AudioTrackNode` from the very same numbers, so a desktop render and an
/// on-device render delay, trim, gain, and fade a track identically.
@immutable
final class ResolvedAudioTrack {
  /// Creates a resolved track over the authored [source].
  const ResolvedAudioTrack({
    required this.source,
    this.delayMs = 0,
    this.volume = 1,
    this.trimStartSeconds,
    this.trimEndSeconds,
    this.fadeInSeconds,
    this.fadeOutSeconds,
    this.fadeOutStartSeconds = 0,
    this.loop = false,
  });

  /// The audio source as authored: an asset key, a file path, or a URL. A
  /// custom encoder materializes it to a local file before decoding.
  final String source;

  /// How far to shift the track later, in milliseconds (`0` plays at the start).
  final int delayMs;

  /// Linear gain applied to the track (`1` plays the file as authored).
  final double volume;

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
}

/// A whole render's audio resolved to encoder-neutral [tracks] plus a final
/// [masterVolume], ready for a non-FFmpeg encoder to mix.
@immutable
final class ResolvedAudioMix {
  /// Creates a resolved mix.
  const ResolvedAudioMix({required this.tracks, this.masterVolume = 1});

  /// The per-track resolved audio, in deterministic declaration order.
  final List<ResolvedAudioTrack> tracks;

  /// The final gain applied after the tracks are mixed together.
  final double masterVolume;

  /// Whether there is no audio to encode.
  bool get isEmpty => tracks.isEmpty;
}

/// Resolves one [track] to its encoder-neutral [ResolvedAudioTrack], against the
/// render [fps] and composition [scope].
///
/// This is the single source of the mix's timing math: the FFmpeg
/// `AudioTrackNode` and the on-device `resolveAudioMix` both build from it, so a
/// desktop render and an on-device render delay, trim, gain, and fade a track
/// the same way. Pure and deterministic.
ResolvedAudioTrack resolveAudioTrack(
  Audio track, {
  required int fps,
  required TimeScopeData scope,
}) {
  final resolvedTrim = track.trim?.resolveFrames(scope);
  final trimStartSeconds = resolvedTrim == null ? null : resolvedTrim.start / fps;
  final trimEndSeconds = resolvedTrim == null ? null : resolvedTrim.end / fps;
  final fadeOutSeconds = _seconds(track.fadeOut, scope, fps);
  return ResolvedAudioTrack(
    source: track.source,
    delayMs: track.isSfx ? _delayMs(track, scope, fps) : 0,
    volume: track.volume,
    trimStartSeconds: trimStartSeconds,
    trimEndSeconds: trimEndSeconds,
    fadeInSeconds: _seconds(track.fadeIn, scope, fps),
    fadeOutSeconds: fadeOutSeconds,
    fadeOutStartSeconds: fadeOutSeconds == null
        ? 0
        : _fadeOutStart(
            fadeOutSeconds: fadeOutSeconds,
            windowSeconds: scope.durationFrames / fps,
            // A looping bed fills the whole window; only a non-looping trim ends
            // the audio sooner than the window does.
            trimStartSeconds: track.loop ? null : trimStartSeconds,
            trimEndSeconds: track.loop ? null : trimEndSeconds,
          ),
    loop: track.loop,
  );
}

/// Where the fade-out begins, in seconds, so the ramp reaches silence at the END
/// of the track's audible window — never at time 0 (which would mute the whole
/// bed). The window is the composition span, shortened to the trimmed length when
/// a non-looping trim ends first. Clamped to `0`.
double _fadeOutStart({
  required double fadeOutSeconds,
  required double windowSeconds,
  required double? trimStartSeconds,
  required double? trimEndSeconds,
}) {
  var audioEndSeconds = windowSeconds;
  if (trimStartSeconds != null && trimEndSeconds != null) {
    final trimLength = trimEndSeconds - trimStartSeconds;
    if (trimLength < audioEndSeconds) audioEndSeconds = trimLength;
  }
  final start = audioEndSeconds - fadeOutSeconds;
  return start > 0 ? start : 0;
}

/// The sfx delay in milliseconds: the resolved `at:` frame converted against
/// [fps] (`frame / fps * 1000`), or `0` when the effect fires at the start.
int _delayMs(Audio track, TimeScopeData scope, int fps) {
  final frame = resolveSfxFrame(track.at, scope);
  return frame <= 0 ? 0 : (frame / fps * 1000).round();
}

double? _seconds(Time? time, TimeScopeData scope, int fps) {
  if (time == null) return null;
  final frames = time.resolveFrames(scope);
  return frames > 0 ? frames / fps : null;
}
