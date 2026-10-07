import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt;

/// The canvas's in-place text field: mounted over a text element's rect,
/// it commits on Enter or focus loss and cancels on Escape.
///
/// Built on the bare [EditableText] (no Material), styled to sit over the
/// element it edits.
final class InlineTextEditor extends StatefulWidget {
  /// Edits [initialText] in [style], reporting the result to [onCommit]
  /// (or [onCancel] for Escape).
  const InlineTextEditor({
    required this.initialText,
    required this.style,
    required this.onCommit,
    required this.onCancel,
    super.key,
  });

  /// The element's current text.
  final String initialText;

  /// The element's text style, pre-scaled to viewport pixels.
  final TextStyle style;

  /// Receives the edited text on Enter or focus loss.
  final void Function(String text) onCommit;

  /// Called when Escape abandons the edit.
  final VoidCallback onCancel;

  @override
  State<InlineTextEditor> createState() => _InlineTextEditorState();
}

final class _InlineTextEditorState extends State<InlineTextEditor> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);
  final FocusNode _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    if (_done) return;
    _done = true;
    widget.onCommit(_controller.text);
  }

  void _cancel() {
    if (_done) return;
    _done = true;
    widget.onCancel();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent.base;
    return MediaQuery.fromView(
      view: View.of(context),
      child: Focus(
        onKeyEvent: _onKey,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: accent)),
          child: EditableText(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            style: widget.style,
            cursorColor: accent,
            backgroundCursorColor: accent,
            selectionColor: accent.withValues(alpha: 0.35),
            onEditingComplete: _commit,
          ),
        ),
      ),
    );
  }
}
