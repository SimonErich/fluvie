import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
// MotionTarget is internal; the registry test reaches into the tree to confirm
// lesson 06 binds the pixel-fx overlay the doc demonstrates.
import 'package:fluvie/src/animation/motion_target.dart';
// The audio/caption collect passes are render infrastructure, off the authoring
// barrel; the registry test reaches into src/ like the render harness to assert
// lesson 10 declares the reactive audio + caption sources the pre-pass resolves.
import 'package:fluvie/src/composition/runtime/caption_collector.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
// Lesson 12 uses Trigger.beat; the warning-free pump mounts the analysed beat
// grids through a BeatGridScope, exactly as the capture shell does, so the
// resolver finds a grid and the timeline resolves warning-free (decision
// D-BeatWiring). The grid comes from the real spectral DSP over the committed
// WAV — all under src/, off the authoring barrel like the render harness.
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/rendering/capture/beat_grid_scope.dart';
import 'package:fluvie_example/lessons/lessons.dart';

import '../render/harness_audio.dart';

void main() {
  group('lessons registry (WI-33)', () {
    test('ids are unique and ordered 01..12', () {
      final ids = [for (final lesson in lessons) lesson.id];

      expect(ids, [
        '01_hello_video',
        '02_text_and_motion',
        '03_timing_and_triggers',
        '04_scenes_and_transitions',
        '05_images_and_clips',
        '06_collage',
        '07_charts',
        '08_code_doc_intro',
        '09_diagrams_and_webviews',
        '10_audio_and_captions',
        '11_templates_and_aspects',
        '12_the_kitchen_sink',
      ]);
      expect(ids.toSet().length, ids.length);
    });

    test('lessonForId resolves every registered id and rejects unknown ids', () {
      for (final lesson in lessons) {
        expect(lessonForId(lesson.id), same(lesson));
      }
      expect(lessonForId('99_unknown'), isNull);
    });

    test('every lesson carries a title, an intro, and a poster frame (D25)', () {
      for (final lesson in lessons) {
        expect(lesson.title, isNotEmpty, reason: lesson.id);
        expect(lesson.intro, isNotEmpty, reason: lesson.id);
        expect(lesson.video().poster, isNotNull, reason: lesson.id);
      }
    });

    test('the media lessons declare sources the collect pass gathers (WI-23/D3)', () {
      for (final id in const ['05_images_and_clips', '06_collage']) {
        final video = lessonForId(id)!.video();
        expect(
          collectMediaSources(video.scenes),
          isNotEmpty,
          reason: '$id should declare at least one Image/Clip source',
        );
      }
    });

    test('lesson 09 declares snapshot sources the collect pass gathers (WI-20)', () {
      final video = lessonForId('09_diagrams_and_webviews')!.video();
      expect(
        collectSnapshotSources(video.scenes),
        isNotEmpty,
        reason: 'lesson 09 should declare at least one Mermaid/WebView/Html source',
      );
    });

    test('lesson 09 carries a poster frame so its golden has a frame to pin', () {
      final video = lessonForId('09_diagrams_and_webviews')!.video();
      expect(video.poster, isNotNull);
    });

    test('lesson 10 declares an audio track and a caption source the harness '
        'pre-resolves (WI-24)', () {
      final video = lessonForId('10_audio_and_captions')!.video();
      // The reactive pre-pass analyses the music bed; the caption pre-pass reads
      // and parses the SRT — both before frame 0.
      expect(
        collectReactiveTracks(video).allSources,
        isNotEmpty,
        reason: 'lesson 10 should declare an Audio.music track to analyse',
      );
      expect(
        collectCaptionSource(video),
        isNotNull,
        reason: 'lesson 10 should declare a Captions.fromSrt track',
      );
    });

    test('lesson 10 carries a poster frame so its golden has a frame to pin', () {
      final video = lessonForId('10_audio_and_captions')!.video();
      expect(video.poster, isNotNull);
    });

    test('lesson 12 declares the beat-tagged audio + caption track the shell '
        'pre-resolves (WI-29)', () {
      // The kitchen sink declares an Audio.music track named by an Anchor (so
      // Trigger.beat references its analysed grid) and an SRT caption track —
      // both resolved before frame 0 by the same pre-passes lesson 10 uses.
      final video = lessonForId('12_the_kitchen_sink')!.video();
      final tracks = collectReactiveTracks(video);
      expect(
        tracks.byAnchor,
        isNotEmpty,
        reason: 'lesson 12 should name its Audio.music track so Trigger.beat can follow it',
      );
      expect(
        collectCaptionSource(video),
        isNotNull,
        reason: 'lesson 12 should declare a Captions.fromSrt track',
      );
    });

    testWidgets('lesson 12 Trigger.beat resolves warning-free against the '
        'analysed grid (WI-29, D-BeatWiring)', (tester) async {
      // The proof the Phase 14 beat wiring works: the kitchen sink's
      // Trigger.beat resolves to a real beat of the committed WAV through the
      // BeatGridScope the shell mounts. If the grid is missing the resolver
      // throws "no grid", so a warning-free, row-bearing timeline confirms the
      // beat-pop placed against an analysed beat.
      final video = lessonForId('12_the_kitchen_sink')!.video();
      final grids = await tester.runAsync(() => _beatGridsFor(video));
      expect(grids, isNotNull, reason: 'lesson 12 should analyse a beat-tagged track');

      final probe = TimelineProbe();
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.capture,
          child: RenderControllerScope(
            controller: RenderController(),
            child: BeatGridScope(
              defaultBeatGrid: grids!.defaultBeatGrid,
              trackBeatGrids: grids.trackBeatGrids,
              child: TimelineProbeScope(
                probe: probe,
                child: Directionality(textDirection: TextDirection.ltr, child: video),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final timeline = probe.value;
      expect(timeline, isNotNull);
      expect(
        timeline!.warnings,
        isEmpty,
        reason: 'lesson 12 Trigger.beat resolved with warnings:\n${debugTimeline(timeline)}',
      );
      expect(timeline.rows, isNotEmpty);
    });

    test('lesson 06 carries the pixel-fx overlay (WI-22): grain, vignette, confetti', () {
      // The upgraded collage applies two pixel post-effects to the wall and a
      // seeded particle burst to the caption — the kinds the doc demonstrates.
      final scene = lessonForId('06_collage')!.video().scenes.single;
      final effects = [
        for (final target in _motionTargetsIn(scene.children))
          for (final animation in target.animations) animation.effect,
      ];

      expect(
        effects.where((e) => effectKindOf(e) == EffectKind.pixel),
        hasLength(3),
        reason: 'expected grain, vignette, and a confetti particle effect',
      );
    });

    testWidgets('every lesson resolves to a warning-free timeline (D21)', (tester) async {
      for (final lesson in lessons) {
        final video = lesson.video();
        // A beat-driven lesson (12) needs the analysed beat grids above the
        // Video so Trigger.beat resolves; the capture shell mounts these in a
        // render, so the warning-free pump mounts the same scope here. A lesson
        // with no beat-tagged audio gets a no-op wrap.
        final grids = await tester.runAsync(() => _beatGridsFor(video));

        final probe = TimelineProbe();
        final controller = RenderController();
        Widget timed = TimelineProbeScope(
          probe: probe,
          child: Directionality(textDirection: TextDirection.ltr, child: video),
        );
        if (grids != null) {
          timed = BeatGridScope(
            defaultBeatGrid: grids.defaultBeatGrid,
            trackBeatGrids: grids.trackBeatGrids,
            child: timed,
          );
        }
        await tester.pumpWidget(
          RenderModeContext(
            mode: RenderMode.preview,
            child: RenderControllerScope(controller: controller, child: timed),
          ),
        );
        // The D1 post-frame pass resolves the plan; the extra pump applies it.
        await tester.pump();

        final timeline = probe.value;
        expect(timeline, isNotNull, reason: '${lesson.id} pushed no timeline');
        expect(
          timeline!.warnings,
          isEmpty,
          reason: '${lesson.id} resolved with warnings:\n${debugTimeline(timeline)}',
        );
        expect(timeline.rows, isNotEmpty, reason: lesson.id);
        // A fresh tree between lessons keeps the registrar generations apart.
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}

/// The analysed beat grids for a beat-driven lesson: the default (master) grid
/// and the per-`Audio.track` grids `Trigger.beat(track:)` resolves against.
typedef _BeatGrids = ({BeatGrid? defaultBeatGrid, Map<Anchor, BeatGrid> trackBeatGrids});

/// Runs the real spectral beat DSP over [video]'s committed WAV (decision
/// D-Lesson) and returns its beat grids, or `null` when it declares no
/// beat-tagged audio — exactly the grids the capture shell mounts so
/// `Trigger.beat` resolves against an analysed grid.
Future<_BeatGrids?> _beatGridsFor(Video video) async {
  final tracks = collectReactiveTracks(video);
  if (tracks.allSources.isEmpty) return null;
  final repository = MediaRepository(
    loader: MediaBytesLoader(
      bundle: rootBundle,
      httpClient: const _UnusedHttpClient(),
      allowlist: NetworkAllowlist.allowAny(),
    ),
  );
  await preResolveReactiveFor(repository, video, fps: video.fps, totalFrames: video.totalFrames);
  final defaultSource = tracks.defaultSource;
  return (
    defaultBeatGrid: defaultSource == null ? null : repository.beatGridFor(defaultSource),
    trackBeatGrids: <Anchor, BeatGrid>{
      for (final entry in tracks.byAnchor.entries) entry.key: repository.beatGridFor(entry.value),
    },
  );
}

/// The reactive pre-pass reads only bundled assets, so the network client is
/// never reached; an unexpected fetch would be a determinism bug, not a download.
class _UnusedHttpClient implements MediaHttpClient {
  const _UnusedHttpClient();

  @override
  Future<Uint8List> get(Uri url) async =>
      throw StateError('The lesson registry resolves only bundled fixtures ($url).');
}

/// Walks the static widget tree [widgets] collecting every [MotionTarget]
/// without mounting it, descending through the container shapes lesson 06 uses
/// (`Padding`, `Positioned`, and the targets' own children).
Iterable<MotionTarget> _motionTargetsIn(List<Widget> widgets) sync* {
  for (final widget in widgets) {
    if (widget is MotionTarget) {
      yield widget;
      yield* _motionTargetsIn([widget.child]);
    } else if (widget is SingleChildRenderObjectWidget && widget.child != null) {
      yield* _motionTargetsIn([widget.child!]);
    } else if (widget is ProxyWidget) {
      yield* _motionTargetsIn([widget.child]);
    }
  }
}
