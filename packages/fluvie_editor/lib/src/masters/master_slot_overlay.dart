import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show decodePlacement;
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/masters/master_edit_session.dart';
import 'package:fluvie_editor/src/widgets/canvas_viewport.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt, OiLabel;

/// The canvas chrome of an adopting slide: a non-interactive corner badge
/// naming the master, and an outline box with the slot name over every
/// unfilled slot (inviting the click that starts the fill flow).
///
/// Editor-only by construction — the overlay never enters the render; a
/// plain render shows nothing for an unfilled slot.
final class MasterSlotOverlay extends StatelessWidget {
  /// Overlays slide [slide] of [document] under [viewport]'s camera.
  const MasterSlotOverlay({
    required this.document,
    required this.slide,
    required this.viewport,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The slide on stage.
  final int slide;

  /// The camera; slot boxes map through it.
  final CanvasViewportController viewport;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = document.sceneMasterName(slide);
    if (name == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: viewport,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            for (final entry in unfilledSlotRects(document, slide).entries)
              Positioned.fromRect(
                rect: Rect.fromPoints(
                  viewport.toViewport(entry.value.topLeft),
                  viewport.toViewport(entry.value.bottomRight),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.accent.base.withValues(alpha: 0.6)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(child: OiLabel.small(entry.key, color: colors.textSubtle)),
                ),
              ),
            Positioned(
              left: viewport.toViewport(Offset.zero).dx + 6,
              top: viewport.toViewport(Offset.zero).dy + 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: OiLabel.small('master: $name', color: colors.textSubtle),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The canvas-pixel boxes of slide [slide]'s unfilled slots, by slot name:
/// the placeholder's placement, or the default slot box for a placeholder
/// without one — so every unfilled slot has a clickable home.
Map<String, Rect> unfilledSlotRects(EditorDocument document, int slide) {
  final size = document.spec.size;
  final canvas = Size(size.width.toDouble(), size.height.toDouble());
  final rects = <String, Rect>{};
  for (final slot in document.masterSlots(slide)) {
    if (slot.fillId != null) continue;
    final transform = slot.transform ?? MasterEditSession.defaultSlotTransform;
    final rect = decodePlacement(transform).rectFor(canvas);
    if (rect != null) rects[slot.slot] = rect;
  }
  return rects;
}

/// Whether clicking the slot [slot] should open the media picker instead of
/// the inline text editor — media wants media, everything else types.
bool slotPrefersMedia(String slot) {
  final lower = slot.toLowerCase();
  return lower.startsWith('media') || lower.startsWith('image') || lower.startsWith('video');
}
