import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

/// Edit mode's host: the editor canvas over one slide of the document, a
/// slide stepper, and the way back. Phase 1 is read-only — the panels,
/// tools, and inspector arrive with the authoring surface.
final class EditorScreen extends StatefulWidget {
  /// Opens [document] for viewing at slide zero.
  const EditorScreen({
    required this.document,
    required this.title,
    required this.onClose,
    super.key,
  });

  /// The deck on the canvas.
  final EditorDocument document;

  /// What the top bar calls the deck.
  final String title;

  /// Back to the picker.
  final VoidCallback onClose;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

final class _EditorScreenState extends State<EditorScreen> {
  int _slide = 0;

  void _step(int delta) {
    final next = (_slide + delta).clamp(0, widget.document.sceneCount - 1);
    if (next != _slide) setState(() => _slide = next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.background,
      child: Column(
        children: [
          ColoredBox(
            color: colors.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  OiIconButton(
                    icon: OiIcons.x,
                    semanticLabel: 'Close editor',
                    onTap: widget.onClose,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: OiLabel.bodyStrong(widget.title)),
                  OiIconButton(
                    icon: OiIcons.chevronLeft,
                    semanticLabel: 'Previous slide',
                    onTap: () => _step(-1),
                  ),
                  OiLabel.small(
                    '${_slide + 1} / ${widget.document.sceneCount}',
                    color: colors.textSubtle,
                  ),
                  OiIconButton(
                    icon: OiIcons.chevronRight,
                    semanticLabel: 'Next slide',
                    onTap: () => _step(1),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: EditorCanvas(document: widget.document, slide: _slide),
          ),
        ],
      ),
    );
  }
}
