part of '../spectrum_slider.dart';

/// The saturation/value square: white-to-hue across, transparent-to-black
/// down, with a thumb on the current color.
final class SaturationValueArea extends StatelessWidget {
  /// Edits [hsv]'s saturation and value.
  const SaturationValueArea({required this.hsv, required this.onChanged, super.key});

  /// The current color.
  final HSVColor hsv;

  /// Receives the color under the pointer.
  final ValueChanged<HSVColor> onChanged;

  void _pick(Offset local, Size size) {
    final saturation = (local.dx / size.width).clamp(0.0, 1.0);
    final value = 1 - (local.dy / size.height).clamp(0.0, 1.0);
    onChanged(hsv.withSaturation(saturation).withValue(value));
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _pick(details.localPosition, size),
          onPanUpdate: (details) => _pick(details.localPosition, size),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFFFFF),
                        HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                      ],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xFF000000)],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment(hsv.saturation * 2 - 1, (1 - hsv.value) * 2 - 1),
                  child: _Thumb(color: hsv.toColor()),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
