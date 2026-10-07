part of '../spectrum_slider.dart';

/// The horizontal alpha ramp.
final class AlphaSlider extends StatelessWidget {
  /// Edits [hsv]'s alpha.
  const AlphaSlider({required this.hsv, required this.onChanged, super.key});

  /// The current color.
  final HSVColor hsv;

  /// Receives the re-alphaed color.
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) => SpectrumTrack(
    gradient: [hsv.toColor().withValues(alpha: 0), hsv.toColor().withValues(alpha: 1)],
    position: hsv.alpha,
    thumbColor: hsv.toColor(),
    onChanged: (fraction) => onChanged(hsv.withAlpha(fraction)),
  );
}
