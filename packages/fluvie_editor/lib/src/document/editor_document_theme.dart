part of 'editor_document.dart';

/// The document's theme block: reading it, spotting live `{"token": ...}`
/// references, and the rename transform that keeps them honest.
extension EditorDocumentTheme on EditorDocument {
  /// A copy of the deck's top-level `theme` JSON, or null when it has none.
  Map<String, Object?>? get themeJson {
    final theme = _json['theme'];
    return theme is Map<String, Object?> ? _deepCopy(theme) : null;
  }

  /// Whether any `token` reference in the scenes or masters names [name] —
  /// a color's `{"token": name}` or a style object's `"token"` base. A
  /// referenced token cannot be removed without breaking the next build.
  bool themeTokenReferenced(String name) =>
      _referencesToken(_json['scenes'], name) || _referencesToken(_json['masters'], name);

  /// Renames the theme [map] entry [from] (`palette` or `typeScale`) to
  /// [to], rewriting every reference in the scenes and masters in the same
  /// step. Throws an [ArgumentError] when the entry does not exist or [to]
  /// is already taken.
  EditorDocument renameThemeToken({
    required String map,
    required String from,
    required String to,
  }) => _mutate((json) {
    final theme = json['theme'];
    final entries = theme is Map<String, Object?> ? theme[map] : null;
    if (entries is! Map<String, Object?> || !entries.containsKey(from)) {
      throw ArgumentError.value(from, 'from', 'No $map token with this name');
    }
    if (entries.containsKey(to)) {
      throw ArgumentError.value(to, 'to', 'A $map token with this name already exists');
    }
    (theme! as Map<String, Object?>)[map] = {
      for (final entry in entries.entries)
        if (entry.key == from) to: entry.value else entry.key: entry.value,
    };
    _rewriteTokenRefs(json['scenes'], from, to);
    _rewriteTokenRefs(json['masters'], from, to);
  });
}

bool _referencesToken(Object? node, String name) => switch (node) {
  Map<String, Object?>() =>
    node['token'] == name || node.values.any((value) => _referencesToken(value, name)),
  List<Object?>() => node.any((value) => _referencesToken(value, name)),
  _ => false,
};

void _rewriteTokenRefs(Object? node, String from, String to) {
  switch (node) {
    case Map<String, Object?>():
      if (node['token'] == from) node['token'] = to;
      for (final value in node.values) {
        _rewriteTokenRefs(value, from, to);
      }
    case List<Object?>():
      for (final value in node) {
        _rewriteTokenRefs(value, from, to);
      }
  }
}
