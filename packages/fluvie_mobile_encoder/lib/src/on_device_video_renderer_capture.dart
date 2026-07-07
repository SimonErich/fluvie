part of 'on_device_video_renderer.dart';

/// Resolves a composition's audio into materialized [MobileAudioTrack]s —
/// the shared opt-in gate ([gateOptInAudio]) with the on-device label, then
/// each surviving track's source materialized through [materializer].
Future<({List<MobileAudioTrack> tracks, double masterVolume})> _resolveAudioTracks(
  Widget composition, {
  required bool encode,
  required bool warn,
  required int fps,
  required int frameCount,
  required MobileAudioMaterializer materializer,
  required void Function(String message) warnSink,
}) async {
  final mix = gateOptInAudio(
    composition: composition,
    encode: encode,
    warn: warn,
    fps: fps,
    frameCount: frameCount,
    warnSink: warnSink,
    platformLabel: 'on-device',
  );
  if (mix == null) return (tracks: const <MobileAudioTrack>[], masterVolume: 1.0);
  return (
    tracks: [
      for (final track in mix.tracks)
        MobileAudioTrack.fromResolved(track, path: await materializer.materialize(track.source)),
    ],
    masterVolume: mix.masterVolume,
  );
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
);

Future<AudioMixLanes> _silentAudio({
  required MediaResolver resolver,
  required Directory sandbox,
}) async => (nodes: const <Never>[], amix: null);
