import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/audio/generative_audio.dart';
import 'package:fluvie/src/composition/runtime/scene_tree_walk.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart';

/// Gathers every declared [Audio] track from [video] before the frame loop —
/// a pure structural read over the constructor data, with no mounting and no
/// async.
///
/// The order is video-level tracks first (in declaration order), then each
/// scene's tracks in scene order, then any generated audio tracks, so the mix is
/// deterministic and the same composition always produces the same track
/// sequence. The render path resolves each track's [Audio.audioSource],
/// pre-resolves them, and appends one `AudioTrackNode` per track to the encode
/// plan.
///
/// When a [generative] resolver is given (after its `generateAll` ran), every
/// `GenerativeAudio` in the scene tree folds in as a file-backed [Audio.music]
/// track over its produced file, so generated music/speech/sound-effects mix
/// through the same pipeline as hand-written tracks.
List<Audio> collectAudioTracks(Video video, {GenerativeResolver? generative}) => [
  ...video.audio,
  for (final scene in video.scenes) ...scene.audio,
  if (generative != null) ...collectGenerativeAudioTracks(video.scenes, generative),
];

/// The deduplicated set of [AudioSource]s every track in [video] needs: the
/// materialize set handed to `MediaResolver.preResolveAudio` before frame 0.
///
/// Two tracks that name the same origin (so resolve to an equal [AudioSource])
/// materialize once; an asset and a file of the same string are distinct
/// origins and stay distinct, exactly as the cache key distinguishes them. A
/// [generative] resolver folds the produced generated-audio sources in too.
Set<AudioSource> collectAudioSources(Video video, {GenerativeResolver? generative}) => {
  for (final track in collectAudioTracks(video, generative: generative)) track.audioSource,
};

/// Maps every [GenerativeAudio] in [scenes] to a file-backed [Audio.music] track
/// over the file [generative] produced for it, carrying the widget's volume,
/// fades, and loop. Walks the same tree as the media collectors.
List<Audio> collectGenerativeAudioTracks(List<Scene> scenes, GenerativeResolver generative) {
  final tracks = <Audio>[];
  walkSceneTree(scenes, (widget) {
    if (widget is! GenerativeAudio) return;
    tracks.add(
      Audio.music(
        _audioPath(generative.audioFor(widget.source)),
        volume: widget.volume,
        fadeIn: widget.fadeIn,
        fadeOut: widget.fadeOut,
        loop: widget.loop,
      ),
    );
  });
  return tracks;
}

/// The source string [Audio.music] takes for a produced [AudioSource], which
/// `audioSourceFromString` round-trips back to the same kind.
String _audioPath(AudioSource source) => switch (source) {
  FileAudioSource(:final path) => path,
  AssetAudioSource(:final name) => name,
  NetworkAudioSource(:final url) => url.toString(),
};
