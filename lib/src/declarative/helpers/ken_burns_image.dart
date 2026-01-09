import 'package:flutter/material.dart';
import '../../presentation/time_consumer.dart';

/// A widget that applies the Ken Burns effect to an image or any widget.
///
/// The Ken Burns effect is a slow zoom and pan that creates cinematic
/// movement on still images, commonly used in documentaries.
///
/// You can provide either a [child] widget (recommended) or an [assetPath]
/// string. The [child] parameter allows maximum flexibility, supporting
/// [Image.asset], [Image.network], SVGs, or any custom widget.
///
/// Example with child (recommended):
/// ```dart
/// KenBurnsImage(
///   child: Image.network('https://example.com/photo.jpg', fit: BoxFit.cover),
///   width: 800,
///   height: 600,
///   startScale: 1.0,
///   endScale: 1.3,
///   startAlignment: Alignment.centerLeft,
///   endAlignment: Alignment.centerRight,
/// )
/// ```
///
/// Example with assetPath (legacy):
/// ```dart
/// KenBurnsImage(
///   assetPath: 'assets/photo.jpg',
///   width: 800,
///   height: 600,
/// )
/// ```
class KenBurnsImage extends StatelessWidget {
  /// The child widget to apply the Ken Burns effect to.
  ///
  /// If provided, [assetPath] must be null. This is the recommended approach
  /// as it supports any widget type including [Image.network], SVGs, etc.
  final Widget? child;

  /// Path to the image asset.
  ///
  /// Deprecated: Use [child] instead for more flexibility.
  /// Example: `child: Image.asset('assets/photo.jpg', fit: BoxFit.cover)`
  @Deprecated('Use child parameter instead. '
      'Example: child: Image.asset("assets/photo.jpg", fit: BoxFit.cover)')
  final String? assetPath;

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
  ///
  /// Only applies when using [assetPath]. When using [child], handle
  /// errors in your widget directly (e.g., Image.network's errorBuilder).
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  /// Creates a Ken Burns image widget.
  ///
  /// Either [child] or [assetPath] must be provided, but not both.
  const KenBurnsImage({
    super.key,
    this.child,
    @Deprecated('Use child parameter instead. '
        'Example: child: Image.asset("assets/photo.jpg", fit: BoxFit.cover)')
    this.assetPath,
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
  })  : assert(
          child != null || assetPath != null,
          'Either child or assetPath must be provided',
        ),
        assert(
          !(child != null && assetPath != null),
          'Cannot provide both child and assetPath',
        );

  /// Creates a Ken Burns image with a zoom-in effect.
  ///
  /// Either [child] or [assetPath] must be provided, but not both.
  factory KenBurnsImage.zoomIn({
    Key? key,
    Widget? child,
    @Deprecated('Use child parameter instead') String? assetPath,
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
      child: child,
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
  ///
  /// Either [child] or [assetPath] must be provided, but not both.
  factory KenBurnsImage.pan({
    Key? key,
    Widget? child,
    @Deprecated('Use child parameter instead') String? assetPath,
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
      child: child,
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
  ///
  /// Either [child] or [assetPath] must be provided, but not both.
  factory KenBurnsImage.zoomAndPan({
    Key? key,
    Widget? child,
    @Deprecated('Use child parameter instead') String? assetPath,
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
      child: child,
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
        final alignX = startAlignment.x +
            (endAlignment.x - startAlignment.x) * curvedProgress;
        final alignY = startAlignment.y +
            (endAlignment.y - startAlignment.y) * curvedProgress;
        final alignment = Alignment(alignX, alignY);

        // Build the media widget
        Widget mediaWidget;
        if (child != null) {
          // Use provided child widget wrapped in FittedBox for proper scaling
          mediaWidget = SizedBox(
            width: width * scale,
            height: height * scale,
            child: FittedBox(
              fit: fit,
              child: SizedBox(
                width: width,
                height: height,
                child: child,
              ),
            ),
          );
        } else {
          // Use asset path (legacy)
          mediaWidget = Image.asset(
            assetPath!,
            width: width * scale,
            height: height * scale,
            fit: fit,
            errorBuilder: errorBuilder ??
                (context, error, stack) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
          );
        }

        return ClipRect(
          child: OverflowBox(
            maxWidth: width * scale,
            maxHeight: height * scale,
            alignment: alignment,
            child: mediaWidget,
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
