part of '../spectrum_slider.dart';

/// A horizontal gradient track with a draggable thumb reporting `0..1`.
final class SpectrumTrack extends StatelessWidget {
  /// A track painted with [gradient], its thumb at [position].
  const SpectrumTrack({
    required this.gradient,
    required this.position,
    required this.thumbColor,
    required this.onChanged,
    super.key,
  });

  /// The gradient stops, left to right.
  final List<Color> gradient;

  /// The thumb position, `0..1`.
  final double position;

  /// The thumb fill.
  final Color thumbColor;

  /// Receives the tapped or dragged fraction.
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 14,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.biggest.width;
        void pick(Offset local) => onChanged((local.dx / width).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => pick(details.localPosition),
          onPanUpdate: (details) => pick(details.localPosition),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
              Align(
                alignment: Alignment(position * 2 - 1, 0),
                child: _Thumb(color: thumbColor),
              ),
            ],
          ),
        );
      },
    ),
  );
}
