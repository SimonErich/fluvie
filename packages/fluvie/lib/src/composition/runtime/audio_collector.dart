import 'package:flutter/widgets.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/audio/generative_audio.dart';
import 'package:fluvie/src/composition/runtime/scene_tree_walk.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

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
/// `GenerativeAudio` in the scene tree folds in as an [Audio.musicSource]
/// track over its produced source, so generated music/speech/sound-effects mix
/// through the same pipeline as hand-written tracks.
List<Audio> collectAudioTracks(Video video, {GenerativeResolver? generative}) => [
  ...video.audio,
  for (var i = 0; i < video.scenes.length; i++)
    for (final track in video.scenes[i].audio)
      track.inWindow(
        video.sceneStartFrames[i],
        video.scenes[i].duration.resolveFrames(
          TimeScopeData(fps: video.fps, startFrame: 0, durationFrames: video.totalFrames),
        ),
      ),
  if (generative != null)
    ...collectGenerativeAudioTracks(video.scenes, generative, overlays: video.overlays),
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

/// Maps every [GenerativeAudio] in [scenes] to an [Audio.musicSource] track
/// over the source [generative] produced for it, carrying the widget's volume,
/// fades, and loop. Walks the same tree as the media collectors. The produced
/// [AudioSource] flows through typed, so a resolver returning bytes in memory
/// mixes exactly like one returning a file.
List<Audio> collectGenerativeAudioTracks(
  List<Scene> scenes,
  GenerativeResolver generative, {
  List<Widget> overlays = const [],
}) {
  final tracks = <Audio>[];
  walkSceneTree(scenes, overlays: overlays, (widget) {
    if (widget is! GenerativeAudio) return;
    tracks.add(
      Audio.musicSource(
        generative.audioFor(widget.source),
        volume: widget.volume,
        fadeIn: widget.fadeIn,
        fadeOut: widget.fadeOut,
        loop: widget.loop,
      ),
    );
  });
  return tracks;
}
