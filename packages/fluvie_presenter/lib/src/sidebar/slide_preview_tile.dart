import 'package:flutter/widgets.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_service.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt, OiLabel;

/// One slide thumbnail: the cached preview when it has rendered, a flat
/// placeholder until then, the slide number in the corner, and an accent
/// border when it is the current slide.
///
/// The tile listens to the preview service, so it repaints by itself when
/// its image lands — presenting never waits on previews.
final class SlidePreviewTile extends StatelessWidget {
  /// Creates the tile for [slide].
  const SlidePreviewTile({
    required this.slide,
    required this.service,
    required this.selected,
    required this.onTap,
    required this.aspectRatio,
    super.key,
  });

  /// The slide index this tile shows.
  final int slide;

  /// The shared preview cache.
  final SlidePreviewService service;

  /// Whether this is the current slide.
  final bool selected;

  /// Navigates to the slide.
  final VoidCallback onTap;

  /// The deck's canvas aspect ratio.
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: service,
        builder: (context, _) {
          final image = service.peek(slide);
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? colors.accent.base : colors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null)
                    RawImage(image: image, fit: BoxFit.cover)
                  else
                    ColoredBox(color: colors.surfaceSubtle),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: OiLabel.tiny('${slide + 1}', color: colors.textSubtle),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
