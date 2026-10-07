part of '../spectrum_slider.dart';

/// The horizontal hue rainbow.
final class HueSlider extends StatelessWidget {
  /// Edits [hsv]'s hue.
  const HueSlider({required this.hsv, required this.onChanged, super.key});

  /// The current color.
  final HSVColor hsv;

  /// Receives the re-hued color.
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) => SpectrumTrack(
    gradient: [
      for (var stop = 0; stop <= 6; stop++) HSVColor.fromAHSV(1, stop * 60.0, 1, 1).toColor(),
    ],
    position: hsv.hue / 360,
    thumbColor: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
    onChanged: (fraction) => onChanged(hsv.withHue(fraction * 360)),
  );
}
