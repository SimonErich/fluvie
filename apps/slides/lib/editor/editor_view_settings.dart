import 'package:fluvie_editor/fluvie_editor.dart' show EditorWorkspace;
import 'package:obers_ui/obers_ui.dart';

/// Personal view choices; never serialized into an authored deck.
final class EditorViewSettings with OiSettingsData {
  /// Creates the editor view preferences.
  const EditorViewSettings({
    this.workspace = EditorWorkspace.edit,
    this.previewScale = 0.5,
    this.bypassEffects = false,
    this.quickGuideDismissed = false,
  });

  /// Reads old or missing settings with safe defaults.
  factory EditorViewSettings.fromJson(Map<String, dynamic> json) => EditorViewSettings(
    bypassEffects: json['bypassEffects'] == true,
    quickGuideDismissed: json['quickGuideDismissed'] == true,
    workspace: EditorWorkspace.values.asNameMap()[json['workspace']] ?? EditorWorkspace.edit,
    previewScale: switch (json['previewScale']) {
      1 => 1,
      0.25 => 0.25,
      _ => 0.5,
    },
  );

  /// The last workspace the author selected.
  final EditorWorkspace workspace;

  /// The preview resolution relative to delivery size.
  final double previewScale;

  /// Preview-only effects bypass; export always uses the authored effects.
  final bool bypassEffects;

  /// Whether the action-gated first-project guide was dismissed.
  final bool quickGuideDismissed;

  @override
  int get schemaVersion => 1;

  @override
  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'workspace': workspace.name,
    'previewScale': previewScale,
    'bypassEffects': bypassEffects,
    'quickGuideDismissed': quickGuideDismissed,
  };
}
