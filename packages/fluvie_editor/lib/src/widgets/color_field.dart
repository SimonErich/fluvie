import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:fluvie_editor/src/widgets/named_color.dart';
import 'package:fluvie_editor/src/widgets/spectrum_color_picker.dart';
import 'package:obers_ui/obers_ui.dart';

// obers_ui upstream candidate: a labeled color swatch that opens the
// spectrum picker, theme-swatch binding included.

/// A compact color row: the current color as a swatch — or, when bound to
/// a named token, a chip with the token's name and a one-click unbind.
/// Tapping either opens the spectrum picker in a dialog, which leads with
/// the [tokens], then [recents], then the full spectrum.
final class ColorField extends StatelessWidget {
  /// Shows [color] under [label]; picks land in [onChanged].
  const ColorField({
    required this.label,
    required this.color,
    required this.onChanged,
    this.palette = const [],
    this.tokens = const [],
    this.boundToken,
    this.onTokenSelected,
    this.recents = const [],
    this.onCommitted,
    super.key,
  });

  /// The dialog title and semantic label.
  final String label;

  /// The current color (the token's resolved color when bound).
  final Color color;

  /// Receives every picked literal color.
  final ValueChanged<Color> onChanged;

  /// Plain preset swatches forwarded to the picker.
  final List<Color> palette;

  /// The theme's named swatches, leading the picker; tapping one binds.
  final List<NamedColor> tokens;

  /// The token this field is bound to, or null for a literal color.
  final String? boundToken;

  /// Hears a theme-swatch tap (the bind); the dialog closes with it.
  final ValueChanged<String>? onTokenSelected;

  /// The session's recent picks, forwarded to the picker.
  final List<Color> recents;

  /// Hears the final color once when the dialog closes after at least one
  /// literal pick — the recents recorder.
  final ValueChanged<Color>? onCommitted;

  Future<void> _open(BuildContext context) async {
    Color? picked;
    await OiDialogShell.show<void>(
      context: context,
      semanticLabel: label,
      maxWidth: 280,
      minWidth: 240,
      builder: (close) => OiDialog.standard(
        label: label,
        title: label,
        content: _LivePicker(
          initial: color,
          palette: palette,
          tokens: tokens,
          recents: recents,
          onChanged: (next) {
            picked = next;
            onChanged(next);
          },
          onToken: onTokenSelected == null
              ? null
              : (name) {
                  picked = null;
                  onTokenSelected!(name);
                  close(null);
                },
        ),
        onClose: () => close(null),
      ),
    );
    if (picked != null) onCommitted?.call(picked!);
  }

  @override
  Widget build(BuildContext context) {
    final bound = boundToken;
    return GestureDetector(
      onTap: () => _open(context),
      child: Semantics(
        container: true,
        label: label,
        button: true,
        child: bound == null
            ? _swatch(context, height: 22)
            : Row(
                children: [
                  _swatch(context, height: 16, width: 16),
                  const SizedBox(width: 6),
                  Expanded(child: OiLabel.small(bound, color: context.colors.text)),
                  EditorTip(
                    message: 'Use the literal color',
                    child: OiIconButton(
                      icon: OiIcons.x,
                      semanticLabel: 'Unbind $label',
                      size: OiButtonSize.small,
                      onTap: () => onChanged(color),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _swatch(BuildContext context, {required double height, double? width}) => Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: context.colors.borderSubtle),
    ),
  );
}

/// The picker inside the dialog, holding the live color so drags preview
/// without waiting for the document round-trip.
final class _LivePicker extends StatefulWidget {
  const _LivePicker({
    required this.initial,
    required this.palette,
    required this.tokens,
    required this.recents,
    required this.onChanged,
    required this.onToken,
  });

  final Color initial;
  final List<Color> palette;
  final List<NamedColor> tokens;
  final List<Color> recents;
  final ValueChanged<Color> onChanged;
  final ValueChanged<String>? onToken;

  @override
  State<_LivePicker> createState() => _LivePickerState();
}

final class _LivePickerState extends State<_LivePicker> {
  late Color _color = widget.initial;

  @override
  Widget build(BuildContext context) => SpectrumColorPicker(
    color: _color,
    palette: widget.palette,
    tokens: widget.tokens,
    onTokenSelected: widget.onToken,
    recents: widget.recents,
    onChanged: (next) {
      setState(() => _color = next);
      widget.onChanged(next);
    },
  );
}
