import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/widgets/field_math.dart';
import 'package:fluvie_editor/src/widgets/numeric_unit.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt;

// obers_ui upstream candidate: a numeric field with typing, math
// expressions, arrow stepping, and label scrubbing — the inspector's
// workhorse input.

/// A numeric inspector field: type a number or a `960/2`-style expression,
/// step with the arrow keys (Shift steps by ten), or scrub by dragging the
/// label horizontally.
final class MathNumberInput extends StatefulWidget {
  /// Shows [value] under [label]; every change lands in [onChanged],
  /// clamped to [min]..[max]. [step] is one arrow press or one scrub pixel.
  const MathNumberInput({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
    this.step = 1,
    this.decimals = 1,
    this.format,
    super.key,
  });

  /// The short field name, also the scrub handle.
  final String label;

  /// The current value.
  final double value;

  /// Receives every committed or scrubbed value.
  final ValueChanged<double> onChanged;

  /// The smallest allowed value, or null for unbounded.
  final double? min;

  /// The largest allowed value, or null for unbounded.
  final double? max;

  /// One arrow press or one scrub pixel.
  final double step;

  /// Fraction digits shown (trailing zeros trimmed).
  final int decimals;

  /// How the value is written and read, or null for a bare number.
  ///
  /// The value stays in the field's own domain either way — a frames field
  /// holds frames whether it shows `120f` or `00:00:04:00` — so a unit changes
  /// only what the author sees and types, never what the document receives.
  final NumericFormat? format;

  @override
  State<MathNumberInput> createState() => _MathNumberInputState();
}

final class _MathNumberInputState extends State<MathNumberInput> {
  late final TextEditingController _controller = TextEditingController(text: _format(widget.value));
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(MathNumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && oldWidget.value != widget.value) {
      _controller.text = _format(widget.value);
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

  String _format(double value) {
    final unit = widget.format;
    if (unit != null) return unit.format(value);
    final text = value.toStringAsFixed(widget.decimals);
    return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
  }

  /// What the typed [text] means, or null when it means nothing.
  ///
  /// A unit-bearing field reads through its unit, so `2s` and `00:00:02:00`
  /// both land as frames. A **relative** expression is checked first, because
  /// the unit would happily read `+30` as the plain number 30 and the author's
  /// nudge would become a jump. The grammar's own rule decides which is which:
  /// a leading `+`, `*` or `/` applies to the current value, while a leading
  /// `-` is an absolute negative, since negatives are legal positions.
  double? _read(String text) {
    final unit = widget.format;
    final trimmed = text.trim();
    final relative = trimmed.startsWith('+') || trimmed.startsWith('*') || trimmed.startsWith('/');
    if (unit != null && !relative) {
      final parsed = unit.parse(text);
      if (parsed != null) return parsed;
    }
    return evalFieldMath(text, current: widget.value);
  }

  double _clamped(double value) {
    var result = value;
    final min = widget.min;
    final max = widget.max;
    if (min != null && result < min) result = min;
    if (max != null && result > max) result = max;
    return result;
  }

  void _commitText() {
    final evaluated = _read(_controller.text);
    final next = evaluated == null ? widget.value : _clamped(evaluated);
    _controller.text = _format(next);
    if (next != widget.value) widget.onChanged(next);
  }

  void _onFocus() {
    if (!_focus.hasFocus) _commitText();
  }

  void _stepBy(double direction) {
    final next = _clamped(widget.value + direction);
    _controller.text = _format(next);
    if (next != widget.value) widget.onChanged(next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final factor = shift ? 10 : 1;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _stepBy(widget.step * factor);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _stepBy(-widget.step * factor);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => _stepBy(details.delta.dx * widget.step),
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: SizedBox(
              width: 24,
              child: Text(
                widget.label,
                style: TextStyle(color: colors.textSubtle, fontSize: 11),
              ),
            ),
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Focus(
                onKeyEvent: _onKey,
                child: EditableText(
                  controller: _controller,
                  focusNode: _focus,
                  style: TextStyle(color: colors.text, fontSize: 12),
                  cursorColor: colors.accent.base,
                  backgroundCursorColor: colors.accent.base,
                  selectionColor: colors.accent.base.withValues(alpha: 0.35),
                  onEditingComplete: _commitText,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
