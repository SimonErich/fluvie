import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

/// Six essential properties, chosen for the selected element's content type.
final class QuickElementSection extends StatelessWidget {
  /// Uses the same property editors and commands as the full inspector.
  const QuickElementSection({
    required this.document,
    required this.id,
    required this.element,
    required this.styleRows,
    required this.onCommand,
    super.key,
  });

  /// The immutable open document.
  final EditorDocument document;

  /// The selected element identity.
  final String id;

  /// The selected element JSON.
  final Map<String, Object?> element;

  /// Content fields reused from the full inspector.
  final List<OiPropertyRow> styleRows;

  /// Dispatches one user edit.
  final ValueChanged<EditorCommand> onCommand;
  @override
  Widget build(BuildContext context) {
    final raw = element['transform'];
    final transform = raw is Map<String, Object?> ? raw : <String, Object?>{};
    final content = styleRows.take(3).toList();
    final fields = content.length == 3
        ? ['x', 'y', 'opacity']
        : ['x', 'y', 'w', 'h', 'opacity', 'rotation'];
    final width = document.spec.size.width.toDouble();
    final height = document.spec.size.height.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OiLabel.small('Essentials'),
        OiPropertyGrid(
          properties: [
            ...content,
            for (final field in fields.take(6 - content.length))
              OiPropertyRow(
                label: const {
                  'x': 'X',
                  'y': 'Y',
                  'w': 'Width',
                  'h': 'Height',
                  'opacity': 'Opacity',
                  'rotation': 'Angle',
                }[field]!,
                editor: MathNumberInput(
                  label: '',
                  value:
                      (transform[field] is num
                          ? (transform[field]! as num).toDouble()
                          : field == 'rotation'
                          ? 0
                          : const {'x', 'y'}.contains(field)
                          ? 0.5
                          : 1) *
                      (const {'x', 'w'}.contains(field)
                          ? width
                          : const {'y', 'h'}.contains(field)
                          ? height
                          : 1),
                  min: field == 'opacity'
                      ? 0
                      : const {'w', 'h'}.contains(field)
                      ? 1
                      : null,
                  max: field == 'opacity' ? 1 : null,
                  step: field == 'opacity' ? 0.05 : 1,
                  decimals: field == 'opacity' ? 2 : 1,
                  onChanged: (value) => onCommand(
                    SetTransformsCommand(
                      transforms: {
                        id: {
                          ...transform,
                          field:
                              value /
                              (const {'x', 'w'}.contains(field)
                                  ? width
                                  : const {'y', 'h'}.contains(field)
                                  ? height
                                  : 1),
                        },
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: OiLabel.small('Switch to Edit for animation, arrange and all properties.'),
        ),
      ],
    );
  }
}
