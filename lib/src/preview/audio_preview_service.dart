import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../domain/audio_config.dart';
import '../domain/render_config.dart';
import '../presentation/time_consumer.dart';

// Platform check - just_audio doesn't support Linux
bool get _isAudioPreviewSupported {
  if (kIsWeb) return true; // Web is supported
  // just_audio doesn't support Linux
  return defaultTargetPlatform != TargetPlatform.linux;
}

class AudioPreviewService {
  final List<_PreviewAudioTrack> _tracks = [];
  bool _isInitialized = false;
  bool _isPlaying = false;
  double _fps = 30;
  bool _isAttached = false;
  bool _isSupported = _isAudioPreviewSupported;

  Future<void> initialize(RenderConfig config) async {
    await dispose();
    if (config.audioTracks.isEmpty) {
      return;
    }

    // Check if audio preview is supported on this platform
    // Skip on Linux since just_audio doesn't support it
    if (!_isSupported) {
      return;
    }

    try {
      _fps = config.timeline.fps.toDouble();
      for (final track in config.audioTracks) {
        try {
          final player = ja.AudioPlayer();
          final source = await _createAudioSource(track.source);
          await player.setAudioSource(source);
          _tracks.add(
            _PreviewAudioTrack(player: player, config: track, fps: _fps),
          );
        } catch (e) {
          // If we can't create a player, mark as unsupported and skip remaining tracks
          if (e is MissingPluginException) {
            _isSupported = false;
            // Dispose any players we already created
            for (final existingTrack in _tracks) {
              try {
                await existingTrack.player.dispose();
              } catch (_) {
                // Ignore disposal errors
              }
            }
            _tracks.clear();
            return;
          }
          // Re-throw other errors
          rethrow;
        }
      }
      _isInitialized = true;
      _attachFrameSync();
    } catch (e) {
      // Platform not supported or other error - gracefully degrade
      if (e is MissingPluginException) {
        _isSupported = false;
      }
      await dispose();
    }
  }

  Future<void> play() async {
    if (!_isSupported || !_isInitialized) return;
    try {
      _isPlaying = true;
      for (final track in _tracks) {
        await track.player.play();
      }
    } catch (e) {
      // Silently fail on unsupported platforms
      _isPlaying = false;
    }
  }

  Future<void> pause() async {
    if (!_isSupported || !_isInitialized) return;
    try {
      _isPlaying = false;
      for (final track in _tracks) {
        await track.player.pause();
      }
    } catch (e) {
      // Silently fail on unsupported platforms
    }
  }

  Future<void> seekToFrame(int frame) async {
    if (!_isSupported || !_isInitialized) return;
    try {
      final futures = <Future<void>>[];
      for (final track in _tracks) {
        futures.add(track.seekToFrame(frame, _isPlaying));
      }
      await Future.wait(futures);
    } catch (e) {
      // Silently fail on unsupported platforms
    }
  }

  Future<void> dispose() async {
    _detachFrameSync();
    _isInitialized = false;
    _isPlaying = false;
    if (!_isSupported) {
      _tracks.clear();
      return;
    }
    try {
      for (final track in _tracks) {
        await track.player.dispose();
      }
    } catch (e) {
      // Silently fail on unsupported platforms
    }
    _tracks.clear();
  }

  Future<ja.AudioSource> _createAudioSource(AudioSourceConfig source) async {
    switch (source.type) {
      case AudioSourceType.asset:
        return ja.AudioSource.asset(source.uri);
      case AudioSourceType.file:
        return ja.AudioSource.uri(Uri.file(source.uri));
      case AudioSourceType.url:
        return ja.AudioSource.uri(Uri.parse(source.uri));
    }
  }

  void _attachFrameSync() {
    if (_isAttached) return;
    FrameProvider.addFrameListener(_handleFrameChange);
    _isAttached = true;
  }

  void _detachFrameSync() {
    if (!_isAttached) return;
    FrameProvider.removeFrameListener(_handleFrameChange);
    _isAttached = false;
  }

  void _handleFrameChange(int frame) {
    unawaited(seekToFrame(frame));
  }
}

class _PreviewAudioTrack {
  final ja.AudioPlayer player;
  final AudioTrackConfig config;
  final double fps;

  _PreviewAudioTrack({
    required this.player,
    required this.config,
    required this.fps,
  });

  Future<void> seekToFrame(int frame, bool shouldPlay) async {
    try {
      final relativeFrame = frame - config.startFrame;
      if (relativeFrame < 0) {
        await _reset(shouldPlay);
        return;
      }

      if (relativeFrame > config.durationInFrames && !config.loop) {
        await player.pause();
        await player.seek(_duration);
        return;
      }

      final position = _calculatePosition(relativeFrame);
      await player.seek(position);
      final effectiveVolume = _calculateVolume(relativeFrame);
      await player.setVolume(effectiveVolume);

      if (shouldPlay) {
        await player.play();
      } else {
        await player.pause();
      }
    } catch (e) {
      // Silently fail on unsupported platforms
    }
  }

  Duration _calculatePosition(int relativeFrame) {
    final relativeMs = (relativeFrame / fps * 1000).round();
    final trackDurationMs = (config.durationInFrames / fps * 1000).round();
    int playbackMs = relativeMs;

    if (config.loop && trackDurationMs > 0) {
      playbackMs = relativeMs % trackDurationMs;
    } else if (relativeMs > trackDurationMs) {
      playbackMs = trackDurationMs;
    }

    // Convert trim frames to milliseconds for audio player
    final trimStartMs = config.trimStartFrameToMs(fps.round());
    final trimEndMs = config.trimEndFrameToMs(fps.round());
    final maxPlayableMs = trimEndMs != null
        ? math.max(0, trimEndMs - trimStartMs)
        : null;
    if (maxPlayableMs != null) {
      playbackMs = math.min(playbackMs, maxPlayableMs);
    }

    final absoluteMs = trimStartMs + playbackMs;
    return Duration(milliseconds: absoluteMs);
  }

  double _calculateVolume(int relativeFrame) {
    var multiplier = 1.0;
    if (config.fadeInFrames > 0 && relativeFrame >= 0) {
      final fadeProgress = math.min(relativeFrame / config.fadeInFrames, 1.0);
      multiplier *= fadeProgress;
    }

    final framesUntilEnd = config.durationInFrames - relativeFrame;
    if (config.fadeOutFrames > 0 && framesUntilEnd < config.fadeOutFrames) {
      final fadeProgress = math.max(framesUntilEnd / config.fadeOutFrames, 0.0);
      multiplier *= fadeProgress;
    }

    return math.max(config.volume * multiplier, 0.0);
  }

  Duration get _duration =>
      Duration(milliseconds: (config.durationInFrames / fps * 1000).round());

  Future<void> _reset(bool shouldPlay) async {
    try {
      await player.pause();
      await player.seek(
        Duration(milliseconds: config.trimStartFrameToMs(fps.round())),
      );
      if (shouldPlay) {
        await player.play();
      }
    } catch (e) {
      // Silently fail on unsupported platforms
    }
  }
}

final audioPreviewServiceProvider = Provider<AudioPreviewService>((ref) {
  final service = AudioPreviewService();
  ref.onDispose(() {
    // Wrap disposal in a safe way that won't throw
    // Use unawaited to prevent errors from propagating
    unawaited(
      service.dispose().catchError((error) {
        // Silently ignore all disposal errors, especially MissingPluginException
        // This can happen on Linux when just_audio tries to dispose players globally
      }),
    );
  });
  return service;
});
