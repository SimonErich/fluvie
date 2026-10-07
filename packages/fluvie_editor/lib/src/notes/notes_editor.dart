import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/inspector/inspector_text_field.dart';
import 'package:fluvie_editor/src/notes/notes_merge.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:obers_ui/obers_ui.dart';

part 'notes_editor_add_field.dart';
part 'notes_editor_fields.dart';
part 'notes_editor_scopes.dart';

/// The collapsible speaker-notes strip under the timeline: the current
/// slide's notes — prose plus highlight bullets — edited per slide, and per
/// build step when the slide has steps, through the command layer.
///
/// The scope chips mirror the timeline's build markers: they derive from the
/// same `steps` list, so a marker edit and a notes scope never disagree. A
/// step's notes follow the presenter's merge rule (its text replaces the
/// slide text while the step is active, its highlights append), and the
/// preview line under the fields shows exactly what the speaker window will
/// show for the selected scope — the same merge `compileNotes` performs,
/// mirrored locally so editing never rebuilds a deck.
final class NotesEditor extends StatefulWidget {
  /// Edits the notes of slide [slide] in [document].
  const NotesEditor({
    required this.document,
    required this.slide,
    required this.onCommand,
    this.height = 180,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The slide whose notes show.
  final int slide;

  /// Receives the editor's notes commands.
  final void Function(EditorCommand command) onCommand;

  /// The open strip's body height (the header rides on top of it).
  final double height;

  @override
  State<NotesEditor> createState() => _NotesEditorState();
}

final class _NotesEditorState extends State<NotesEditor> {
  // A secondary strip: it starts closed so the timeline keeps the room.
  bool _open = false;

  // 0 is the slide scope; k edits listed step k - 1's override.
  int _scope = 0;

  @override
  void didUpdateWidget(NotesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slide != oldWidget.slide) _scope = 0;
  }

  /// [setState] for the extension parts (the member is protected).
  void _refresh(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scene = widget.document.sceneJson(widget.slide);
    final steps = _stepsOf(scene);
    // A scope the document no longer has (an undo took the step) falls
    // back to the slide scope.
    final scope = _scope > steps.length ? 0 : _scope;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(context),
          if (_open) SizedBox(height: widget.height, child: _body(context, scene, steps, scope)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    child: Row(
      children: [
        OiLabel.small('Notes', color: context.colors.text),
        const Spacer(),
        EditorTip(
          message: _open ? 'Collapse the notes editor' : 'Show the notes editor',
          child: OiIconButton(
            icon: _open ? OiIcons.panelBottomClose : OiIcons.panelBottom,
            semanticLabel: _open ? 'Collapse the notes editor' : 'Show the notes editor',
            size: OiButtonSize.small,
            onTap: () => _refresh(() => _open = !_open),
          ),
        ),
      ],
    ),
  );
}
