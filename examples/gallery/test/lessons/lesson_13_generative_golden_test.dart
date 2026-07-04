// Lesson 13's poster golden. The generative lesson cannot golden through the
// shared media path (its widgets declare a GenerativeSource, not a MediaSource),
// so it mounts a deterministic fake generative resolver that maps each prompt to
// a committed fixture — the poster then shows the produced image present, exactly
// as a real render would, with no API keys.
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/composition/runtime/generative_collector.dart';
import 'package:fluvie/src/media/runtime/generative_resolver_scope.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie_example/lessons/13_generative_content.dart';
import 'package:fluvie_example/lessons/poster_frame.dart';

import '../render/fake_lesson_media.dart';

Future<void> main() async {
  // The fixtures load from the asset bundle in main() (before any goldenTest), so
  // the binding must be ready first.
  TestWidgetsFlutterBinding.ensureInitialized();
  const lesson = lesson13GenerativeContent;
  final probe = lesson.video();
  final frame = posterFrameOf(probe);

  // Map each visual generative source to a committed fixture, so the golden is
  // deterministic and needs no provider keys.
  final media = <GenerativeSource, MediaSource>{
    for (final source in collectGenerativeSources(probe.scenes))
      if (source.kind == GenerativeKind.video)
        source: const MediaSource.asset('assets/fixtures/clip_1s.mp4')
      else if (source.isVisual)
        source: const MediaSource.asset('assets/fixtures/swatch.png'),
  };
  final fakeMedia = await FakeLessonMedia.create(media.values.toSet());
  await fakeMedia.preResolveAll(media.values);

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
              child: ImageResolverScope(
                resolver: fakeMedia,
                child: GenerativeResolverScope(
                  resolver: _FakeGenerative(media),
                  child: Directionality(textDirection: TextDirection.ltr, child: lesson.video()),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A deterministic generative resolver for the golden: it produces nothing and
/// serves each source's committed fixture media.
final class _FakeGenerative implements GenerativeResolver {
  _FakeGenerative(this._media);

  final Map<GenerativeSource, MediaSource> _media;

  @override
  Future<void> generateAll(
    Iterable<GenerativeSource> sources, {
    void Function(GenerativeProgress progress)? onProgress,
  }) async {}

  @override
  MediaSource mediaFor(GenerativeSource source) => _media[source]!;

  @override
  AudioSource audioFor(GenerativeSource source) =>
      throw StateError('the lesson 13 golden uses no generated audio');

  @override
  GeneratedAssetMeta metaFor(GenerativeSource source) =>
      (duration: null, hasAudio: false, width: null, height: null);
}
