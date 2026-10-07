part of 'on_device_video_renderer.dart';

/// Resolves a composition's audio into materialized [MobileAudioTrack]s —
/// the shared opt-in gate ([gateOptInAudio]) with the on-device label, then
/// each surviving track's source materialized through [materializer].
///
/// Native mixers apply scalar rates and integrated speed maps, along with
/// the same resolved volume envelope used by desktop and browser exports.
///
/// A track whose typed source is an [AudioSource.memory] writes its own bytes
/// into [sandbox] under `audio_<cacheKey>` (the content hash, so identical
/// bytes share one file) — the string-keyed [materializer] is never asked for
/// a source that has no string to resolve, mirroring the web sandbox staging.
Future<({List<MobileAudioTrack> tracks, double masterVolume})> _resolveAudioTracks(
  Widget composition, {
  required bool encode,
  required bool warn,
  required int fps,
  required int frameCount,
  required MobileAudioMaterializer materializer,
  required Directory sandbox,
  required void Function(String message) warnSink,
  required MediaResolver resolver,
  required int authoredFrames,
  required List<ClipAudioPlan> mountedClipPlans,
}) async {
  final mix = gateOptInAudio(
    composition: composition,
    encode: encode,
    warn: warn,
    fps: fps,
    frameCount: authoredFrames,
    warnSink: warnSink,
    platformLabel: 'on-device',
    // Capture has already run, so the clip pre-pass has probed every clip and
    // a trimmed clip's audio can open where its picture does.
    clipMetadata: resolver.clipMetadataFor,
    clipTimeline: (source) => clipTimelineFor(resolver, source),
    mountedClipPlans: mountedClipPlans,
  );
  if (mix == null) return (tracks: const <MobileAudioTrack>[], masterVolume: 1.0);
  return (
    tracks: [
      for (final track in mix.tracks)
        // A source placed at/after its owner or render end has no audible
        // samples. Do not load it or send an empty native composition track.
        if (track.delayMs / 1000 < frameCount / fps &&
            (track.endSeconds == null || track.delayMs / 1000 < track.endSeconds!))
          MobileAudioTrack.fromResolved(
            track,
            path: await _materializeTrack(track, materializer, sandbox),
          ),
    ],
    masterVolume: mix.masterVolume,
  );
}

/// One track's local file: memory bytes written under their content hash,
/// every path-shaped source through the injected string materializer.
Future<String> _materializeTrack(
  ResolvedAudioTrack track,
  MobileAudioMaterializer materializer,
  Directory sandbox,
) async {
  final source = track.audioSource;
  if (source is! MemoryAudioSource) return materializer.materialize(track.source);
  final file = File('${sandbox.path}/audio_${source.cacheKey}');
  if (!file.existsSync()) await file.writeAsBytes(source.bytes);
  return file.path;
}

/// Fluvie's capture entry, wrapped at library scope so
/// [OnDeviceVideoRenderer.render] can call it without the method name shadowing
/// the free function. Capture stages a silent FFmpeg lane; the renderer mixes
/// and muxes audio natively after capture (see [_resolveAudioTracks]).
Future<RenderAspectResult> _captureToSandbox({
  required Widget composition,
  required Aspect aspect,
  required int frameCount,
  required Directory outDir,
  required RenderService service,
  required ShellMount pumpWidget,
  required ShellFramePump pumpFrame,
  required int longEdge,
  required int fps,
  required String compositionKey,
  required MediaResolver resolver,
  required VideoRenderRequest request,
  required void Function(PreparedComposition prepared, VideoRenderRequest request) onPrepared,
  RenderCancellation? cancellation,
  BeatDetectionService? beatDetector,
  FrequencyAnalyzer? analyzer,
}) => render(
  composition: composition,
  aspect: aspect,
  frameCount: frameCount,
  outDir: outDir,
  service: service,
  pumpWidget: pumpWidget,
  pumpFrame: pumpFrame,
  longEdge: longEdge,
  fps: fps,
  compositionKey: compositionKey,
  stageAudio: _silentAudio,
  resolver: resolver,
  request: request,
  cancellation: cancellation,
  beatDetector: beatDetector,
  analyzer: analyzer,
  onPrepared: onPrepared,
);

Future<AudioMixLanes> _silentAudio({
  required MediaResolver resolver,
  required Directory sandbox,
}) async => (nodes: const <Never>[], amix: null);
