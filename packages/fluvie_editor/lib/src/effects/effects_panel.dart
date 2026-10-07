import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/effects/effect_browser.dart';
import 'package:fluvie_editor/src/effects/effects_section.dart';
import 'package:fluvie_editor/src/selection/selection_controller.dart';
import 'package:obers_ui/obers_ui.dart';

/// The Effects tab: the selected element's stack over the add browser.
///
/// One element at a time on purpose — a stack edited "somewhere" is a stack
/// the author cannot predict. Multi-selection points at the paste verb,
/// which is how a look lands on many elements at once.
final class EffectsPanel extends ConsumerWidget {
  /// Shows and edits the selected element's effects on [document].
  const EffectsPanel({
    required this.document,
    required this.onCommand,
    this.playheadProgress,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// Receives every dispatched command.
  final void Function(EditorCommand command) onCommand;

  /// Where the playhead sits inside an element's window (0..1), or null
  /// when the host mounts no transport.
  final double? Function(String elementId)? playheadProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectionProvider);
    final colors = context.colors;
    final Widget body;
    if (selected.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(12),
        child: OiLabel.body('Select an element to stack effects on it.', color: colors.textSubtle),
      );
    } else if (selected.length > 1) {
      body = Padding(
        padding: const EdgeInsets.all(12),
        child: OiLabel.body(
          '${selected.length} elements selected. Effects edit one element at '
          'a time; use Paste Effects to land a copied look on all of them.',
          color: colors.textSubtle,
        ),
      );
    } else if (document.elementJson(selected.single) == null) {
      body = Padding(
        padding: const EdgeInsets.all(12),
        child: OiLabel.body('Nothing here anymore.', color: colors.textSubtle),
      );
    } else {
      final id = selected.single;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          EffectsSection(
            document: document,
            elementId: id,
            onCommand: onCommand,
            playheadProgress: playheadProgress,
          ),
          const SizedBox(height: 12),
          EffectBrowser(
            onAdd: (effect) => onCommand(AddEffectCommand(id: id, effect: effect)),
          ),
        ],
      );
    }
    return ColoredBox(
      color: colors.surface,
      child: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(8), child: body),
      ),
    );
  }
}
