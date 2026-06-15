import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';

/// The reactive audio tracks a composition declares, gathered for the
/// pre-resolve pass.
///
/// [byAnchor] maps each `Audio.track` anchor to its source (for `track:`-scoped
/// reactivity); [defaultSource] is the first declared track (the master mix a
/// reactive effect with no `track:` reads); [allSources] is the deduplicated set
/// the shell hands to `MediaResolver.preResolveReactive` so each track is
/// analysed once before frame 0.
class ReactiveTracks {
  /// Creates the gathered reactive tracks.
  const ReactiveTracks({
    required this.byAnchor,
    required this.defaultSource,
    required this.allSources,
  });

  /// Per-track sources keyed by the `Audio.track` anchor.
  final Map<Anchor, AudioSource> byAnchor;

  /// The master source (the first declared track), or `null` when silent.
  final AudioSource? defaultSource;

  /// The deduplicated set of sources to analyse before frame 0.
  final Set<AudioSource> allSources;
}

/// Gathers every reactive audio track [video] declares — a pure structural read
/// over the constructor data, no mounting and no async.
///
/// The first declared track becomes the default (master) source the reactive
/// scope serves to untracked effects; every track that carries an `Audio.track`
/// anchor is also mapped by that anchor so a `track:`-scoped effect reads its
/// own table. The set is deduplicated so two tracks naming one origin analyse
/// once.
ReactiveTracks collectReactiveTracks(Video video) {
  final tracks = collectAudioTracks(video);
  final byAnchor = <Anchor, AudioSource>{};
  for (final track in tracks) {
    final anchor = track.track;
    if (anchor != null) byAnchor[anchor] = track.audioSource;
  }
  return ReactiveTracks(
    byAnchor: byAnchor,
    defaultSource: tracks.isEmpty ? null : tracks.first.audioSource,
    allSources: {for (final track in tracks) track.audioSource},
  );
}
