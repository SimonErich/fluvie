part of 'editor_screen.dart';

extension _EditorScreenPreferences on _EditorScreenState {
  Future<void> _loadViewSettings() async {
    try {
      final loaded = await widget.layoutSettings?.load<EditorViewSettings>(
        namespace: editorShellSettingsNamespace,
        key: 'view',
        deserialize: EditorViewSettings.fromJson,
      );
      if (!mounted || loaded == null || _viewChanged) return;
      _refresh(() {
        _workspace = loaded.workspace;
        _previewScale = loaded.previewScale;
        _bypassEffects = loaded.bypassEffects;
        _quickGuideDismissed = loaded.quickGuideDismissed;
      });
    } on Object {
      // Preferences are best-effort: an unreadable settings store never
      // prevents opening a deck, and choosing a view still works in memory.
    }
  }

  void _setWorkspace(EditorWorkspace workspace) {
    _viewChanged = true;
    _refresh(() => _workspace = workspace);
    unawaited(_saveViewSettings());
  }

  Future<void> _saveViewSettings() {
    final settings = EditorViewSettings(
      workspace: _workspace,
      previewScale: _previewScale,
      bypassEffects: _bypassEffects,
      quickGuideDismissed: _quickGuideDismissed,
    );
    return _viewSave = _viewSave.then((_) async {
      try {
        await widget.layoutSettings?.save<EditorViewSettings>(
          namespace: editorShellSettingsNamespace,
          key: 'view',
          data: settings,
          serialize: (value) => value.toJson(),
        );
      } on Object {
        // A failing optional store never prevents the next preference save.
      }
    });
  }
}
