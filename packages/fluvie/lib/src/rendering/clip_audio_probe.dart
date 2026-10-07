import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';

/// Probes every **trimmed** clip in [composition], so a mix resolved before the
/// frame pre-pass can still place its embedded audio.
///
/// `resolveAudioMix` is pure and cannot probe, and a renderer that resolves its
/// mix up front (the in-browser one hands the tracks to `renderToSandbox`)
/// therefore has nothing to resolve a trim against. This walks the same plans
/// the mix will, probes only the clips whose audio actually needs a source
/// (probing is idempotent and cached, so the pre-pass reuses the result), and
/// returns the lookup to hand to `resolveAudioMix` or `gateOptInAudio`.
///
/// A non-[Video] composition, or one whose clips are all untrimmed, probes
/// nothing and returns an empty map.
Future<Map<MediaSource, ClipMetadata>> probeTrimmedClips(
  Widget composition, {
  required MediaResolver resolver,
  required int fps,
  GenerativeResolver? generative,
}) async {
  final video = compositionVideo(composition);
  if (video == null) return const {};
  final probed = <MediaSource, ClipMetadata>{};
  for (final plan in collectClipAudioPlans(
    video.scenes,
    fps,
    sceneStartFrames: video.sceneStartFrames,
    generative: generative,
    overlays: video.overlays,
    totalFrames: video.totalFrames,
  )) {
    if (plan.trim == null || probed.containsKey(plan.source)) continue;
    probed[plan.source] = await resolver.probeClip(plan.source);
  }
  return probed;
}
