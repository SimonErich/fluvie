import 'package:flutter/material.dart';
import '../../presentation/time_consumer.dart';

/// A widget that applies the Ken Burns effect to an image.
///
/// The Ken Burns effect is a slow zoom and pan that creates cinematic
/// movement on still images, commonly used in documentaries.
///
/// Example:
/// ```dart
/// KenBurnsImage(
///   assetPath: 'assets/photo.jpg',
///   width: 800,
///   height: 600,
///   startScale: 1.0,
///   endScale: 1.3,
///   startAlignment: Alignment.centerLeft,
///   endAlignment: Alignment.centerRight,
/// )
/// ```
class KenBurnsImage extends StatelessWidget {
  /// Path to the image asset.
  final String assetPath;

  /// Width of the image container.
  final double width;

  /// Height of the image container.
  final double height;

  /// Starting scale of the image.
  final double startScale;

  /// Ending scale of the image.
  final double endScale;

  /// Starting alignment/focus point.
  final Alignment startAlignment;

  /// Ending alignment/focus point.
  final Alignment endAlignment;

  /// How the image should be fitted.
  final BoxFit fit;

  /// Border radius for the image.
  final BorderRadius? borderRadius;

  /// Easing curve for the animation.
  final Curve curve;

  /// Optional error builder for when image fails to load.
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  /// Creates a Ken Burns image widget.
  const KenBurnsImage({
    super.key,
    required this.assetPath,
    required this.width,
    required this.height,
    this.startScale = 1.0,
    this.endScale = 1.2,
    this.startAlignment = Alignment.center,
    this.endAlignment = Alignment.center,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.curve = Curves.linear,
    this.errorBuilder,
  });

  /// Creates a Ken Burns image with a zoom-in effect.
  factory KenBurnsImage.zoomIn({
    Key? key,
    required String assetPath,
    required double width,
    required double height,
    double zoomAmount = 0.2,
    Alignment focus = Alignment.center,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Curve curve = Curves.linear,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    return KenBurnsImage(
      key: key,
      assetPath: assetPath,
      width: width,
      height: height,
      startScale: 1.0,
      endScale: 1.0 + zoomAmount,
      startAlignment: focus,
      endAlignment: focus,
      fit: fit,
      borderRadius: borderRadius,
      curve: curve,
      errorBuilder: errorBuilder,
    );
  }

  /// Creates a Ken Burns image with a pan effect (no zoom).
  factory KenBurnsImage.pan({
    Key? key,
    required String assetPath,
    required double width,
    required double height,
    required Alignment from,
    required Alignment to,
    double scale = 1.2,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Curve curve = Curves.linear,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    return KenBurnsImage(
      key: key,
      assetPath: assetPath,
      width: width,
      height: height,
      startScale: scale,
      endScale: scale,
      startAlignment: from,
      endAlignment: to,
      fit: fit,
      borderRadius: borderRadius,
      curve: curve,
      errorBuilder: errorBuilder,
    );
  }

  /// Creates a Ken Burns image with zoom and pan.
  factory KenBurnsImage.zoomAndPan({
    Key? key,
    required String assetPath,
    required double width,
    required double height,
    double startScale = 1.0,
    double endScale = 1.3,
    Alignment from = Alignment.centerLeft,
    Alignment to = Alignment.centerRight,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Curve curve = Curves.linear,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    return KenBurnsImage(
      key: key,
      assetPath: assetPath,
      width: width,
      height: height,
      startScale: startScale,
      endScale: endScale,
      startAlignment: from,
      endAlignment: to,
      fit: fit,
      borderRadius: borderRadius,
      curve: curve,
      errorBuilder: errorBuilder,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = TimeConsumer(
      builder: (context, frame, progress) {
        final curvedProgress = curve.transform(progress);

        // Interpolate scale
        final scale = startScale + (endScale - startScale) * curvedProgress;

        // Interpolate alignment
        final alignX =
            startAlignment.x +
            (endAlignment.x - startAlignment.x) * curvedProgress;
        final alignY =
            startAlignment.y +
            (endAlignment.y - startAlignment.y) * curvedProgress;
        final alignment = Alignment(alignX, alignY);

        return ClipRect(
          child: OverflowBox(
            maxWidth: width * scale,
            maxHeight: height * scale,
            alignment: alignment,
            child: SizedBox(
              width: width * scale,
              height: height * scale,
              child: Image.asset(
                assetPath,
                width: width * scale,
                height: height * scale,
                fit: fit,
                errorBuilder:
                    errorBuilder ??
                    (context, error, stack) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
              ),
            ),
          ),
        );
      },
    );

    if (borderRadius != null) {
      content = ClipRRect(borderRadius: borderRadius!, child: content);
    }

    return SizedBox(width: width, height: height, child: content);
  }
}
