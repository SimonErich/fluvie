part of '../spectrum_slider.dart';

/// The hex field: `#RRGGBB` or `#AARRGGBB`, committed on Enter.
final class HexColorField extends StatefulWidget {
  /// Edits [color] as hex text.
  const HexColorField({required this.color, required this.onChanged, super.key});

  /// The current color.
  final Color color;

  /// Receives the parsed color.
  final ValueChanged<Color> onChanged;

  @override
  State<HexColorField> createState() => _HexColorFieldState();
}

final class _HexColorFieldState extends State<HexColorField> {
  late final TextEditingController _controller = TextEditingController(text: _hex(widget.color));
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(HexColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && oldWidget.color != widget.color) {
      _controller.text = _hex(widget.color);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  static String _hex(Color color) {
    final argb = color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return argb.startsWith('FF') ? '#${argb.substring(2)}' : '#$argb';
  }

  void _commit() {
    var digits = _controller.text.trim();
    if (digits.startsWith('#')) digits = digits.substring(1);
    if (digits.length == 6) digits = 'FF$digits';
    final value = int.tryParse(digits, radix: 16);
    if (value == null || digits.length != 8) {
      _controller.text = _hex(widget.color);
      return;
    }
    widget.onChanged(Color(value));
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
        child: EditableText(
          controller: _controller,
          focusNode: _focus,
          style: TextStyle(color: colors.text, fontSize: 12),
          cursorColor: colors.accent.base,
          backgroundCursorColor: colors.accent.base,
          selectionColor: colors.accent.base.withValues(alpha: 0.35),
          onEditingComplete: _commit,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
          ],
        ),
      ),
    );
  }
}
