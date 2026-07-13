import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_presenter/src/controller/presentation_controller.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_service.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_tile.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt;

/// The togglable slide list: one preview tile per slide, the current one
/// highlighted and kept in view, click to jump.
///
/// Previews request lazily as tiles build; the shared service caches them
/// for the overview grid too.
final class SlideSidebar extends ConsumerStatefulWidget {
  /// Creates the sidebar; [aspectRatio] is the deck's canvas ratio.
  const SlideSidebar({required this.aspectRatio, this.width = 168, super.key});

  /// The tile aspect ratio (the deck canvas).
  final double aspectRatio;

  /// The sidebar width in logical pixels.
  final double width;

  @override
  ConsumerState<SlideSidebar> createState() => _SlideSidebarState();
}

final class _SlideSidebarState extends ConsumerState<SlideSidebar> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    ref.listenManual(presentationControllerProvider, (previous, next) {
      if (previous?.position.slide == next.position.slide) return;
      _keepInView(next.position.slide);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls so the current slide's tile is visible.
  void _keepInView(int slide) {
    if (!_scroll.hasClients) return;
    final tileHeight = widget.width / widget.aspectRatio + 8;
    final target = (slide * tileHeight).clamp(0.0, _scroll.position.maxScrollExtent);
    unawaited(
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(sidebarVisibleProvider)) return const SizedBox.shrink();
    final plans = ref.watch(slidePlansProvider);
    final service = ref.watch(slidePreviewServiceProvider);
    final current = ref.watch(
      presentationControllerProvider.select((state) => state.position.slide),
    );
    final colors = context.colors;
    return ColoredBox(
      color: colors.surface,
      child: SizedBox(
        width: widget.width,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(8),
          itemCount: plans.length,
          itemBuilder: (context, slide) {
            // Lazy and off the critical path: request when the tile builds,
            // paint whenever it lands.
            unawaited(service.preview(slide).then((_) {}, onError: (_) {}));
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SlidePreviewTile(
                slide: slide,
                service: service,
                selected: slide == current,
                aspectRatio: widget.aspectRatio,
                onTap: () => ref.read(presentationControllerProvider.notifier).jumpToSlide(slide),
              ),
            );
          },
        ),
      ),
    );
  }
}
