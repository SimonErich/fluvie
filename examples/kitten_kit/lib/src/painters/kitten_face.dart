import 'package:flutter/widgets.dart';
import 'package:kitten_kit/src/painters/kitten_face_painter.dart';
import 'package:kitten_kit/src/theme/kitten_colors.dart';

/// A square, deterministic kitten face widget, drawable in app chrome and inside
/// Fluvie scenes alike. Wraps [KittenFacePainter] at a fixed [size].
class KittenFace extends StatelessWidget {
  /// Creates a kitten face [size] pixels wide in [fur].
  const KittenFace({this.size = 160, this.fur = KittenColors.tabby, super.key});

  /// The edge length of the square face, in logical pixels.
  final double size;

  /// The fur color passed through to the painter.
  final Color fur;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: KittenFacePainter(fur: fur),
  );
}
