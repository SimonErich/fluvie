import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';

/// Gathers every declared [Audio] track from [video] before the frame loop —
/// a pure structural read over the constructor data, with no mounting and no
/// async.
///
/// The order is video-level tracks first (in declaration order), then each
/// scene's tracks in scene order, so the mix is deterministic and the same
/// composition always produces the same track sequence. The render path resolves
/// each track's [Audio.audioSource], pre-resolves them, and appends one
/// `AudioTrackNode` per track to the encode plan.
List<Audio> collectAudioTracks(Video video) => [
  ...video.audio,
  for (final scene in video.scenes) ...scene.audio,
];

/// The deduplicated set of [AudioSource]s every track in [video] needs: the
/// materialize set handed to `MediaResolver.preResolveAudio` before frame 0.
///
/// Two tracks that name the same origin (so resolve to an equal [AudioSource])
/// materialize once; an asset and a file of the same string are distinct
/// origins and stay distinct, exactly as the cache key distinguishes them.
Set<AudioSource> collectAudioSources(Video video) => {
  for (final track in collectAudioTracks(video)) track.audioSource,
};
