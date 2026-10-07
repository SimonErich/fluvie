import 'dart:math' as math;

import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/audio_time_map.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/rendering/clip_audio_source.dart';
import 'package:fluvie/src/rendering/clip_audio_trim.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie_media/fluvie_media.dart' show MediaTimeline;

/// Resolves [video]'s declared `Audio` tracks into an encoder-neutral
/// [ResolvedAudioMix] for a non-FFmpeg encoder (such as `fluvie_mobile_encoder`).
///
/// It collects the tracks in deterministic declaration order and resolves every
/// track's delay, trim, gain, and fades against [fps] and the [totalFrames]
/// window — the same timing math the FFmpeg mix uses, so an on-device render
/// matches a desktop render. Pure and synchronous: it reads no files, so each
/// track keeps its authored [ResolvedAudioTrack.source]; the custom encoder
/// materializes those sources itself. The default render path never calls this;
/// it is the opt-in seam for custom encoders. A video with no audio yields an
/// empty mix.
///
/// Being pure, it cannot probe a clip, so a **trimmed** clip's embedded audio
/// needs [clipMetadata]: the probed source for one clip, which
/// `MediaResolver.clipMetadataFor` answers synchronously once the clip pre-pass
/// has run. Without it a trimmed clip throws rather than opening its audio at
/// zero while its picture opens at the trim. An untrimmed clip never needs it.
ResolvedAudioMix resolveAudioMix({
  required Video video,
  required int fps,
  int totalFrames = 0,
  GenerativeResolver? generative,
  ClipMetadata? Function(MediaSource source)? clipMetadata,
  List<ClipAudioPlan>? mountedClipPlans,
  MediaTimeline? Function(MediaSource source)? clipTimeline,
}) {
  final scope = TimeScopeData(fps: fps, startFrame: 0, durationFrames: totalFrames);
  final tracks = <ResolvedAudioTrack>[
    for (final track in collectAudioTracks(video, generative: generative))
      resolveAudioTrack(track, fps: fps, scope: scope),
    // A clip's embedded audio (including a generated video's, for example Veo 3)
    // plays where the clip plays: delayed to its own window start and trimmed
    // to the source time it is shown for (so sequential clips don't bleed).
    for (final plan
        in (mountedClipPlans ??
            collectClipAudioPlans(
              video.scenes,
              fps,
              sceneStartFrames: video.sceneStartFrames,
              generative: generative,
              overlays: video.overlays,
              totalFrames: video.totalFrames,
            )))
      // A reversed clip contributes nothing: see stageClipAudio for why.
      if (plan.speed >= 0 && (clipMetadata?.call(plan.source)?.hasAudio ?? true))
        _clipAudioTrack(plan, fps, clipMetadata, clipTimeline),
  ];
  return ResolvedAudioMix(tracks: tracks);
}

/// Resolves one clip-audio [plan] to an encoder-neutral track: its source (the
/// video itself — the encoder extracts the audio track), delayed to the clip's
/// own window start and trimmed to the source time it is shown for, at the
/// clip's authored volume, fade-in and rate.
///
/// The typed [ResolvedAudioTrack.audioSource] always rides along, so a memory
/// clip's bytes reach the staging pass; its string form is the same stable
/// `memory:<cacheKey>` diagnostic label a memory bed's `Audio.source` reads.
ResolvedAudioTrack _clipAudioTrack(
  ClipAudioPlan plan,
  int fps,
  ClipMetadata? Function(MediaSource source)? clipMetadata,
  MediaTimeline? Function(MediaSource source)? clipTimeline,
) {
  final source = clipAudioSourceFor(plan.source);
  final trim = resolveClipAudioTrimSeconds(
    trim: plan.trim,
    timeline: clipTimeline?.call(plan.source),
    meta: plan.trim == null ? null : clipMetadata?.call(plan.source),
    windowFrames: plan.windowFrames,
    fps: fps,
    sourceLabel: _sourceString(source),
    speed: plan.sourceTimeMap == null
        ? plan.speed
        : plan.sourceTimeMap!.last / (plan.windowFrames / fps),
  );
  final scope = TimeScopeData(fps: fps, startFrame: 0, durationFrames: plan.windowFrames);
  final fadeIn = plan.audio.fadeIn.resolveFrames(scope) / fps;
  final fadeOut = plan.audio.fadeOut.resolveFrames(scope) / fps;
  final delaySeconds = plan.startFrame / fps;
  final fadeOutStart = delaySeconds + plan.windowFrames / fps - fadeOut;
  return ResolvedAudioTrack(
    source: _sourceString(source),
    audioSource: source,
    delayMs: (plan.startFrame / fps * 1000).round(),
    volume: plan.audio.volume,
    volumeEnvelope: plan.audio.automation.resolve(fps: fps, windowFrames: plan.windowFrames),
    trimStartSeconds: trim.start,
    trimEndSeconds: trim.end,
    fadeInSeconds: fadeIn > 0 ? fadeIn : null,
    fadeOutSeconds: fadeOut > 0 ? fadeOut : null,
    fadeOutStartSeconds: fadeOut > 0 ? math.max(delaySeconds, fadeOutStart) : 0,
    tempo: plan.speed,
    timeMap: plan.sourceTimeMap == null
        ? null
        : AudioTimeMap(fps: fps, sourceSeconds: plan.sourceTimeMap!),
  );
}

/// The authored source string the audio materializer resolves: a file path for
/// a device clip, an asset key for a bundled clip, and the diagnostic
/// `memory:<cacheKey>` label for verbatim bytes (never materialized by string).
String _sourceString(AudioSource source) => switch (source) {
  AssetAudioSource(:final name) => name,
  FileAudioSource(:final path) => path,
  NetworkAudioSource(:final url) => url.toString(),
  MemoryAudioSource() => 'memory:${source.cacheKey}',
};
