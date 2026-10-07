import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show decodeColor, encodeColor, namedAlignments, namedEases;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/selection/keyframe_selection.dart';
import 'package:fluvie_editor/src/widgets/color_field.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

/// One numeric keyframe field: the codec key, its row label, its natural
/// identity (what an unset field means), and its bounds.
typedef _NumField = ({String key, String label, double natural, double? min, double? max});

/// The full numeric field set of the keyframe codec, in display order.
const List<_NumField> _numFields = [
  (key: 'opacity', label: 'Opacity', natural: 1, min: 0, max: 1),
  (key: 'x', label: 'X', natural: 0, min: null, max: null),
  (key: 'y', label: 'Y', natural: 0, min: null, max: null),
  (key: 'scale', label: 'Scale', natural: 1, min: null, max: null),
  (key: 'scaleX', label: 'ScaleX', natural: 1, min: null, max: null),
  (key: 'scaleY', label: 'ScaleY', natural: 1, min: null, max: null),
  (key: 'rotation', label: 'Rotation', natural: 0, min: null, max: null),
  (key: 'skewX', label: 'SkewX', natural: 0, min: null, max: null),
  (key: 'skewY', label: 'SkewY', natural: 0, min: null, max: null),
  (key: 'blur', label: 'Blur', natural: 0, min: 0, max: null),
];

/// The Keyframe section: the selected diamond's stop, every codec field as
/// an editable value (unset fields show their natural identity), the stop
/// color and transform origin, and the OUTGOING segment's easing.
///
/// A stale selection (the animation or stop no longer exists, or the
/// animation is not the keyframes form) renders nothing.
final class KeyframeSection extends StatelessWidget {
  /// Edits the stop [selection] points at inside [document].
  const KeyframeSection({
    required this.document,
    required this.selection,
    required this.onCommand,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The selected keyframe stop.
  final SelectedKeyframe selection;

  /// Receives every dispatched command.
  final void Function(EditorCommand command) onCommand;

  @override
  Widget build(BuildContext context) {
    final animate = document.elementJson(selection.elementId)?['animate'];
    if (animate is! List || selection.animation >= animate.length) {
      return const SizedBox.shrink();
    }
    final animation = (animate[selection.animation]! as Map).cast<String, Object?>();
    final stops = animation['keyframes'];
    if (stops is! List || selection.stop >= stops.length) return const SizedBox.shrink();
    final stop = (stops[selection.stop]! as Map).cast<String, Object?>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: OiLabel.small('Keyframe', color: context.colors.textSubtle),
        ),
        OiPropertyGrid(
          properties: [
            for (final field in _numFields)
              OiPropertyRow(
                label: field.label,
                editor: MathNumberInput(
                  label: '',
                  value: stop[field.key] is num
                      ? (stop[field.key]! as num).toDouble()
                      : field.natural,
                  min: field.min,
                  max: field.max,
                  decimals: 2,
                  onChanged: (next) => _write(stop, field.key, next),
                ),
              ),
            OiPropertyRow(
              label: 'Color',
              editor: ColorField(
                label: 'Keyframe color',
                color: stop['color'] == null
                    ? const Color(0xFFFFFFFF)
                    : decodeColor(stop['color'], path: const ['color']),
                onChanged: (next) => _write(stop, 'color', encodeColor(next)),
              ),
            ),
            OiPropertyRow(label: 'Origin', editor: _originSelect(stop)),
            if (selection.stop < stops.length - 1)
              OiPropertyRow(label: 'Easing', editor: _easingSelect(animation)),
          ],
        ),
      ],
    );
  }

  /// Writes one field onto the stop — never more — so an edit touches only
  /// what the author changed; per-field merge groups coalesce a run of
  /// commits on the same field into one undo step.
  void _write(Map<String, Object?> stop, String field, Object? value) => onCommand(
    SetKeyframeStopCommand(
      id: selection.elementId,
      index: selection.animation,
      stop: selection.stop,
      keyframe: {...stop, field: value},
      mergeGroup: 'kf-$field',
    ),
  );

  Widget _originSelect(Map<String, Object?> stop) {
    final origin = stop['origin'];
    return OiSelect<String>(
      key: const ValueKey('kf-origin'),
      value: origin is String ? origin : 'center',
      options: [
        for (final name in namedAlignments.keys) OiSelectOption(value: name, label: name),
      ],
      onChanged: (next) {
        if (next != null) _write(stop, 'origin', next);
      },
    );
  }

  Widget _easingSelect(Map<String, Object?> animation) {
    final easings = animation['easings'];
    final current = easings is List && selection.stop < easings.length
        ? easings[selection.stop]
        : null;
    return OiSelect<String>(
      key: const ValueKey('kf-easing'),
      value: current is String
          ? current
          : current is Map
          ? 'custom'
          : 'linear',
      options: [
        if (current is Map) const OiSelectOption(value: 'custom', label: 'Custom cubic'),
        for (final name in namedEases.keys) OiSelectOption(value: name, label: name),
      ],
      onChanged: (next) {
        if (next == null || next == 'custom') return;
        onCommand(
          SetKeyframeEasingCommand(
            id: selection.elementId,
            index: selection.animation,
            segment: selection.stop,
            easing: next,
          ),
        );
      },
    );
  }
}
