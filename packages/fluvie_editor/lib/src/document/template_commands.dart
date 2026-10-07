part of 'editor_command.dart';

/// Inserts one template slide into the open deck as a single undo step,
/// merging what the slide needs to build: missing theme tokens arrive from
/// the template's theme (existing deck tokens always win) and masters the
/// deck lacks arrive from the template (a name the deck already defines
/// keeps the deck's master).
///
/// The caller prepares [scene] with `preparedTemplateScene`, so every
/// element id is minted up front and redo stays deterministic.
final class InsertTemplateSlideCommand extends EditorCommand {
  /// Inserts [scene] (appended, or at [at]), merging the template's [theme]
  /// and [masters] additively first.
  const InsertTemplateSlideCommand({required this.scene, this.at, this.theme, this.masters});

  /// The prepared scene JSON (ids minted).
  final Map<String, Object?> scene;

  /// The slide position, or null to append.
  final int? at;

  /// The template's theme, or null for none.
  final Map<String, Object?>? theme;

  /// The template's masters, or null for none.
  final Map<String, Object?>? masters;

  @override
  EditorDocument apply(EditorDocument document) {
    final json = document.toJson();
    final deckMasters = json['masters'];
    final mergedMasters = mergedMastersJson(
      deckMasters is Map<String, Object?> ? deckMasters : null,
      masters,
    );
    final mergedTheme = mergedThemeJson(document.themeJson, theme);
    final patch = {'masters': ?mergedMasters, 'theme': ?mergedTheme};
    final merged = patch.isEmpty ? document : document.updateVideo(patch);
    return merged.addScene(scene, at: at);
  }

  @override
  String get label => 'Insert template slide';

  @override
  Set<String> get affectedIds => {
    for (final id in _templateIds(scene)) id,
  };
}

Iterable<String> _templateIds(Map<String, Object?> scene) sync* {
  Iterable<String> walk(Map<String, Object?> element) sync* {
    if (element['id'] case final String id) yield id;
    final children = element['children'];
    if (element['type'] == 'Group' && children is List) {
      for (final child in children.whereType<Map<String, Object?>>()) {
        yield* walk(child);
      }
    }
  }

  final children = scene['children'];
  if (children is List) {
    for (final child in children.whereType<Map<String, Object?>>()) {
      yield* walk(child);
    }
  }
  final fills = scene['fills'];
  if (fills is Map<String, Object?>) {
    for (final fill in fills.values.whereType<Map<String, Object?>>()) {
      yield* walk(fill);
    }
  }
}
