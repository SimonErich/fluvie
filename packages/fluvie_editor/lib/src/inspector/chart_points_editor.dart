import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/inspector/inspector_sections.dart';
import 'package:fluvie_editor/src/inspector/inspector_text_field.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

/// The rows editor over a `Chart`'s `points` form: x, y, and the optional
/// label per row (empty removes it), with add, remove (never below one),
/// and reorder. Integral coordinates write as `int`.
final class ChartPointsEditor extends StatelessWidget {
  /// Edits the `points` of [element]; every change lands in [patch].
  const ChartPointsEditor({required this.element, required this.patch, super.key});

  /// The chart element JSON.
  final Map<String, Object?> element;

  /// Applies a content patch to the element.
  final ElementPatch patch;

  List<Map<String, Object?>> get _points => [
    for (final point in element['points']! as List<Object?>) point! as Map<String, Object?>,
  ];

  @override
  Widget build(BuildContext context) {
    final points = _points;
    return Column(
      key: const ValueKey('chart-points-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < points.length; i++) _row(points, i),
        Row(
          children: [
            EditorTip(
              message: 'Add point',
              child: OiIconButton(
                icon: OiIcons.plus,
                semanticLabel: 'Add point',
                size: OiButtonSize.small,
                onTap: () => _write([
                  ...points,
                  {'x': points.length, 'y': 0},
                ]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(List<Map<String, Object?>> points, int index) {
    final point = points[index];
    return Padding(
      key: ValueKey('chart-point-$index'),
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 56, child: _numberField(points, index, 'x')),
          const SizedBox(width: 4),
          SizedBox(width: 56, child: _numberField(points, index, 'y')),
          const SizedBox(width: 4),
          Expanded(
            child: InspectorTextField(
              key: ValueKey('point-label-$index'),
              value: (point['label'] as String?) ?? '',
              onChanged: (next) => _replace(
                points,
                index,
                next.isEmpty ? ({...point}..remove('label')) : {...point, 'label': next},
              ),
            ),
          ),
          _tipButton(
            'Move up',
            OiIcons.arrowUp,
            'Move point $index up',
            index == 0 ? null : () => _swap(points, index, index - 1),
          ),
          _tipButton(
            'Move down',
            OiIcons.arrowDown,
            'Move point $index down',
            index == points.length - 1 ? null : () => _swap(points, index, index + 1),
          ),
          _tipButton(
            'Remove point',
            OiIcons.trash,
            'Remove point $index',
            points.length <= 1 ? null : () => _write([...points]..removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _numberField(List<Map<String, Object?>> points, int index, String key) {
    final point = points[index];
    return MathNumberInput(
      label: '',
      value: point[key] is num ? (point[key]! as num).toDouble() : 0,
      onChanged: (next) {
        final written = next == next.roundToDouble() ? next.round() : next;
        _replace(points, index, {...point, key: written}, mergeGroup: 'point-$key-$index');
      },
    );
  }

  Widget _tipButton(String message, IconData icon, String semanticLabel, VoidCallback? onTap) =>
      EditorTip(
        message: message,
        child: OiIconButton(
          icon: icon,
          semanticLabel: semanticLabel,
          size: OiButtonSize.small,
          onTap: onTap,
        ),
      );

  void _replace(
    List<Map<String, Object?>> points,
    int index,
    Map<String, Object?> point, {
    String? mergeGroup,
  }) => _write([...points]..[index] = point, mergeGroup: mergeGroup);

  void _swap(List<Map<String, Object?>> points, int a, int b) {
    final copy = [...points];
    copy[a] = points[b];
    copy[b] = points[a];
    _write(copy);
  }

  void _write(List<Map<String, Object?>> points, {String? mergeGroup}) =>
      patch({'points': points}, mergeGroup: mergeGroup);
}
