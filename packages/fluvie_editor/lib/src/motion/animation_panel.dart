import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show EffectSpec;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/inspector/animate_section.dart';
import 'package:fluvie_editor/src/selection/selection_controller.dart';
import 'package:fluvie_editor/src/widgets/easing_curve_editor.dart';
import 'package:obers_ui/obers_ui.dart';

/// Animation presets and editable easing curves, including effect segments.
final class AnimationPanel extends ConsumerWidget {
  /// Edits the selected element through the shared command/history model.
  const AnimationPanel({required this.document, required this.onCommand, super.key});

  /// The open document.
  final EditorDocument document;

  /// Dispatches one command for each finished curve gesture.
  final ValueChanged<EditorCommand> onCommand;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectionProvider);
    if (selected.length != 1 || document.elementJson(selected.single) == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: OiLabel.body('Select one element to edit motion.'),
      );
    }
    final id = selected.single;
    final element = document.elementJson(selected.single)!;
    final animations = element['animate'] as List? ?? const [];
    final effects = element['effects'] as List? ?? const [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OiLabel.body('Animation'),
          AnimateSection(
            document: document,
            slide: document.sceneOfElement(id) ?? 0,
            elementId: id,
            onCommand: onCommand,
          ),
          for (var i = 0; i < animations.length; i++) ...[
            OiLabel.body('Animation ${i + 1} easing'),
            EasingCurveEditor(
              value: (animations[i] as Map)['ease'] ?? 'smooth',
              onChanged: (value) =>
                  onCommand(SetAnimationEaseCommand(id: id, index: i, ease: value)),
            ),
            if ((animations[i] as Map)['keyframes'] case final List<Object?> stops)
              for (var segment = 0; segment < stops.length - 1; segment++) ...[
                OiLabel.small('Segment ${segment + 1}'),
                EasingCurveEditor(
                  value: _segmentEase((animations[i] as Map)['easings'], segment),
                  onChanged: (value) => onCommand(
                    SetKeyframeEasingCommand(id: id, index: i, segment: segment, easing: value),
                  ),
                ),
              ],
          ],
          for (var i = 0; i < effects.length; i++)
            ..._effectCurves(id, i, (effects[i] as Map).cast<String, Object?>()),
        ],
      ),
    );
  }

  Object _segmentEase(Object? easings, int segment) =>
      easings is List && segment < easings.length ? easings[segment]! as Object : 'linear';
  List<Widget> _effectCurves(String id, int index, Map<String, Object?> json) {
    final spec = EffectSpec.fromJson(json);
    return [
      for (final param in spec.kind.params)
        if (spec.keyframed(param.name) case final ramp?)
          for (var segment = 0; segment < ramp.values.length - 1; segment++) ...[
            OiLabel.small('${spec.kind.name} · ${param.name} · segment ${segment + 1}'),
            EasingCurveEditor(
              value: _segmentEase(ramp.toJson()['easings'], segment),
              onChanged: (value) {
                final map = ramp.toJson();
                final raw = map['easings'];
                final easings = raw is List
                    ? [...raw]
                    : List<Object?>.filled(ramp.values.length - 1, 'linear');
                easings[segment] = value;
                onCommand(
                  SetEffectParamCommand(
                    id: id,
                    index: index,
                    param: param.name,
                    value: {...map, 'easings': easings},
                  ),
                );
              },
            ),
          ],
    ];
  }
}
