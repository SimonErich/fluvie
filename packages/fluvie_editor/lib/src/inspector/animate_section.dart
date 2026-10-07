import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show namedEases;
import 'package:fluvie_editor/src/document/anchor_triggers.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/inspector/animate_presets.dart';
import 'package:fluvie_editor/src/timeline/keyframe_stop_math.dart';
import 'package:fluvie_editor/src/timeline/slide_timeline_model.dart';
import 'package:fluvie_editor/src/timeline/timeline_link_palette.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_bar.dart';
import 'package:obers_ui/obers_ui.dart';

part 'animate_section_commands.dart';
part 'animate_section_triggers.dart';

/// The quick Animate panel: the selected element's animations by name and
/// phase color, each with its resolved duration, easing, simple trigger,
/// and a remove action, plus a phase-grouped add picker — two views of one
/// truth with the timeline, editing the same document commands.
final class AnimateSection extends StatelessWidget {
  /// Edits the `animate` list of [elementId] on slide [slide].
  const AnimateSection({
    required this.document,
    required this.slide,
    required this.elementId,
    required this.onCommand,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The slide holding the element (the introspection scope).
  final int slide;

  /// The element whose animations show.
  final String elementId;

  /// Receives every dispatched command.
  final void Function(EditorCommand command) onCommand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final model = SlideTimelineModel.build(
      document: document,
      slide: slide,
      palette: TimelinePhasePalette(
        enter: colors.success.base,
        during: colors.warning.base,
        exit: colors.error.base,
      ),
      linkPalette: TimelineLinkPalette(ends: colors.accent.base, starts: colors.info.base),
    );
    final animate = document.elementJson(elementId)?['animate'];
    final entries = animate is List ? animate : const <Object?>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++)
          _animation(context, model, i, (entries[i]! as Map).cast<String, Object?>()),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: OiSelect<String>(
            key: const ValueKey('animate-add'),
            options: animatePresetOptions(),
            placeholder: 'Add animation',
            searchable: true,
            onChanged: _add,
          ),
        ),
      ],
    );
  }

  Widget _animation(
    BuildContext context,
    SlideTimelineModel model,
    int index,
    Map<String, Object?> json,
  ) {
    final binding = model.bindings['$elementId:$index'];
    final bar = binding == null ? null : _barOf(model, '$elementId:$index');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (bar != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SizedBox.square(
                  dimension: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: bar.color, shape: BoxShape.circle),
                  ),
                ),
              ),
            Expanded(child: OiLabel.small(animationName(json), color: context.colors.text)),
            EditorTip(
              message: 'Remove animation',
              child: OiIconButton(
                icon: OiIcons.trash,
                semanticLabel: 'Remove animation',
                size: OiButtonSize.small,
                onTap: () => onCommand(RemoveAnimationCommand(id: elementId, index: index)),
              ),
            ),
          ],
        ),
        OiPropertyGrid(
          properties: [
            if (binding != null)
              OiPropertyRow(
                label: 'Length',
                editor: MathNumberInput(
                  label: '',
                  value: binding.durationFrames.toDouble(),
                  min: 1,
                  decimals: 0,
                  onChanged: (next) => _setDuration(binding, json, next),
                ),
              ),
            if (binding != null)
              OiPropertyRow(
                label: 'Offset',
                editor: MathNumberInput(
                  label: '',
                  value: binding.delayFrames.toDouble(),
                  min: 0,
                  decimals: 0,
                  onChanged: (next) => onCommand(
                    SetAnimationDelayCommand(
                      id: elementId,
                      index: index,
                      delayFrames: next.round(),
                    ),
                  ),
                ),
              ),
            OiPropertyRow(label: 'Ease', editor: _easeSelect(index, json)),
            OiPropertyRow(label: 'Start', editor: _triggerSelect(index, json)),
          ],
        ),
      ],
    );
  }

  Widget _easeSelect(int index, Map<String, Object?> json) {
    final ease = json['ease'];
    return OiSelect<String>(
      key: ValueKey('animate-ease-$index'),
      value: ease is String
          ? ease
          : ease is Map
          ? 'custom'
          : 'inherit',
      options: [
        const OiSelectOption(value: 'inherit', label: 'inherit'),
        if (ease is Map) const OiSelectOption(value: 'custom', label: 'Custom cubic'),
        for (final name in namedEases.keys) OiSelectOption(value: name, label: name),
      ],
      onChanged: (next) {
        if (next == null || next == 'custom') return;
        onCommand(
          SetAnimationEaseCommand(
            id: elementId,
            index: index,
            ease: next == 'inherit' ? null : next,
          ),
        );
      },
    );
  }

  void _setDuration(TimelineBarBinding binding, Map<String, Object?> json, double next) =>
      _dispatchDuration(binding, json, next);

  void _add(String? next) => _dispatchAdd(next);

  TimelineBar _barOf(SlideTimelineModel model, String barId) =>
      model.tracks.expand((track) => track.bars).firstWhere((bar) => bar.id == barId);
}
