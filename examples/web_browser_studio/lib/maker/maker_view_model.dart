import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';
import 'package:kitten_kit/kitten_kit.dart';

import 'package:web_browser_studio/maker/maker_state.dart';
import 'package:web_browser_studio/render/web_render_service.dart';

/// Drives the meme maker: edits the inputs and renders the MP4 in the browser.
class MakerViewModel extends Notifier<MakerState> {
  @override
  MakerState build() => const MakerState(
    topText: 'when the human',
    bottomText: 'opens the treat drawer',
    accent: KittenColors.mitten,
  );

  /// Sets the top caption.
  void setTop(String value) => state = state.copyWith(topText: value);

  /// Sets the bottom caption.
  void setBottom(String value) => state = state.copyWith(bottomText: value);

  /// Sets the kitten accent color.
  void setAccent(Color value) => state = state.copyWith(accent: value);

  /// Renders the meme to an MP4 in the browser and hands it to the download.
  Future<void> makeMp4() async {
    if (state.isEncoding) return;
    state = state.copyWith(
      status: MakerStatus.encoding,
      progress: 0,
      clearError: true,
    );
    final service = ref.read(webRenderServiceProvider);
    try {
      final bytes = await service.render(
        memePromo(
          topText: state.topText,
          bottomText: state.bottomText,
          accent: state.accent,
        ),
        aspect: Aspect.square,
        // Matches KittenDurations.meme (4 s); the renderer captures duration * fps.
        duration: const Duration(seconds: 4),
        onProgress: (progress) {
          final total = progress.totalFrames;
          final done = progress.completedFrames;
          if (total != null && total > 0 && done != null) {
            state = state.copyWith(progress: done / total);
          }
        },
      );
      service.download(bytes, 'kitten_meme.mp4');
      state = state.copyWith(status: MakerStatus.done, progress: 1);
    } on Object catch (error) {
      state = state.copyWith(status: MakerStatus.failed, error: '$error');
    }
  }
}

/// The maker view-model provider.
final NotifierProvider<MakerViewModel, MakerState> makerViewModelProvider =
    NotifierProvider<MakerViewModel, MakerState>(MakerViewModel.new);
