import 'package:flutter/widgets.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_service.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt, OiLabel;

/// One slide thumbnail: the cached preview when it has rendered, a flat
/// placeholder until then, the slide number in the corner, an accent
/// border when it is the current slide, and a hover highlight under a
/// mouse.
///
/// The tile listens to the preview service, so it repaints by itself when
/// its image lands — presenting never waits on previews.
final class SlidePreviewTile extends StatefulWidget {
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
  State<SlidePreviewTile> createState() => _SlidePreviewTileState();
}

final class _SlidePreviewTileState extends State<SlidePreviewTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: widget.service,
          builder: (context, _) {
            final image = widget.service.peek(widget.slide);
            return DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected || _hovered ? colors.accent.base : colors.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null)
                      RawImage(image: image, fit: BoxFit.cover)
                    else
                      ColoredBox(color: colors.surfaceSubtle),
                    // A mouse over the tile lifts it slightly out of the dark.
                    if (_hovered && !selected)
                      ColoredBox(color: colors.accent.base.withValues(alpha: 0.08)),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: OiLabel.tiny('${widget.slide + 1}', color: colors.textSubtle),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
