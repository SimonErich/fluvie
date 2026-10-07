import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/audio_analysis_window.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// The reactive audio tracks a composition declares, gathered for the
/// pre-resolve pass.
///
/// [byAnchor] maps each `Audio.track` anchor to its source (for `track:`-scoped
/// reactivity); [defaultSource] is the first audible declared track (the source a
/// reactive effect with no `track:` reads); [allSources] is the deduplicated set
/// the shell hands to `MediaResolver.preResolveReactive` so each track is
/// analysed once before frame 0.
final class ReactiveTracks {
  /// Creates the gathered reactive tracks.
  const ReactiveTracks({
    required this.byAnchor,
    required this.defaultSource,
    required this.allSources,
    this.windows = const [],
    this.windowsByAnchor = const {},
  });

  /// Audible intervals in declaration order; the first is the default track.
  final List<AudioAnalysisWindow> windows;

  /// Audible intervals named by track anchors.
  final Map<Anchor, AudioAnalysisWindow> windowsByAnchor;

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
  final windows = <AudioAnalysisWindow>[];
  final windowsByAnchor = <Anchor, AudioAnalysisWindow>{};
  for (final track in tracks) {
    final anchor = track.track;
    if (anchor != null) byAnchor[anchor] = track.audioSource;
    final resolved = resolveAudioTrack(
      track,
      fps: video.fps,
      scope: TimeScopeData(fps: video.fps, startFrame: 0, durationFrames: video.totalFrames),
    );
    final start = (resolved.delayMs * video.fps / 1000).round();
    final end = ((resolved.endSeconds ?? video.totalFrames / video.fps) * video.fps).round().clamp(
      0,
      video.totalFrames,
    );
    if (end <= start) continue;
    final sourceStart = resolved.trimStartSeconds ?? 0;
    final requested =
        ((resolved.trimEndSeconds == null
                    ? (end - start) / video.fps
                    : resolved.trimEndSeconds! - sourceStart) *
                video.fps)
            .ceil();
    if (requested < 1) continue;
    final window = AudioAnalysisWindow(
      source: track.audioSource,
      sourceStart: Duration(microseconds: (sourceStart * 1000000).round()),
      sourceFrames: requested.clamp(1, end - start),
      startFrame: start,
      endFrame: end,
      fps: video.fps,
      loop: resolved.loop,
    );
    windows.add(window);
    if (anchor != null) windowsByAnchor[anchor] = window;
  }
  return ReactiveTracks(
    byAnchor: byAnchor,
    windows: windows,
    windowsByAnchor: windowsByAnchor,
    defaultSource: tracks.isEmpty ? null : tracks.first.audioSource,
    allSources: {for (final track in tracks) track.audioSource},
  );
}
