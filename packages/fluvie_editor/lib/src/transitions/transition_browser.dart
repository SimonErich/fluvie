import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/transitions/transition_edits.dart';
import 'package:obers_ui/obers_ui.dart';

/// Draggable built-in strategies. Drop a tile near a clip cut on the timeline.
final class TransitionBrowser extends StatelessWidget {
  /// Creates a compact transition palette.
  const TransitionBrowser({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final entry in const {
        'crossFade': 'Dissolve',
        'wipe': 'Wipe',
        'zoom': 'Zoom',
        'slide': 'Slide',
      }.entries)
        Draggable<TransitionDragData>(
          data: TransitionDragData(entry.key),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _tile(context, entry.value),
          childWhenDragging: Opacity(opacity: 0.4, child: _tile(context, entry.value)),
          child: Semantics(
            label: 'Drag ${entry.value} to a clip cut',
            child: MouseRegion(cursor: SystemMouseCursors.grab, child: _tile(context, entry.value)),
          ),
        ),
    ],
  );

  Widget _tile(BuildContext context, String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surfaceSubtle,
      border: Border.all(color: context.colors.borderSubtle),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: OiLabel.small(label, color: context.colors.text),
    ),
  );
}
