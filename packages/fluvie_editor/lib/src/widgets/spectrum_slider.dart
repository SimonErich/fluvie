import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt;

// obers_ui upstream candidate: the spectrum picker's building blocks.

part 'spectrum/saturation_value_area.dart';
part 'spectrum/hue_slider.dart';
part 'spectrum/alpha_slider.dart';
part 'spectrum/spectrum_track.dart';
part 'spectrum/hex_color_field.dart';

/// The picker thumb: a small ring readable on any background.
final class _Thumb extends StatelessWidget {
  const _Thumb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 2)],
    ),
  );
}
