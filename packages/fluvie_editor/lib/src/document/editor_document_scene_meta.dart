part of 'editor_document.dart';

/// Keeps the editor block's per-slide metadata (`editor.scenes`, keyed by
/// slide index) aligned when slides move: metadata follows its slide through
/// insertion, removal, and reorder. Keys that are not slide indices (a
/// hand-edited block) are dropped rather than guessed at.
void _remapSceneMeta(Map<String, Object?> json, int? Function(int index) mapper) {
  final editor = json['editor'];
  if (editor is! Map<String, Object?>) return;
  _remapOverlayHomes(json, editor, mapper);
  final scenes = editor['scenes'];
  if (scenes is! Map<String, Object?>) return;
  final remapped = <String, Object?>{};
  for (final entry in scenes.entries) {
    final index = int.tryParse(entry.key);
    if (index == null) continue;
    final next = mapper(index);
    if (next == null) continue;
    remapped['$next'] = entry.value;
  }
  editor['scenes'] = remapped;
}

/// The overlay homes through the same slide move.
///
/// Homes are index *values* where `editor.scenes` holds index *keys*, and they
/// differ in one way the key mapping cannot express: an overlay whose home
/// slide is deleted does not go with it. It belongs to the video, so it
/// re-homes to the slide that took its place rather than vanishing.
void _remapOverlayHomes(
  Map<String, Object?> json,
  Map<String, Object?> editor,
  int? Function(int index) mapper,
) {
  final homes = editor['overlayHomes'];
  if (homes is! Map<String, Object?> || homes.isEmpty) return;
  final scenes = json['scenes'];
  final last = scenes is List ? scenes.length - 1 : 0;
  final remapped = <String, Object?>{};
  for (final entry in homes.entries) {
    final home = entry.value;
    if (home is! int) continue;
    remapped[entry.key] = (mapper(home) ?? home).clamp(0, last < 0 ? 0 : last);
  }
  editor['overlayHomes'] = remapped;
}

/// The key mapping of inserting a slide at [at]: indices from [at] shift up.
int _insertedAt(int index, int at) => index >= at ? index + 1 : index;

/// The key mapping of removing slide [removed]: its metadata drops, higher
/// indices shift down.
int? _removedAt(int index, int removed) {
  if (index == removed) return null;
  return index > removed ? index - 1 : index;
}

/// The key mapping of moving slide [from] to [to] (list semantics: removed
/// at [from], then inserted at [to]).
int _movedTo(int index, int from, int to) {
  if (index == from) return to;
  if (from < index && index <= to) return index - 1;
  if (to <= index && index < from) return index + 1;
  return index;
}

/// Whole-run slide moves — the strip's section-as-a-unit reorder.
extension EditorDocumentSections on EditorDocument {
  /// Moves the contiguous run of [count] slides starting at [start] so it
  /// begins at [to], keeping its internal order. Composed of single-slide
  /// moves, so per-slide editor metadata (section markers included) follows
  /// every slide. Throws a [RangeError] when the run or the target falls
  /// outside the deck.
  EditorDocument reorderSceneRange({required int start, required int count, required int to}) {
    if (count < 1) throw RangeError.range(count, 1, sceneCount, 'count');
    RangeError.checkValueInInterval(start, 0, sceneCount - count, 'start');
    RangeError.checkValueInInterval(to, 0, sceneCount - count, 'to');
    var document = this;
    for (var i = 0; i < count; i++) {
      document = to < start
          ? document.reorderScene(start + i, to + i)
          : document.reorderScene(start, to + count - 1);
    }
    return document;
  }
}
