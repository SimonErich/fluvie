import 'package:fluvie_example/render/composition_entry.dart';
import 'package:fluvie_example/render/days_recap_composition.dart';
import 'package:fluvie_example/render/demo_composition.dart';
import 'package:fluvie_example/render/lesson_entries.dart';
import 'package:fluvie_example/render/multi_scene_composition.dart';
import 'package:fluvie_example/render/starter_composition.dart';

/// Every composition the capture harness can render, in registration order:
/// the `demo` acceptance, the `multi_scene` acceptance, the `starter` (what
/// `fluvie init` scaffolds), and every lesson.
final List<CompositionEntry> _entries = [
  demoComposition,
  multiSceneComposition,
  starterComposition,
  daysRecapComposition,
  ...lessonEntries,
];

/// The entry registered under [key], or `null` for an unknown key.
CompositionEntry? compositionForKey(String key) {
  for (final entry in _entries) {
    if (entry.key == key) return entry;
  }
  return null;
}

/// The keys of every registered composition.
List<String> get knownCompositionKeys => [for (final entry in _entries) entry.key];
