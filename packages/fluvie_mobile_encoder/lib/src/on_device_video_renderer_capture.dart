part of 'on_device_video_renderer.dart';

/// Resolves a composition's audio into materialized [MobileAudioTrack]s.
///
/// A non-`Video` or audio-less composition yields no tracks. With audio present
/// but [encode] `false`, it warns once (when [warn]) and yields no tracks;
/// otherwise it materializes every track's source through [materializer].
Future<({List<MobileAudioTrack> tracks, double masterVolume})> _resolveAudioTracks(
  Widget composition, {
  required bool encode,
  required bool warn,
  required int fps,
  required int frameCount,
  required MobileAudioMaterializer materializer,
}) async {
  if (composition is! Video) return (tracks: const <MobileAudioTrack>[], masterVolume: 1.0);
  final mix = resolveAudioMix(video: composition, fps: fps, totalFrames: frameCount);
  if (mix.isEmpty) return (tracks: const <MobileAudioTrack>[], masterVolume: 1.0);
  if (!encode) {
    if (warn) {
      OnDeviceVideoRenderer.onWarning(
        'This Video declares ${mix.tracks.length} audio track(s), but on-device '
        'audio is off, so the MP4 will be silent. Pass audio: true to encode it, '
        'or warnOnDroppedAudio: false to silence this warning.',
      );
    }
    return (tracks: const <MobileAudioTrack>[], masterVolume: 1.0);
  }
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
