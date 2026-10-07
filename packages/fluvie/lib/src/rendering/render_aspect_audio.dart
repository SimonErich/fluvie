part of 'render_aspect.dart';

/// Resolves the encoder audio mix for [composition]: an explicit
/// [explicitStager]/[explicitSources] pair wins; otherwise a [Video]
/// composition's declared `Audio` tracks are collected and turned into a
/// [stageAudioMix] closure against [fps]/[totalFrames] (so `Audio.sfx(at:)`
/// resolves its `adelay`). A non-`Video` or track-less composition yields
/// `(null, const [])`, so the encoder's `-an` path is unchanged.
({AudioMixStager? stageAudio, Iterable<AudioSource> audioSources}) _audioFor(
  Widget composition, {
  required AudioMixStager? explicitStager,
  required Iterable<AudioSource>? explicitSources,
  required int fps,
  required int totalFrames,
  GenerativeResolver? generative,
  MediaResolver? resolver,
  List<ClipAudioPlan>? mountedClipPlans,
}) {
  if (explicitStager != null) {
    return (stageAudio: explicitStager, audioSources: explicitSources ?? const []);
  }
  final video = compositionVideo(composition);
  if (video == null) return (stageAudio: null, audioSources: const []);
  final tracks = collectAudioTracks(video, generative: generative);
  // Only clips that actually carry an audio track join the mix (each was probed
  // above); a silent clip would otherwise fail the encoder's `[N:a]` map.
  final clipPlans = resolver == null
      ? const <ClipAudioPlan>[]
      : (mountedClipPlans ??
                collectClipAudioPlans(
                  video.scenes,
                  fps,
                  sceneStartFrames: video.sceneStartFrames,
                  generative: generative,
                  overlays: video.overlays,
                  totalFrames: video.totalFrames,
                ))
            .where((plan) => resolver.clipMetadataFor(plan.source).hasAudio)
            .toList();
  if (tracks.isEmpty && clipPlans.isEmpty) {
    return (stageAudio: null, audioSources: const []);
  }
  return (
    stageAudio: ({required resolver, required sandbox}) async {
      // A clip's embedded audio (including a generated video's) is staged from
      // the clip's video file and joins the same amix as the declared tracks.
      final clipNodes = await stageClipAudio(
        plans: clipPlans,
        resolver: resolver,
        sandbox: sandbox,
        fps: fps,
        totalFrames: totalFrames,
      );
      final plan = await stageAudioMix(
        tracks: tracks,
        resolver: resolver,
        sandbox: sandbox,
        fps: fps,
        totalFrames: totalFrames,
        extraNodes: clipNodes,
      );
      return (nodes: plan.tracks, amix: plan.amix);
    },
    audioSources: {
      ...collectAudioSources(video, generative: generative),
      for (final plan in clipPlans) clipAudioSourceFor(plan.source),
    },
  );
}
