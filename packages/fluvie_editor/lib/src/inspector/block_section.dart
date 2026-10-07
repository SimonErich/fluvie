import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/blocks/block_spec.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

/// The inspector's Block section for a selected group: the kind picker
/// (with "none" clearing the block and keeping the geometry) and the
/// current kind's parameters. Every edit dispatches one command; number
/// commits coalesce per field.
final class BlockSection extends StatelessWidget {
  /// Edits the block of group [id]; commands land in [onCommand].
  const BlockSection({
    required this.document,
    required this.id,
    required this.onCommand,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The selected group.
  final String id;

  /// Receives the block commands.
  final void Function(EditorCommand command) onCommand;

  void _pickKind(BlockSpec? block, String? next) {
    if (next == null) return;
    if (next == 'none') {
      if (block != null) onCommand(ClearBlockCommand(ids: [id]));
      return;
    }
    final kind = BlockKind.values.firstWhere((candidate) => candidate.name == next);
    onCommand(SetBlockParamsCommand(groupId: id, block: BlockSpec.defaults(kind)));
  }

  void _setParam(BlockSpec block, String key, Object? value, {bool merge = false}) => onCommand(
    SetBlockParamsCommand(
      groupId: id,
      block: BlockSpec.fromJson({...block.toJson(), key: value})!,
      mergeGroup: merge ? key : null,
    ),
  );

  OiPropertyRow _number(
    BlockSpec block,
    String label,
    String key,
    double value, {
    double min = 0,
    double max = 0.5,
    int decimals = 2,
    double step = 0.01,
  }) => OiPropertyRow(
    label: label,
    editor: MathNumberInput(
      key: ValueKey('block-$key'),
      label: '',
      value: value,
      min: min,
      max: max,
      step: step,
      decimals: decimals,
      onChanged: (next) => _setParam(block, key, next, merge: true),
    ),
  );

  OiPropertyRow _select(
    BlockSpec block,
    String label,
    String key,
    String value,
    List<String> options,
  ) => OiPropertyRow(
    label: label,
    editor: OiSelect<String>(
      key: ValueKey('block-$key'),
      value: value,
      options: [for (final option in options) OiSelectOption(value: option, label: option)],
      onChanged: (next) => _setParam(block, key, next),
    ),
  );

  List<OiPropertyRow> _paramRows(BlockSpec block) => switch (block.kind) {
    BlockKind.row || BlockKind.column => [
      _number(block, 'Spacing', 'spacing', block.spacing),
      _select(block, 'Main', 'mainAlign', block.mainAlign.name, [
        for (final align in BlockMainAlign.values) align.name,
      ]),
      _select(block, 'Cross', 'crossAlign', block.crossAlign.name, [
        for (final align in BlockCrossAlign.values) align.name,
      ]),
      OiPropertyRow(
        label: 'Equal size',
        editor: OiSwitch(
          key: const ValueKey('block-equalSize'),
          value: block.equalSize,
          onChanged: (next) => _setParam(block, 'equalSize', next),
        ),
      ),
    ],
    BlockKind.grid => [
      _number(
        block,
        'Columns',
        'columns',
        block.columns.toDouble(),
        min: 1,
        max: 12,
        decimals: 0,
        step: 1,
      ),
      _number(block, 'Spacing', 'spacing', block.spacing),
    ],
    BlockKind.list => [
      _number(block, 'Row height', 'itemHeight', block.itemHeight, min: 0.01, max: 1),
      _number(block, 'Spacing', 'spacing', block.spacing),
    ],
    BlockKind.split => [
      _number(block, 'Ratio', 'ratio', block.ratio, min: 0.05, max: 0.95),
      _number(block, 'Gutter', 'gutter', block.gutter),
    ],
    BlockKind.titleBody => [
      _number(block, 'Title share', 'heightFraction', block.heightFraction, min: 0.05, max: 0.95),
      _number(block, 'Spacing', 'spacing', block.spacing),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final block = document.blockOf(id);
    return OiPropertyGrid(
      properties: [
        OiPropertyRow(
          label: 'Kind',
          editor: OiSelect<String>(
            key: const ValueKey('block-kind'),
            value: block?.kind.name ?? 'none',
            options: [
              const OiSelectOption(value: 'none', label: 'none'),
              for (final kind in BlockKind.values)
                OiSelectOption(value: kind.name, label: kind.label),
            ],
            onChanged: (next) => _pickKind(block, next),
          ),
        ),
        if (block != null) ..._paramRows(block),
      ],
    );
  }
}
