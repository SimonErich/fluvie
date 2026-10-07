import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/widgets/gradient_editor/gradient_editor_math.dart';
import 'package:fluvie_editor/src/widgets/gradient_editor/gradient_editor_value.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

part 'gradient_editor_bar.dart';

// obers_ui upstream candidate: a gradient fill editor — a stops bar with
// draggable stops, a linear angle, and a radial toggle. No color-design
// system of its own: the host injects its picker per stop.

/// Edits a [GradientEditorValue]: a stops bar (tap to add, drag to move,
/// drag off to remove — never below two), the linear angle in degrees, a
/// linear/radial toggle, and the selected stop's color through
/// [stopColorEditor].
final class GradientEditor extends StatefulWidget {
  /// Edits [value]; every committed change lands in [onChanged] once (a
  /// handle drag commits on release).
  const GradientEditor({
    required this.value,
    required this.onChanged,
    this.stopColorEditor,
    this.showKind = true,
    super.key,
  });

  /// The gradient being edited.
  final GradientEditorValue value;

  /// Receives each committed change.
  final ValueChanged<GradientEditorValue> onChanged;

  /// Builds the color editor for the selected stop — the host injects its
  /// own picker (and owns that write path), keeping this widget free of
  /// any picker vocabulary. Null shows no color row.
  final Widget Function(BuildContext context, int index, GradientEditorStop stop)? stopColorEditor;

  /// Whether the linear/radial select shows.
  final bool showKind;

  @override
  State<GradientEditor> createState() => _GradientEditorState();
}

final class _GradientEditorState extends State<GradientEditor> {
  int _selected = 0;
  GradientEditorValue? _live;

  GradientEditorValue get _shown => _live ?? widget.value;

  @override
  void didUpdateWidget(GradientEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _live = null;
      _selected = _selected.clamp(0, widget.value.stops.length - 1);
    }
  }

  void _addAt(double fraction) {
    final (value: added, :index) = gradientStopAdded(widget.value, fraction);
    setState(() => _selected = index);
    widget.onChanged(added);
  }

  void _preview(GradientEditorValue value) => setState(() => _live = value);

  void _commit(GradientEditorValue? value) {
    setState(() => _live = null);
    if (value != null && value != widget.value) widget.onChanged(value);
  }

  void _setAngle(double degrees) =>
      widget.onChanged(widget.value.copyWith(angle: (degrees % 360 + 360) % 360));

  @override
  Widget build(BuildContext context) {
    final value = _shown;
    final selected = _selected.clamp(0, value.stops.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _GradientStopsBar(
          value: value,
          selected: selected,
          onSelect: (index) => setState(() => _selected = index),
          onAdd: _addAt,
          onPreview: _preview,
          onCommit: _commit,
        ),
        OiPropertyGrid(
          properties: [
            if (widget.showKind)
              OiPropertyRow(
                label: 'Kind',
                editor: OiSelect<GradientEditorKind>(
                  value: value.kind,
                  options: [
                    for (final kind in GradientEditorKind.values)
                      OiSelectOption(value: kind, label: kind.name),
                  ],
                  onChanged: (next) {
                    if (next != null) widget.onChanged(widget.value.copyWith(kind: next));
                  },
                ),
              ),
            if (value.kind == GradientEditorKind.linear)
              OiPropertyRow(
                label: 'Angle',
                editor: MathNumberInput(
                  label: '',
                  value: widget.value.angle,
                  decimals: 0,
                  onChanged: _setAngle,
                ),
              ),
            if (widget.stopColorEditor != null)
              OiPropertyRow(
                label: 'Stop',
                editor: widget.stopColorEditor!(context, selected, value.stops[selected]),
              ),
          ],
        ),
      ],
    );
  }
}
