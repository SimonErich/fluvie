import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show decodeColor, encodeColor;
import 'package:fluvie_editor/src/widgets/color_field.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:obers_ui/obers_ui.dart';

/// The floating mini-toolbar above a selection: the two or three most
/// useful actions for the element's type — a color swatch, font-size
/// steps for text, and delete.
final class SelectionToolbar extends StatelessWidget {
  /// Shows actions for [element]; patches land in [onPatch], delete in
  /// [onDelete].
  const SelectionToolbar({
    required this.element,
    required this.onPatch,
    required this.onDelete,
    super.key,
  });

  /// The selected element's JSON.
  final Map<String, Object?> element;

  /// Receives content patches (merged over the element).
  final void Function(Map<String, Object?> patch) onPatch;

  /// Deletes the element.
  final VoidCallback onDelete;

  bool get _hasColor => switch (element['type']) {
    'Box' || 'Shape' || 'Arrow' || 'Connector' => true,
    _ => false,
  };

  Map<String, Object?> get _style => element['style'] is Map<String, Object?>
      ? element['style']! as Map<String, Object?>
      : const {};

  void _bumpFontSize(double delta) {
    final current = _style['fontSize'] is num ? (_style['fontSize']! as num).toDouble() : 32.0;
    onPatch({
      'style': {..._style, 'fontSize': (current + delta).clamp(4, 512)},
    });
  }

  Color _color(Object? raw, Color fallback) =>
      raw == null ? fallback : decodeColor(raw, path: const ['color']);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isText = element['type'] == 'Text';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.borderSubtle),
        boxShadow: [BoxShadow(color: colors.overlay.withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isText) ...[
              EditorTip(
                message: 'Smaller text',
                child: OiIconButton(
                  icon: OiIcons.minus,
                  semanticLabel: 'Smaller text',
                  onTap: () => _bumpFontSize(-4),
                ),
              ),
              EditorTip(
                message: 'Larger text',
                child: OiIconButton(
                  icon: OiIcons.plus,
                  semanticLabel: 'Larger text',
                  onTap: () => _bumpFontSize(4),
                ),
              ),
              SizedBox(
                width: 26,
                height: 22,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ColorField(
                    label: 'Text color',
                    color: _color(_style['color'], const Color(0xFFF9FAFB)),
                    onChanged: (next) => onPatch({
                      'style': {..._style, 'color': encodeColor(next)},
                    }),
                  ),
                ),
              ),
            ],
            if (_hasColor)
              SizedBox(
                width: 26,
                height: 22,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ColorField(
                    label: 'Element color',
                    color: _color(element['color'], const Color(0xFF6C5CE7)),
                    onChanged: (next) => onPatch({'color': encodeColor(next)}),
                  ),
                ),
              ),
            EditorTip(
              message: 'Delete (Backspace)',
              child: OiIconButton(
                icon: OiIcons.trash,
                semanticLabel: 'Delete element',
                onTap: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
