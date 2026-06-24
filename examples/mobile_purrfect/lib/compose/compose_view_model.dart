import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitten_kit/kitten_kit.dart';

import 'package:mobile_purrfect/compose/compose_state.dart';
import 'package:mobile_purrfect/render/mobile_render_service.dart';
import 'package:mobile_purrfect/services/photo_picker_service.dart';
import 'package:mobile_purrfect/services/share_service.dart';

/// Drives the compose screen: edits the card, renders it on-device, and shares.
class ComposeViewModel extends Notifier<ComposeState> {
  @override
  ComposeState build() => const ComposeState(catName: '');

  /// Sets the cat's name.
  void setCatName(String value) => state = state.copyWith(catName: value);

  /// Picks a photo from the gallery; ignored when the user cancels.
  Future<void> pickPhoto() async {
    final bytes = await ref.read(photoPickerServiceProvider).pickImage();
    if (bytes != null) state = state.copyWith(photoBytes: bytes);
  }

  /// Renders the birthday card to an MP4 on the device.
  Future<void> render() async {
    if (!state.canRender) return;
    state = state.copyWith(
      status: ComposeStatus.rendering,
      progress: 0,
      clearError: true,
      clearOutput: true,
    );
    try {
      final file = await ref
          .read(mobileRenderServiceProvider)
          .render(
            catName: state.catName.trim(),
            photoBytes: state.photoBytes,
            song: KittenAssets.jingle,
            onProgress: (progress) => state = state.copyWith(progress: progress),
          );
      state = state.copyWith(status: ComposeStatus.done, outputPath: file.path);
    } on Object catch (error) {
      state = state.copyWith(status: ComposeStatus.failed, error: '$error');
    }
  }

  /// Opens the share sheet for the rendered card.
  Future<void> share() async {
    final path = state.outputPath;
    if (path != null) await ref.read(shareServiceProvider).shareVideo(path);
  }

  /// Returns to editing to make another card.
  void reset() => state = state.copyWith(
    status: ComposeStatus.editing,
    clearOutput: true,
    clearError: true,
  );
}

/// The compose view-model provider.
final NotifierProvider<ComposeViewModel, ComposeState> composeViewModelProvider =
    NotifierProvider<ComposeViewModel, ComposeState>(
      ComposeViewModel.new,
    );
