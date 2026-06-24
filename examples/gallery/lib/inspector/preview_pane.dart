import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/inspector/playback_view_model.dart';
import 'package:fluvie_example/inspector/providers.dart';

/// The live preview: the selected lesson's `Video` mounted under the
/// inspector's frame clock at its natural size, scaled to fit the pane.
///
/// The stack above the video is the preview contract: an explicit
/// [RenderMode.preview] context, the playback view model's controller as the
/// frame clock, and the lesson's [TimelineProbe] so the video can push its
/// resolved timeline to the inspector pane.
final class PreviewPane extends ConsumerWidget {
  /// Creates the preview pane.
  const PreviewPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref.watch(selectedLessonProvider);
    // Watching totalFrames (never `frame`) keeps this pane from rebuilding on
    // every scrub — a rebuilt pane would remount the Video and re-resolve the
    // whole plan — while still flushing a dirty playback provider, so the
    // controller below is always the one built for [lesson].
    ref.watch(playbackViewModelProvider.select((state) => state.totalFrames));
    final controller = ref.watch(playbackViewModelProvider.notifier).controller;
    final probe = ref.watch(timelineProbeProvider);
    final video = lesson.video();

    return RenderModeContext(
      mode: RenderMode.preview,
      child: RenderControllerScope(
        controller: controller,
        child: TimelineProbeScope(
          probe: probe,
          child: ColoredBox(
            color: const Color(0xFF14141C),
            child: FittedBox(
              child: SizedBox(
                width: video.width.toDouble(),
                height: video.height.toDouble(),
                child: video,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
