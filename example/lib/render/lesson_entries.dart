import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/lessons/lessons.dart';
import 'package:fluvie_example/render/composition_entry.dart';

/// Every lesson as a renderable [CompositionEntry]: the key is the
/// lesson id, the geometry comes from the lesson's own `Video`, and the build
/// wraps it in a [Directionality] because the capture harness mounts no
/// `WidgetsApp` (the `multi_scene` precedent).
final List<CompositionEntry> lessonEntries = List<CompositionEntry>.unmodifiable([
  for (final lesson in lessons) _entryFor(lesson),
]);

/// One lesson's entry; the probe `Video` is built once for the geometry and
/// the media collect pass and never mounted — every render builds
/// a fresh tree via `lesson.video()`.
CompositionEntry _entryFor(Lesson lesson) {
  final probe = lesson.video();
  return CompositionEntry(
    key: lesson.id,
    width: probe.width,
    height: probe.height,
    fps: probe.fps,
    frameCount: probe.totalFrames,
    mediaSources: collectMediaSources(probe.scenes),
    build: () => Directionality(textDirection: TextDirection.ltr, child: lesson.video()),
  );
}
