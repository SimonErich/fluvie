import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_presenter/src/controller/presentation_controller.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_service.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_tile.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt;

/// The overview: every slide as a grid of previews over a dimmed stage
/// (the O shortcut). Picking a slide navigates and closes; Esc just closes.
///
/// The grid reuses the sidebar's preview cache — the same image never
/// renders twice.
final class OverviewGrid extends ConsumerWidget {
  /// Creates the grid; [aspectRatio] is the deck's canvas ratio.
  const OverviewGrid({required this.aspectRatio, super.key});

  /// The tile aspect ratio (the deck canvas).
  final double aspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(overviewVisibleProvider)) return const SizedBox.shrink();
    final plans = ref.watch(slidePlansProvider);
    final service = ref.watch(slidePreviewServiceProvider);
    final current = ref.watch(
      presentationControllerProvider.select((state) => state.position.slide),
    );
    return ColoredBox(
      color: context.colors.overlay,
      child: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          childAspectRatio: aspectRatio,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        itemCount: plans.length,
        itemBuilder: (context, slide) {
          unawaited(service.preview(slide).then((_) {}, onError: (_) {}));
          return SlidePreviewTile(
            slide: slide,
            service: service,
            selected: slide == current,
            aspectRatio: aspectRatio,
            onTap: () {
              ref.read(presentationControllerProvider.notifier).jumpToSlide(slide);
              ref.read(overviewVisibleProvider.notifier).visible = false;
            },
          );
        },
      ),
    );
  }
}
