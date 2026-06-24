import 'dart:io';

import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie/src/composition/runtime/media_collector.dart' show ClipAudioPlan;
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// The [AudioSource] FFmpeg extracts a clip's embedded audio from: the clip's
/// own video file. FFmpeg reads `[N:a]` from a `-i video.mp4` input just as it
/// would from an audio file, so a clip's track needs no separate audio asset.
///
/// A memory clip has no file to extract from and is rejected with a
/// [FluvieRenderException].
AudioSource clipAudioSourceFor(MediaSource source) => switch (source) {
  FileSource(:final path) => AudioSource.file(path),
  AssetSource(:final name) => AudioSource.asset(name),
  NetworkSource(:final url) => AudioSource.network(url),
  MemorySource() => throw FluvieRenderException(
    'A MediaSource.memory clip cannot contribute embedded audio to the mix.',
  ),
};

/// Stages every clip's embedded audio into the render [sandbox] and returns one
/// [AudioTrackNode] per clip, ready to join the encoder `amix`.
///
/// Each clip's video file (already materialized by `MediaResolver.preResolveAudio`
/// through [clipAudioSourceFor]) is copied into [sandbox] under a bare name, then
/// turned into a node delayed to the clip's scene start (`startFrame`)
/// and trimmed to its scene window (`windowFrames`) at the clip's
/// volume and fade-in. This mirrors the on-device `resolveAudioMix` clip-audio
/// math exactly, so a desktop render and an on-device render mix a clip's audio
/// identically — and a generated video (for example Veo 3) rides the same path.
Future<List<AudioTrackNode>> stageClipAudio({
  required List<ClipAudioPlan> plans,
  required MediaResolver resolver,
  required Directory sandbox,
  required int fps,
  required int totalFrames,
}) async {
  final nodes = <AudioTrackNode>[];
  final scope = TimeScopeData(fps: fps, startFrame: 0, durationFrames: totalFrames);
  for (var i = 0; i < plans.length; i++) {
    final plan = plans[i];
    final source = clipAudioSourceFor(plan.source);
    final materialized = resolver.materializedAudioPathFor(source);
    final name = 'clip_audio_${i}_${source.cacheKey}';
    await File(materialized).copy('${sandbox.path}/$name');
    final fadeInFrames = plan.audio.fadeIn.resolveFrames(scope);
    nodes.add(
      AudioTrackNode(
        name: name,
        delayMs: (plan.startFrame / fps * 1000).round(),
        volume: plan.audio.volume,
        trimStartSeconds: 0,
        trimEndSeconds: plan.windowFrames / fps,
        fadeInSeconds: fadeInFrames > 0 ? fadeInFrames / fps : null,
      ),
    );
  }
  return nodes;
}
