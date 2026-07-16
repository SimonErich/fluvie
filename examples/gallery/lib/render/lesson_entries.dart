import 'package:fluvie_example/lessons/lessons.dart';
import 'package:fluvie_example/render/composition_entry.dart';

/// Every lesson as a renderable [CompositionEntry], keyed by the lesson id.
final List<CompositionEntry> lessonEntries = List<CompositionEntry>.unmodifiable([
  for (final lesson in lessons) CompositionEntry(key: lesson.id, video: lesson.video),
]);
