part of 'editor_command.dart';

/// Places one element in time: writes its `show` window with both bounds in
/// frames form, scene-relative — the exact serialized form of
/// `.show({from, to})`, and where every video-mode lane move and trim lands.
final class SetShowWindowCommand extends EditorCommand {
  /// Windows element [id] to `fromFrames..toFrames` (scene-relative). A
  /// non-null [mergeGroup] coalesces a drag's stream of placements into one
  /// undo step.
  const SetShowWindowCommand({
    required this.id,
    required this.fromFrames,
    required this.toFrames,
    this.mergeGroup,
  });

  /// The element being windowed.
  final String id;

  /// The first scene-relative frame the element is alive.
  final int fromFrames;

  /// The scene-relative frame the window closes on (exclusive).
  final int toFrames;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) => document.replaceElement(id, {
    ...document.elementJson(id)!,
    'show': {'from': '${fromFrames}f', 'to': '${toFrames}f'},
  });

  @override
  String get label => 'Place $id in time';

  @override
  Set<String> get affectedIds => {id};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'show:$mergeGroup:$id';
}
