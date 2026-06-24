import 'dart:io';

import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/audio/encoding/audio_mix_plan.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
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
/// Each sfx track's `at:` trigger is resolved to a composition frame by the
/// shared [resolveAudioTrack] and threaded into
/// its [AudioTrackNode.delayMs] (`= frame / fps * 1000` ms, which `adelay`
/// shifts the track by); a music track carries no `at:` and never delays.
/// [totalFrames] is the composition window the sfx `at:` resolves against, so a
/// relative `Trigger.at` measures its fraction against the whole render.
/// Pass [extraNodes] to add already-staged tracks to the mix (the clip-embedded
/// audio the render layer stages from a video file); they join the `amix` after
/// the declared [tracks].
Future<AudioMixPlan> stageAudioMix({
  required List<Audio> tracks,
  required MediaResolver resolver,
  required Directory sandbox,
  required int fps,
  int totalFrames = 0,
  List<AudioTrackNode> extraNodes = const [],
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
  nodes.addAll(extraNodes);
  return buildAudioMixPlan(nodes);
}

/// Builds the FFmpeg [AudioTrackNode] for [track] from the shared, neutral
/// [resolveAudioTrack] resolution, so the FFmpeg mix and the on-device
/// `resolveAudioMix` delay, trim, gain, fade, and loop a track identically.
AudioTrackNode _nodeFor(
  Audio track, {
  required String name,
  required int fps,
  required TimeScopeData scope,
}) => AudioTrackNode.fromResolved(
  resolveAudioTrack(track, fps: fps, scope: scope),
  name: name,
);
