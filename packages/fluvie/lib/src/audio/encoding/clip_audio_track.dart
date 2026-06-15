import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Maps a clip's [ClipAudio] policy to one [AudioTrackNode] for the mix,
/// or `null` when the clip is muted.
///
/// A `ClipAudio.included` clip joins the `amix` as one more track over its
/// materialized [name]: its [ClipAudio.volume] becomes the track gain and its
/// [ClipAudio.fadeIn] (resolved against [fps]) becomes the fade-in seconds. A
/// `ClipAudio.muted` clip contributes no node — its sound is dropped at source,
/// never mixed and re-silenced.
AudioTrackNode? clipAudioTrackNode(ClipAudio audio, {required String name, required int fps}) {
  if (audio.muted) return null;
  final fadeInFrames = audio.fadeIn.resolveFrames(
    TimeScopeData(fps: fps, startFrame: 0, durationFrames: 0),
  );
  return AudioTrackNode(
    name: name,
    volume: audio.volume,
    fadeInSeconds: fadeInFrames > 0 ? fadeInFrames / fps : null,
  );
}
