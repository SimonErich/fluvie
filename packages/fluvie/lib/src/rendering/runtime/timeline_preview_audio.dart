import 'dart:async';
import 'dart:math' as math;

import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/core/audio/audio_automation.dart';
import 'package:fluvie/src/rendering/runtime/preview_audio_controller.dart';

/// A platform player for a single original audio/video source.
abstract interface class PreviewAudioPlayer {
  /// Duration of the loaded original.
  Duration get duration;

  /// Current source position.
  Duration get position;

  /// Whether the source is playing.
  bool get playing;

  /// Current playback rate.
  double get rate;

  /// Current linear gain.
  double get volume;

  /// Seeks within the original.
  Future<void> seek(Duration position);

  /// Updates playback rate.
  Future<void> setRate(double value);

  /// Updates gain.
  Future<void> setVolume(double value);

  /// Starts playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Releases the platform source.
  Future<void> dispose();
}

/// Creates a loaded platform player from an encoder-neutral audio track.
typedef PreviewAudioPlayerFactory = Future<PreviewAudioPlayer> Function(ResolvedAudioTrack track);

/// Plays the encoder's actual mix plan against the canonical preview clock.
/// Original clip audio, trims, delays, loops, rates and fades share render math.
/// Concurrent clock ticks coalesce while platform I/O is pending.
final class TimelinePreviewAudioController implements PreviewAudioController {
  /// The mix can be resolved after VideoPreview's media probe completes.
  TimelinePreviewAudioController({required this.mix, required this.createPlayer});

  /// Reads the ready composition's encoder plan.
  final ResolvedAudioMix Function() mix;

  /// Platform media I/O; no timeline math belongs in this adapter.
  final PreviewAudioPlayerFactory createPlayer;
  final _players = <({ResolvedAudioTrack track, PreviewAudioPlayer player})>[];
  Future<void>? _initializing;
  Future<void>? _syncing;
  ({Duration position, bool playing, double rate})? _pending;
  double _masterVolume = 1;
  bool _disposed = false;

  @override
  Future<void> activate() =>
      _initializing ??= _prepare().catchError((Object error, StackTrace stack) {
        _initializing = null;
        Error.throwWithStackTrace(error, stack);
      });

  Future<void> _prepare() async {
    if (_disposed) return;
    try {
      final plan = mix();
      _masterVolume = plan.masterVolume;
      for (final track in plan.tracks) {
        final player = await createPlayer(track);
        if (_disposed) {
          await player.dispose();
          return;
        }
        _players.add((track: track, player: player));
      }
    } on Object {
      for (final lane in _players) {
        await lane.player.dispose();
      }
      _players.clear();
      _initializing = null;
      rethrow;
    }
  }

  @override
  Future<void> synchronize({
    required Duration position,
    required bool playing,
    required double rate,
  }) {
    if (_disposed || _players.isEmpty) return Future<void>.value();
    if (!rate.isFinite || rate <= 0) throw ArgumentError.value(rate, 'rate');
    _pending = (position: position, playing: playing, rate: rate);
    return _syncing ??= _drain().whenComplete(() => _syncing = null);
  }

  Future<void> _drain() async {
    while (!_disposed && _pending != null) {
      final state = _pending!;
      _pending = null;
      final seconds = state.position.inMicroseconds / Duration.microsecondsPerSecond;
      for (final lane in _players) {
        final track = lane.track;
        final player = lane.player;
        final local = seconds - track.delayMs / 1000;
        final start = track.trimStartSeconds ?? 0;
        final end = math.min(
          track.trimEndSeconds ?? double.infinity,
          player.duration.inMicroseconds / Duration.microsecondsPerSecond,
        );
        final mapped =
            track.timeMap?.sourceSecondsAt(local.clamp(0.0, double.infinity)) ??
            local * track.tempo;
        var source = start + mapped;
        final span = end - start;
        if (track.loop && span > 0 && local >= 0) source = start + mapped % span;
        final audible =
            state.playing &&
            local >= 0 &&
            span > 0 &&
            (track.endSeconds == null || seconds < track.endSeconds!) &&
            (track.loop || source < end);
        var gain = track.volume * _masterVolume * audioVolumeAt(track.volumeEnvelope, local);
        if (track.fadeInSeconds case final fade? when fade > 0) {
          gain *= (local / fade).clamp(0.0, 1.0);
        }
        if (track.fadeOutSeconds case final fade? when fade > 0) {
          gain *= ((track.fadeOutStartSeconds + fade - seconds) / fade).clamp(0.0, 1.0);
        }
        if ((player.position.inMicroseconds / Duration.microsecondsPerSecond - source).abs() > .2) {
          await player.seek(
            Duration(
              microseconds:
                  (source.clamp(start, math.max(start, end)) * Duration.microsecondsPerSecond)
                      .round(),
            ),
          );
        }
        final map = track.timeMap;
        final tempo = map == null
            ? track.tempo
            : (map.sourceSecondsAt(math.max(0, local) + 1 / map.fps) -
                      map.sourceSecondsAt(math.max(0, local))) *
                  map.fps;
        final speed = state.rate * (tempo > 0 ? tempo : track.tempo);
        if (player.rate != speed) await player.setRate(speed);
        final volume = gain.clamp(0.0, 1.0);
        if (player.volume != volume) await player.setVolume(volume);
        if (audible != player.playing) {
          if (audible) {
            await player.play();
          } else {
            await player.pause();
          }
        }
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pending = null;
    try {
      await _syncing;
      await _initializing;
    } on Object {
      /* Failed initialization has already released its players. */
    }
    for (final lane in _players) {
      await lane.player.dispose();
    }
    _players.clear();
  }
}
