import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show Video;
import 'package:fluvie_presenter/src/controller/presentation_controller.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_frame.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt, OiLabel;

/// What the next input produces: the next step of this slide, or the next
/// slide at its base step — rendered live, settled, on a held clock.
///
/// At the end of the deck it says so instead of guessing.
final class SpeakerNextPreview extends ConsumerWidget {
  /// Creates the preview for [video].
  const SpeakerNextPreview({required this.video, super.key});

  /// The authored deck.
  final Video video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the state keeps the preview following navigation; the
    // derived next position comes from the controller.
    ref.watch(presentationControllerProvider);
    final controller = ref.read(presentationControllerProvider.notifier);
    final next = controller.nextPosition;
    final colors = context.colors;
    if (next == null) {
      return ColoredBox(
        color: colors.surfaceSubtle,
        child: Center(child: OiLabel.small('End of deck', color: colors.textMuted)),
      );
    }
    final plans = ref.watch(slidePlansProvider);
    return SlidePreviewFrame(video: video, plan: plans[next.slide], step: next.step);
  }
}
