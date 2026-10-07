import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt;

/// The inspector's plain string field: commits on Enter or focus loss.
final class InspectorTextField extends StatefulWidget {
  /// Edits [value]; commits land in [onChanged]. A [maxLines] above one (or
  /// null for unbounded) makes the field multi-line — Enter then inserts a
  /// newline and only focus loss commits. The [placeholder] shows while the
  /// field is empty.
  const InspectorTextField({
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    this.onEdited,
    this.placeholder,
    super.key,
  });

  /// The current text.
  final String value;

  /// Receives the committed text.
  final ValueChanged<String> onChanged;

  /// Receives each local draft change without committing the value. Used by
  /// explicit Apply controls that must read text before focus leaves the field.
  final ValueChanged<String>? onEdited;

  /// The visible line count, or null to grow with the text. One (the
  /// default) keeps the classic single-line field.
  final int? maxLines;

  /// The hint shown while the field holds no text, or null for none.
  final String? placeholder;

  @override
  State<InspectorTextField> createState() => _InspectorTextFieldState();
}

final class _InspectorTextFieldState extends State<InspectorTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(InspectorTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    if (_controller.text != widget.value) widget.onChanged(_controller.text);
    // A refused commit (a colliding rename, an invalid time) must not
    // leave the field lying: once the frame settles — an accepted commit
    // has rebuilt this widget with the new value by then — snap the text
    // back to whatever the owner actually holds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focus.hasFocus) return;
      if (_controller.text != widget.value) _controller.text = widget.value;
    });
  }

  void _onFocus() {
    if (!_focus.hasFocus) _commit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Stack(
          children: [
            if (widget.placeholder case final String placeholder)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) => value.text.isEmpty
                    ? Text(
                        placeholder,
                        style: TextStyle(color: colors.textSubtle, fontSize: 12),
                      )
                    : const SizedBox.shrink(),
              ),
            EditableText(
              controller: _controller,
              focusNode: _focus,
              maxLines: widget.maxLines,
              style: TextStyle(color: colors.text, fontSize: 12),
              cursorColor: colors.accent.base,
              backgroundCursorColor: colors.accent.base,
              selectionColor: colors.accent.base.withValues(alpha: 0.35),
              onChanged: widget.onEdited,
              onEditingComplete: _commit,
            ),
          ],
        ),
      ),
    );
  }
}
