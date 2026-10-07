part of 'editor_command.dart';

/// Writes the deck's `theme` block wholesale — every theme-panel edit is
/// one of these, so every token change is one undoable step.
final class SetThemeCommand extends EditorCommand {
  /// Sets the theme to [theme] (null removes the block). A non-null
  /// [mergeGroup] coalesces a stream (a swatch drag) into one step; [verb]
  /// names the step for the undo menu ("Edit", "Apply").
  const SetThemeCommand({required this.theme, this.mergeGroup, this.verb = 'Edit'});

  /// The whole new theme JSON, or null to clear it.
  final Map<String, Object?>? theme;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  /// What the undo menu calls this ("Edit", "Apply").
  final String verb;

  @override
  EditorDocument apply(EditorDocument document) => document.updateVideo({'theme': theme});

  @override
  String get label => '$verb theme';

  @override
  Set<String> get affectedIds => const {};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'theme:$mergeGroup';
}

/// Renames a theme token and rewrites every `{"token": ...}` reference
/// bound to it — the theme entry and its consumers move as one undo step.
final class RenameThemeTokenCommand extends EditorCommand {
  /// Renames the [map] entry [from] to [to].
  const RenameThemeTokenCommand({required this.map, required this.from, required this.to});

  /// The theme map holding the token (`palette` or `typeScale`).
  final String map;

  /// The current token name.
  final String from;

  /// The new token name.
  final String to;

  @override
  EditorDocument apply(EditorDocument document) =>
      document.renameThemeToken(map: map, from: from, to: to);

  @override
  String get label => 'Rename token';

  @override
  Set<String> get affectedIds => const {};
}
