import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show EffectParam, EffectSpec;
import 'package:fluvie_editor/src/colour/tone_curve_editor.dart';
import 'package:fluvie_editor/src/colour/white_balance_wheel.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/effects/effect_object_editor.dart';
import 'package:fluvie_editor/src/effects/effect_stopwatch.dart';
import 'package:fluvie_editor/src/effects/effect_text_editor.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

part 'effects_section_fields.dart';

/// The selected element's effect stack: one tile per effect in stack order,
/// reorderable by drag, each with its enabled switch, its remove action,
/// and a row per parameter — numbers as [MathNumberInput], every numeric
/// row with the diamond that keyframes it or collapses it back.
final class EffectsSection extends StatelessWidget {
  /// Edits the `effects` list of [elementId].
  const EffectsSection({
    required this.document,
    required this.elementId,
    required this.onCommand,
    this.playheadProgress,
    this.kinds,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// Optional kind filter for the dedicated Colour workspace.
  final Set<String>? kinds;

  /// The element whose stack shows.
  final String elementId;

  /// Receives every dispatched command.
  final void Function(EditorCommand command) onCommand;

  /// Where the playhead sits inside the element's window (0..1), or null
  /// when no transport is mounted — the diamond then collapses to the
  /// ramp's first value instead of the value under the playhead.
  final double? Function(String elementId)? playheadProgress;

  @override
  Widget build(BuildContext context) {
    final effects = document.elementJson(elementId)?['effects'];
    final entries = effects is List ? effects : const <Object?>[];
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: OiLabel.body('No effects yet.', color: context.colors.textSubtle),
      );
    }
    return OiReorderable(
      shrinkWrap: true,
      onReorder: (from, to) =>
          onCommand(ReorderEffectCommand(id: elementId, from: from, to: to > from ? to - 1 : to)),
      children: [
        for (var i = 0; i < entries.length; i++)
          if (kinds == null || kinds!.contains((entries[i]! as Map)['kind']))
            _tile(context, i, (entries[i]! as Map).cast<String, Object?>()),
      ],
    );
  }

  Widget _tile(BuildContext context, int index, Map<String, Object?> json) {
    final spec = EffectSpec.fromJson(json);
    return Column(
      key: ValueKey('effect-tile-$index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: OiLabel.small(spec.kind.name, color: context.colors.text)),
            OiSwitch(
              key: ValueKey('effect-enabled-$index'),
              value: spec.enabled,
              onChanged: (next) =>
                  onCommand(SetEffectEnabledCommand(id: elementId, index: index, enabled: next)),
            ),
            EditorTip(
              message: 'Remove effect',
              child: OiIconButton(
                icon: OiIcons.trash,
                semanticLabel: 'Remove ${spec.kind.name}',
                size: OiButtonSize.small,
                onTap: () => onCommand(RemoveEffectCommand(id: elementId, index: index)),
              ),
            ),
          ],
        ),
        if (spec.kind.name == 'grade' &&
            !spec.isKeyframed('temperature') &&
            !spec.isKeyframed('tint'))
          WhiteBalanceWheel(
            temperature: spec.number('temperature'),
            tint: spec.number('tint'),
            onChanged: (temperature, tint) => onCommand(
              SetEffectParamsCommand(
                id: elementId,
                index: index,
                params: {'temperature': temperature, 'tint': tint},
              ),
            ),
          ),
        OiPropertyGrid(
          properties: [
            for (final param in spec.kind.params) _numberRow(index, spec, param),
            for (final flag in spec.kind.flags) _flagRow(index, spec, flag),
            for (final entry in spec.kind.enums.entries) _enumRow(index, spec, entry),
            for (final text in spec.kind.strings)
              if (text != 'cube') _textRow(index, spec, text),
          ],
        ),
        for (final name in spec.kind.objects)
          if (name == 'curves')
            ToneCurveEditor(
              curves: spec.object(name) ?? const {},
              onChanged: (value) => onCommand(
                SetEffectParamCommand(id: elementId, index: index, param: name, value: value),
              ),
            )
          else
            EffectObjectEditor(
              spec: spec,
              name: name,
              onChanged: (value) => onCommand(
                SetEffectParamCommand(id: elementId, index: index, param: name, value: value),
              ),
            ),
      ],
    );
  }
}
