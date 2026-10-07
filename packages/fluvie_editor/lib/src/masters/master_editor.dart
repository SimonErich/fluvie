import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/canvas/editor_canvas.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/masters/master_edit_session.dart';
import 'package:obers_ui/obers_ui.dart';

/// Master-edit mode's stage: the same [EditorCanvas], pointed at the
/// session's synthetic view — placeholders render as labeled outline boxes,
/// chrome edits like any element — with a header naming the master and the
/// way back. Every command translates through the session onto the real
/// document, so each edit is one undoable step and every adopting slide
/// re-derives at once.
final class MasterEditor extends StatelessWidget {
  /// Edits [session]'s master; translated commands land in [onCommand],
  /// Done calls [onClose].
  const MasterEditor({
    required this.session,
    required this.onCommand,
    required this.onClose,
    super.key,
  });

  /// The master-edit lens over the real document.
  final MasterEditSession session;

  /// Receives the translated [SetMasterCommand]s (the owner dispatches
  /// them into its history).
  final void Function(EditorCommand command) onCommand;

  /// Leaves master-edit mode.
  final VoidCallback onClose;

  void _dispatch(EditorCommand command) {
    final translated = session.translate(command);
    if (translated != null) onCommand(translated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: colors.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: OiLabel.small(
                    'Editing master "${session.name}" — every adopting slide follows',
                    color: colors.textSubtle,
                  ),
                ),
                OiButton.secondary(label: 'Done', onTap: onClose),
              ],
            ),
          ),
        ),
        Expanded(
          child: EditorCanvas(
            document: session.view,
            slide: 0,
            interactive: true,
            onCommand: _dispatch,
          ),
        ),
      ],
    );
  }
}
