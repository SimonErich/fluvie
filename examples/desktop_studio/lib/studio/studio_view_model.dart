import 'package:desktop_studio/render/render_service.dart';
import 'package:desktop_studio/render/save_dialog_service.dart';
import 'package:desktop_studio/render/templates.dart';
import 'package:desktop_studio/studio/studio_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drives the studio: picks a template and renders it to a file via the CLI.
class StudioViewModel extends Notifier<StudioState> {
  @override
  StudioState build() => StudioState(selectedKey: studioTemplates.first.key);

  /// The currently selected template.
  StudioTemplate get template => templateForKey(state.selectedKey);

  /// Selects [key] and clears any prior result.
  void selectTemplate(String key) => state = state.copyWith(
    selectedKey: key,
    status: StudioStatus.idle,
    clearResult: true,
    clearError: true,
  );

  /// Toggles the draft (fast, fewer-frames) render.
  void toggleDraft() => state = state.copyWith(draft: !state.draft);

  /// Asks where to save, then renders the selected template there via the CLI.
  Future<void> render() async {
    if (state.isRendering) return;
    final path = await ref
        .read(saveDialogServiceProvider)
        .chooseSavePath('${state.selectedKey}.mp4');
    if (path == null) return; // The user cancelled the save dialog.
    state = state.copyWith(
      status: StudioStatus.rendering,
      clearResult: true,
      clearError: true,
    );
    try {
      final result = await ref
          .read(renderServiceProvider)
          .render(key: state.selectedKey, outputPath: path, draft: state.draft);
      state = state.copyWith(status: StudioStatus.done, result: result);
    } on Object catch (error) {
      state = state.copyWith(status: StudioStatus.failed, error: '$error');
    }
  }
}

/// The studio view-model provider.
final NotifierProvider<StudioViewModel, StudioState> studioViewModelProvider =
    NotifierProvider<StudioViewModel, StudioState>(StudioViewModel.new);
