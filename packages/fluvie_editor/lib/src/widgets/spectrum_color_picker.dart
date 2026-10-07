import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/widgets/named_color.dart';
import 'package:fluvie_editor/src/widgets/spectrum_slider.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt, OiLabel;

// obers_ui upstream candidate: a full spectrum color picker (SV area, hue
// and alpha sliders, hex field, palette presets) — OiColorInput has
// presets, hex, and alpha, but no spectrum area.

/// A spectrum color picker: named theme swatches first, recent picks
/// second, then the saturation/value area, hue and alpha sliders, and a
/// hex field.
final class SpectrumColorPicker extends StatelessWidget {
  /// Edits [color]; every change lands in [onChanged]. [tokens] leads the
  /// picker (tapping one calls [onTokenSelected]), [recents] follows, and
  /// [palette] seeds plain preset swatches.
  const SpectrumColorPicker({
    required this.color,
    required this.onChanged,
    this.palette = const [],
    this.tokens = const [],
    this.onTokenSelected,
    this.recents = const [],
    super.key,
  });

  /// The current color.
  final Color color;

  /// Receives every picked color.
  final ValueChanged<Color> onChanged;

  /// Plain preset swatches (shown with the recents).
  final List<Color> palette;

  /// The theme's named swatches, leading the picker.
  final List<NamedColor> tokens;

  /// Hears the name of a tapped theme swatch; null paints the row inert.
  final ValueChanged<String>? onTokenSelected;

  /// The session's recent picks, between the theme row and the spectrum.
  final List<Color> recents;

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(color);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tokens.isNotEmpty) ...[
          _row(context, 'Theme', [
            for (final token in tokens)
              _Swatch(
                label: 'Token ${token.name}',
                color: token.color,
                onTap: () => onTokenSelected?.call(token.name),
              ),
          ]),
          const SizedBox(height: 8),
        ],
        if (recents.isNotEmpty) ...[
          _row(context, 'Recent', [
            for (final (i, recent) in recents.indexed)
              _Swatch(
                label: 'Recent color ${i + 1}',
                color: recent,
                onTap: () => onChanged(recent),
              ),
          ]),
          const SizedBox(height: 8),
        ],
        if (palette.isNotEmpty) ...[
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final preset in palette)
                _Swatch(label: 'Preset', color: preset, onTap: () => onChanged(preset)),
            ],
          ),
          const SizedBox(height: 8),
        ],
        SaturationValueArea(hsv: hsv, onChanged: (next) => onChanged(next.toColor())),
        const SizedBox(height: 8),
        HueSlider(hsv: hsv, onChanged: (next) => onChanged(next.toColor())),
        const SizedBox(height: 8),
        AlphaSlider(hsv: hsv, onChanged: (next) => onChanged(next.toColor())),
        const SizedBox(height: 8),
        HexColorField(color: color, onChanged: onChanged),
      ],
    );
  }

  Widget _row(BuildContext context, String label, List<Widget> swatches) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      OiLabel.small(label, color: context.colors.textSubtle),
      const SizedBox(height: 4),
      Wrap(spacing: 4, runSpacing: 4, children: swatches),
    ],
  );
}

/// One tappable swatch square.
final class _Swatch extends StatelessWidget {
  const _Swatch({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: context.colors.borderSubtle),
        ),
      ),
    ),
  );
}
