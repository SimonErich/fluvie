// Per-lesson Alchemist goldens (WI-34): each lesson rendered at its own
// poster frame (decision D25 — the poster lives on the Video, not the
// Lesson). The ci variant runs everywhere on the Ahem font; the platform
// variant is Linux-only per the shared flutter_test_config.
//
// Media lessons (05/06) mount an ImageResolverScope over an offline fake
// resolver so their Image/Clip paint from a real decoded fixture, never the
// async preview fallback (decision D16) — the poster golden then shows the
// media present, exactly as a render would.
//
// The snapshot lesson (09) mounts the same scope over the offline fake snapshot
// service, so its Mermaid/Html paint from a fixture raster rather than the
// preview placeholder — the poster golden shows the diagram and the framed page
// present, exactly as an offline render would (decision D-Lesson).
@Tags(['golden'])
library;

import 'dart:typed_data';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
// The resolver scope, the reactive scope builder, the collect passes, and the
// real MediaRepository are render infrastructure, off the authoring barrel; the
// golden reaches into src/ like the render harness.
import 'package:fluvie/src/animation/runtime/reactive_scope_builder.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/runtime/caption_collector.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/capture/beat_grid_scope.dart';
import 'package:fluvie_example/lessons/lessons.dart';
import 'package:fluvie_example/lessons/poster_frame.dart';

import '../render/fake_lesson_media.dart';
import '../render/harness_audio.dart';
import '../render/harness_snapshot.dart';

Future<void> main() async {
  for (final lesson in lessons) {
    final probe = lesson.video();
    final frame = posterFrameOf(probe);
    final resolver = await _resolverFor(probe);

    await goldenTest(
      'lesson ${lesson.id} at its poster frame ($frame)',
      fileName: 'lesson_${lesson.id}',
      builder: () => GoldenTestGroup(
        children: [
          GoldenTestScenario(
            name: 'poster frame $frame',
            child: SizedBox(
              width: probe.width.toDouble(),
              height: probe.height.toDouble(),
              child: RenderControllerScope(
                controller: RenderController(initialFrame: frame),
                child: _withMedia(
                  resolver,
                  probe,
                  Directionality(textDirection: TextDirection.ltr, child: lesson.video()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds the resolver for [probe]'s poster golden, or `null` when it declares
/// nothing to pre-resolve.
///
/// A media lesson (05/06) decodes its `Image`/`Clip` fixtures through the
/// offline [FakeLessonMedia]. The snapshot lesson (09) rasterizes its
/// `Mermaid`/`Html` through the offline fake snapshot service. The audio lesson
/// (10) analyses its committed WAV with the real spectral DSP and parses its
/// SRT, all offline with no ffmpeg (decision D-Lesson). The paths are disjoint
/// across the current lessons, so each lesson picks exactly one; a lesson with
/// none resolves to `null`.
Future<MediaResolver?> _resolverFor(Video probe) async {
  final snapshotSources = collectSnapshotSources(probe.scenes);
  if (snapshotSources.isNotEmpty) {
    return prepareSnapshotMedia(snapshotSources);
  }
  if (collectAudioSources(probe).isNotEmpty || collectCaptionSource(probe) != null) {
    return _reactiveResolver(probe);
  }
  final mediaSources = collectMediaSources(probe.scenes);
  if (mediaSources.isEmpty) return null;
  final resolver = await FakeLessonMedia.create(mediaSources);
  await resolver.preResolveAll(mediaSources);
  return resolver;
}

/// Builds a real [MediaRepository] for the audio lesson and runs its offline
/// pre-passes: the real spectral beat/band DSP over the committed WAV (via the
/// in-house WAV decoder, no ffmpeg) and the SRT parse, so the poster golden
/// shows the bars and the badge at their true band energy and the active caption
/// cue (decision D-Lesson).
Future<MediaResolver> _reactiveResolver(Video probe) async {
  final repository = MediaRepository(
    loader: MediaBytesLoader(
      bundle: rootBundle,
      httpClient: const _UnusedHttpClient(),
      allowlist: NetworkAllowlist.allowAny(),
    ),
  );
  final captions = collectCaptionSource(probe);
  if (captions != null) await repository.preResolveCaptions(captions);
  await preResolveReactiveFor(repository, probe, fps: probe.fps, totalFrames: probe.totalFrames);
  return repository;
}

/// Wraps [child] so a lesson paints its pre-resolved sources: an
/// [ImageResolverScope] for media / snapshots / captions, a `ReactiveScope`
/// (via [reactiveScopeFor]) over [probe]'s analysed band tables so the bars and
/// the reactive badge show real energy, and a [BeatGridScope] over its analysed
/// beat grids so a `Trigger.beat` lesson (12) resolves its beat-synced pop
/// (decision D-BeatWiring) — exactly the scopes the capture shell mounts. A
/// lesson with no [resolver] is left untouched.
Widget _withMedia(MediaResolver? resolver, Video probe, Widget child) {
  if (resolver == null) return child;
  final tracks = collectReactiveTracks(probe);
  final withBeat = _withBeatGrids(tracks, resolver, child);
  final scoped = reactiveScopeFor(tracks, resolver, withBeat);
  return ImageResolverScope(resolver: resolver, child: scoped);
}

/// Wraps [child] in a [BeatGridScope] carrying the analysed beat grids for
/// [tracks], or returns it unchanged when no track has a grid — the golden
/// counterpart of the capture shell's beat-grid mount.
Widget _withBeatGrids(ReactiveTracks tracks, MediaResolver resolver, Widget child) {
  final defaultSource = tracks.defaultSource;
  final defaultGrid = defaultSource == null ? null : _gridOrNull(resolver, defaultSource);
  final trackGrids = <Anchor, BeatGrid>{};
  for (final entry in tracks.byAnchor.entries) {
    final grid = _gridOrNull(resolver, entry.value);
    if (grid != null) trackGrids[entry.key] = grid;
  }
  if (defaultGrid == null && trackGrids.isEmpty) return child;
  return BeatGridScope(defaultBeatGrid: defaultGrid, trackBeatGrids: trackGrids, child: child);
}

/// The analysed [BeatGrid] for [source], or `null` when the resolver has none (a
/// reactive track analysed only for its band table carries no grid).
BeatGrid? _gridOrNull(MediaResolver resolver, AudioSource source) {
  try {
    return resolver.beatGridFor(source);
  } on Object {
    return null;
  }
}

/// The reactive resolver reads only bundled assets, so the network client is
/// never reached; an unexpected fetch would be a determinism bug, not a download.
class _UnusedHttpClient implements MediaHttpClient {
  const _UnusedHttpClient();

  @override
  Future<Uint8List> get(Uri url) async =>
      throw StateError('The lesson 10 golden resolves only bundled fixtures ($url).');
}
