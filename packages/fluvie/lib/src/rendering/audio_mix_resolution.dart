import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

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
ResolvedAudioMix resolveAudioMix({
  required Video video,
  required int fps,
  int totalFrames = 0,
}) {
  final tracks = collectAudioTracks(video);
  if (tracks.isEmpty) return const ResolvedAudioMix(tracks: []);
  final scope = TimeScopeData(fps: fps, startFrame: 0, durationFrames: totalFrames);
  return ResolvedAudioMix(
    tracks: [for (final track in tracks) resolveAudioTrack(track, fps: fps, scope: scope)],
  );
}
