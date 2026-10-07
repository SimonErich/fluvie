import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:meta/meta.dart';

/// One contiguous run of slides in the slide strip, under an optional named
/// header.
///
/// Sections derive from `section` markers in the per-slide editor metadata
/// (`editor.scenes`): a marker starts a named section that runs until the
/// next marker or the end of the deck. Slides before the first marker form
/// an implicit unnamed section ([name] is null). Because the marker rides
/// the scene-meta channel, it follows its slide through add, remove, and
/// reorder — and never moves the render digest.
@immutable
final class DeckSection {
  /// Describes the run of [count] slides starting at [start].
  const DeckSection({
    required this.start,
    required this.count,
    this.name,
    this.collapsed = false,
  });

  /// The header's name, or null for the implicit unsectioned run.
  final String? name;

  /// Whether the strip hides this section's tiles.
  final bool collapsed;

  /// The first slide of the section.
  final int start;

  /// How many slides the section holds.
  final int count;

  /// One past the section's last slide.
  int get end => start + count;
}

/// Derives the slide strip's sections from [document]'s `section` markers.
///
/// A deck without markers is a single unnamed section; a marker without a
/// `name` reads as "Section".
List<DeckSection> deckSections(EditorDocument document) {
  final starts = <int>[];
  final markers = <int, ({String name, bool collapsed})>{};
  for (var slide = 0; slide < document.sceneCount; slide++) {
    final marker = document.sceneMeta(slide)['section'];
    if (marker is! Map<String, Object?>) continue;
    starts.add(slide);
    markers[slide] = (
      name: marker['name'] is String ? marker['name']! as String : 'Section',
      collapsed: marker['collapsed'] == true,
    );
  }
  final sections = <DeckSection>[];
  if (starts.isEmpty || starts.first > 0) {
    sections.add(DeckSection(start: 0, count: starts.isEmpty ? document.sceneCount : starts.first));
  }
  for (var i = 0; i < starts.length; i++) {
    final start = starts[i];
    final end = i + 1 < starts.length ? starts[i + 1] : document.sceneCount;
    final marker = markers[start]!;
    sections.add(
      DeckSection(name: marker.name, collapsed: marker.collapsed, start: start, count: end - start),
    );
  }
  return sections;
}
