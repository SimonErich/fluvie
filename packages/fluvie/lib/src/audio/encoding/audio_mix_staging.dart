import 'dart:io';

import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/audio/encoding/audio_mix_plan.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie/src/audio/encoding/sfx_trigger_resolver.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Stages every pre-resolved audio track into the render [sandbox] and builds
/// the encoder [AudioMixPlan].
///
/// Each track's materialized source (already fetched by
/// `MediaResolver.preResolveAudio`) is copied into [sandbox] under a *bare*
/// name the encoder can `-i` without a path separator, then turned into one
/// `AudioTrackNode` whose volume, trim, and fades are resolved against [fps].
/// The plan's `amix` combines them. A track-less composition stages nothing and
/// returns an empty plan, so the encoder's `-an` path is unchanged.
///
/// Each sfx track's `at:` trigger is resolved to a composition frame by
/// [resolveSfxFrame] and threaded into
/// its [AudioTrackNode.delayMs] (`= frame / fps * 1000` ms, which `adelay`
/// shifts the track by); a music track carries no `at:` and never delays.
/// [totalFrames] is the composition window the sfx `at:` resolves against, so a
/// relative `Trigger.at` measures its fraction against the whole render.
Future<AudioMixPlan> stageAudioMix({
  required List<Audio> tracks,
  required MediaResolver resolver,
  required Directory sandbox,
  required int fps,
  int totalFrames = 0,
}) async {
  final nodes = <AudioTrackNode>[];
  final scope = TimeScopeData(fps: fps, startFrame: 0, durationFrames: totalFrames);
  for (var i = 0; i < tracks.length; i++) {
    final track = tracks[i];
    final source = track.audioSource;
    final materialized = resolver.materializedAudioPathFor(source);
    final name = 'audio_${i}_${source.cacheKey}';
    await File(materialized).copy('${sandbox.path}/$name');
    nodes.add(_nodeFor(track, name: name, fps: fps, scope: scope));
  }
  return buildAudioMixPlan(nodes);
}

AudioTrackNode _nodeFor(
  Audio track, {
  required String name,
  required int fps,
  required TimeScopeData scope,
}) {
  final trim = track.trim;
  final resolvedTrim = trim?.resolveFrames(scope);
  final trimStartSeconds = resolvedTrim == null ? null : resolvedTrim.start / fps;
  final trimEndSeconds = resolvedTrim == null ? null : resolvedTrim.end / fps;
  final fadeOutSeconds = _seconds(track.fadeOut, scope, fps);
  return AudioTrackNode(
    name: name,
    delayMs: track.isSfx ? _delayMsFor(track, scope, fps) : 0,
    volume: track.volume,
    trimStartSeconds: trimStartSeconds,
    trimEndSeconds: trimEndSeconds,
    fadeInSeconds: _seconds(track.fadeIn, scope, fps),
    fadeOutSeconds: fadeOutSeconds,
    fadeOutStartSeconds: fadeOutSeconds == null
        ? 0
        : _fadeOutStartSeconds(
            fadeOutSeconds: fadeOutSeconds,
            windowSeconds: scope.durationFrames / fps,
            // A looping bed fills the whole window; only a non-looping trim ends
            // the audio sooner than the window does.
            trimStartSeconds: track.loop ? null : trimStartSeconds,
            trimEndSeconds: track.loop ? null : trimEndSeconds,
          ),
  );
}

/// Where the fade-out begins, in seconds, so the ramp reaches silence at the
/// END of the track's audible window — never at time 0 (which would mute the
/// whole bed). The window is the composition span [windowSeconds], shortened to
/// the trimmed length when a non-looping trim ends first. Clamped to `0` so a
/// fade longer than the window still starts at the beginning instead of going
/// negative.
double _fadeOutStartSeconds({
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
int _delayMsFor(Audio track, TimeScopeData scope, int fps) {
  final frame = resolveSfxFrame(track.at, scope);
  return frame <= 0 ? 0 : (frame / fps * 1000).round();
}

double? _seconds(Time? time, TimeScopeData scope, int fps) {
  if (time == null) return null;
  final frames = time.resolveFrames(scope);
  return frames > 0 ? frames / fps : null;
}
