import 'dart:io';
import 'dart:math' as math;

import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart' show ClipAudioPlan;
import 'package:fluvie/src/core/audio/audio_time_map.dart';
import 'package:fluvie/src/core/contracts/clip_timeline_resolver.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/rendering/clip_audio_source.dart';
import 'package:fluvie/src/rendering/clip_audio_trim.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

export 'package:fluvie/src/rendering/clip_audio_source.dart' show clipAudioSourceFor;

/// Stages every clip's embedded audio into the render [sandbox] and returns one
/// [AudioTrackNode] per clip, ready to join the encoder `amix`.
///
/// Each clip's video file (already materialized by `MediaResolver.preResolveAudio`
/// through [clipAudioSourceFor]) is copied into [sandbox] under a bare name, then
/// turned into a node delayed to the clip's own window start (`startFrame` —
/// where the element appears, not where its scene begins) and
/// trimmed to the source-time window [resolveClipAudioTrimSeconds] resolves (so
/// a trimmed clip's audio opens where its picture does), at the clip's volume
/// and fade-in, retimed by the clip's speed. A **reversed** clip is skipped
/// entirely: no filter here plays a stream backwards, and forward audio under
/// backwards picture is worse than silence. This mirrors the on-device
/// `resolveAudioMix` clip-audio
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
  for (var i = 0; i < plans.length; i++) {
    final plan = plans[i];
    // Nothing in this graph reverses a stream, so a backwards clip contributes
    // no audio rather than forward audio under backwards picture.
    if (plan.speed < 0) continue;
    final source = clipAudioSourceFor(plan.source);
    final materialized = resolver.materializedAudioPathFor(source);
    final name = 'clip_audio_${i}_${source.cacheKey}';
    await File(materialized).copy('${sandbox.path}/$name');
    final scope = TimeScopeData(fps: fps, startFrame: 0, durationFrames: plan.windowFrames);
    final fadeInFrames = plan.audio.fadeIn.resolveFrames(scope);
    final fadeOutFrames = plan.audio.fadeOut.resolveFrames(scope);
    final delaySeconds = plan.startFrame / fps;
    // The ramp ENDS where the clip stops being shown, so it starts that much
    // earlier on the mix timeline (composition time, after atempo has already
    // retimed the stream back).
    final fadeOutStart = delaySeconds + plan.windowFrames / fps - fadeOutFrames / fps;
    // probeClip is idempotent and cached, so a clip already probed by the frame
    // pre-pass costs a map lookup here.
    final trim = resolveClipAudioTrimSeconds(
      trim: plan.trim,
      timeline: clipTimelineFor(resolver, plan.source),
      meta: plan.trim == null ? null : await resolver.probeClip(plan.source),
      windowFrames: plan.windowFrames,
      fps: fps,
      sourceLabel: '${plan.source}',
      speed: plan.sourceTimeMap == null
          ? plan.speed
          : plan.sourceTimeMap!.last / (plan.windowFrames / fps),
    );
    nodes.add(
      AudioTrackNode(
        name: name,
        delayMs: (plan.startFrame / fps * 1000).round(),
        volume: plan.audio.volume,
        volumeEnvelope: plan.audio.automation.resolve(fps: fps, windowFrames: plan.windowFrames),
        trimStartSeconds: trim.start,
        trimEndSeconds: trim.end,
        fadeInSeconds: fadeInFrames > 0 ? fadeInFrames / fps : null,
        fadeOutSeconds: fadeOutFrames > 0 ? fadeOutFrames / fps : null,
        fadeOutStartSeconds: fadeOutFrames > 0 ? math.max(delaySeconds, fadeOutStart) : 0,
        tempo: plan.speed,
        timeMap: plan.sourceTimeMap == null
            ? null
            : AudioTimeMap(fps: fps, sourceSeconds: plan.sourceTimeMap!),
      ),
    );
  }
  return nodes;
}
