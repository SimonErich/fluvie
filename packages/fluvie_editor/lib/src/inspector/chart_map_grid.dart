import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/inspector/inspector_text_field.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

/// The label-and-value grid over one category-to-value map — the `Chart`
/// `data` form, and each series' own map. One row per entry with add,
/// remove (never below one), and reorder; a rename to an empty or
/// colliding label drops; integral values write as `int`.
final class ChartMapGrid extends StatelessWidget {
  /// Edits [data]; every rewritten map lands in [onChanged].
  const ChartMapGrid({required this.data, required this.onChanged, super.key});

  /// The category-to-value map being edited.
  final Map<String, Object?> data;

  /// Receives the rewritten map (a spinner stream coalesces per row
  /// through `mergeGroup`).
  final void Function(Map<String, Object?> data, {String? mergeGroup}) onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++) _row(entries, i),
        Row(
          children: [
            EditorTip(
              message: 'Add row',
              child: OiIconButton(
                icon: OiIcons.plus,
                semanticLabel: 'Add data row',
                size: OiButtonSize.small,
                onTap: () => _write([...entries, MapEntry(_freshLabel(data), 0)]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(List<MapEntry<String, Object?>> entries, int index) {
    final entry = entries[index];
    return Padding(
      key: ValueKey('chart-row-${entry.key}'),
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: InspectorTextField(
              value: entry.key,
              onChanged: (next) => _rename(entries, index, next),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 72,
            child: MathNumberInput(
              label: '',
              value: entry.value is num ? (entry.value! as num).toDouble() : 0,
              onChanged: (next) => _setValue(entries, index, next),
            ),
          ),
          _tipButton(
            'Move up',
            OiIcons.arrowUp,
            'Move row $index up',
            index == 0 ? null : () => _swap(entries, index, index - 1),
          ),
          _tipButton(
            'Move down',
            OiIcons.arrowDown,
            'Move row $index down',
            index == entries.length - 1 ? null : () => _swap(entries, index, index + 1),
          ),
          _tipButton(
            'Remove row',
            OiIcons.trash,
            'Remove row $index',
            entries.length <= 1 ? null : () => _write([...entries]..removeAt(index)),
          ),
        ],
      ),
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

  void _write(List<MapEntry<String, Object?>> entries, {String? mergeGroup}) => onChanged({
    for (final entry in entries) entry.key: entry.value,
  }, mergeGroup: mergeGroup);

  /// A rename keeps the row's position; an empty or colliding label drops.
  void _rename(List<MapEntry<String, Object?>> entries, int index, String next) {
    if (next.isEmpty || entries.any((entry) => entry.key == next)) return;
    _write([...entries]..[index] = MapEntry(next, entries[index].value));
  }

  /// Integral values write as `int` so the JSON stays as authored.
  void _setValue(List<MapEntry<String, Object?>> entries, int index, double next) {
    final written = next == next.roundToDouble() ? next.round() : next;
    _write(
      [...entries]..[index] = MapEntry(entries[index].key, written),
      mergeGroup: 'chart-data-$index',
    );
  }

  void _swap(List<MapEntry<String, Object?>> entries, int a, int b) {
    final copy = [...entries];
    copy[a] = entries[b];
    copy[b] = entries[a];
    _write(copy);
  }

  /// The first unused single letter, then `Item N` when all 26 are taken.
  String _freshLabel(Map<String, Object?> data) {
    for (var i = 0; i < 26; i++) {
      final label = String.fromCharCode(65 + i);
      if (!data.containsKey(label)) return label;
    }
    var n = data.length + 1;
    while (data.containsKey('Item $n')) {
      n++;
    }
    return 'Item $n';
  }
}
