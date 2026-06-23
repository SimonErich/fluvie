import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/runtime/media_collector.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/media/media_source.dart';
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
  final scope = TimeScopeData(fps: fps, startFrame: 0, durationFrames: totalFrames);
  final tracks = <ResolvedAudioTrack>[
    for (final track in collectAudioTracks(video)) resolveAudioTrack(track, fps: fps, scope: scope),
    // A clip's embedded audio plays where the clip plays: delayed to its scene
    // start and trimmed to the scene window (so sequential clips don't bleed).
    for (final plan in collectClipAudioPlans(video.scenes, fps)) _clipAudioTrack(plan, fps, scope),
  ];
  return ResolvedAudioMix(tracks: tracks);
}

/// Resolves one clip-audio [plan] to an encoder-neutral track: its source file
/// (the video — the encoder extracts the audio track), delayed to the clip's
/// start and trimmed to its window, at the clip's authored volume and fade-in.
ResolvedAudioTrack _clipAudioTrack(ClipAudioPlan plan, int fps, TimeScopeData scope) {
  final windowSeconds = plan.windowFrames / fps;
  final fadeIn = plan.audio.fadeIn.resolveFrames(scope) / fps;
  return ResolvedAudioTrack(
    source: _sourceString(plan.source),
    delayMs: (plan.startFrame / fps * 1000).round(),
    volume: plan.audio.volume,
    trimStartSeconds: 0,
    trimEndSeconds: windowSeconds,
    fadeInSeconds: fadeIn > 0 ? fadeIn : null,
  );
}

/// The authored source string the audio materializer resolves: a file path for
/// a device clip, an asset key for a bundled clip.
String _sourceString(MediaSource source) => switch (source) {
  AssetSource(:final name) => name,
  FileSource(:final path) => path,
  NetworkSource(:final url) => url.toString(),
  MemorySource() => '',
};
