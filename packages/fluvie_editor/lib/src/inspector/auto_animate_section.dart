import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/autoanimate/morph_preview.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:obers_ui/obers_ui.dart';

/// The inspector's per-slide auto-animate controls: the switch matching
/// this slide's elements to the previous slide, the live pair count, a
/// Rematch action for when elements changed, and the morph preview. Every
/// change dispatches one command, so every change is one undo step.
final class AutoAnimateSection extends StatelessWidget {
  /// Controls auto-animate on [slide]; commands land in [onCommand].
  const AutoAnimateSection({
    required this.document,
    required this.slide,
    required this.onCommand,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The slide the switch belongs to.
  final int slide;

  /// Receives the auto-animate commands.
  final void Function(EditorCommand command) onCommand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final on = document.autoAnimateOn(slide);
    final first = slide == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OiPropertyGrid(
          properties: [
            OiPropertyRow(
              label: 'Match previous slide',
              editor: OiSwitch(
                key: const ValueKey('auto-animate-switch'),
                value: on,
                enabled: !first,
                onChanged: first
                    ? null
                    : (next) => onCommand(ApplyAutoAnimateCommand(slide: slide, enabled: next)),
              ),
            ),
          ],
        ),
        if (first)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: OiLabel.small(
              'The first slide has nothing to morph from',
              color: colors.textSubtle,
            ),
          ),
        if (on) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: OiLabel.small(_pairSummary(), color: colors.textSubtle),
          ),
          Row(
            children: [
              OiButton.secondary(
                label: 'Preview morph',
                size: OiButtonSize.small,
                onTap: () => unawaited(showMorphPreview(context, document: document, slide: slide)),
              ),
              const SizedBox(width: 8),
              OiButton.ghost(
                label: 'Rematch',
                size: OiButtonSize.small,
                onTap: () => onCommand(ApplyAutoAnimateCommand(slide: slide, enabled: true)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _pairSummary() {
    final count = document.linkedPairCountOf(slide);
    return switch (count) {
      0 => 'No elements match the previous slide',
      1 => '1 element morphs from the previous slide',
      _ => '$count elements morph from the previous slide',
    };
  }
}
