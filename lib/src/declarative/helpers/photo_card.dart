import 'package:flutter/material.dart';
import '../../presentation/time_consumer.dart';
import 'ken_burns_image.dart';

/// A modern photo card widget with shadow, rounded corners, and optional effects.
///
/// This widget provides a clean, professional way to display photos with
/// optional Ken Burns effect, rotation, and shadow.
///
/// You can provide either a [child] widget (recommended) or an [assetPath]
/// string. The [child] parameter allows maximum flexibility, supporting
/// [Image.asset], [Image.network], SVGs, or any custom widget.
///
/// Example with child (recommended):
/// ```dart
/// PhotoCard(
///   child: Image.network('https://example.com/photo.jpg', fit: BoxFit.cover),
///   width: 400,
///   height: 300,
///   rotation: -0.05,
///   elevation: 20,
///   kenBurns: true,
/// )
/// ```
///
/// Example with assetPath (legacy):
/// ```dart
/// PhotoCard(
///   assetPath: 'assets/photo.jpg',
///   width: 400,
///   height: 300,
/// )
/// ```
class PhotoCard extends StatelessWidget {
  /// The child widget to display.
  ///
  /// If provided, [assetPath] must be null. This is the recommended approach
  /// as it supports any widget type including [Image.network], SVGs, etc.
  final Widget? child;

  /// Path to the image asset.
  ///
  /// Deprecated: Use [child] instead for more flexibility.
  @Deprecated('Use child parameter instead. '
      'Example: child: Image.asset("assets/photo.jpg", fit: BoxFit.cover)')
  final String? assetPath;

  /// Width of the card.
  final double width;

  /// Height of the card.
  final double height;

  /// Rotation in radians.
  final double rotation;

  /// Elevation/shadow depth.
  final double elevation;

  /// Border radius of the card.
  final double borderRadius;

  /// Whether to apply Ken Burns effect.
  final bool kenBurns;

  /// Ken Burns start scale.
  final double kenBurnsStartScale;

  /// Ken Burns end scale.
  final double kenBurnsEndScale;

  /// Ken Burns start alignment.
  final Alignment kenBurnsStartAlignment;

  /// Ken Burns end alignment.
  final Alignment kenBurnsEndAlignment;

  /// Optional border color.
  final Color? borderColor;

  /// Border width if [borderColor] is set.
  final double borderWidth;

  /// Background color for the card (visible if image fails to load).
  final Color backgroundColor;

  /// How the image should be fitted.
  final BoxFit fit;

  /// Optional caption text below the image.
  final String? caption;

  /// Style for the caption text.
  final TextStyle? captionStyle;

  /// Optional error builder for when image fails to load.
  ///
  /// Only applies when using [assetPath]. When using [child], handle
  /// errors in your widget directly (e.g., Image.network's errorBuilder).
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  /// Creates a photo card widget.
  ///
  /// Either [child] or [assetPath] must be provided, but not both.
  const PhotoCard({
    super.key,
    this.child,
    @Deprecated('Use child parameter instead. '
        'Example: child: Image.asset("assets/photo.jpg", fit: BoxFit.cover)')
    this.assetPath,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.elevation = 15,
    this.borderRadius = 12,
    this.kenBurns = false,
    this.kenBurnsStartScale = 1.0,
    this.kenBurnsEndScale = 1.15,
    this.kenBurnsStartAlignment = Alignment.center,
    this.kenBurnsEndAlignment = Alignment.center,
    this.borderColor,
    this.borderWidth = 3,
    this.backgroundColor = Colors.white,
    this.fit = BoxFit.cover,
    this.caption,
    this.captionStyle,
    this.errorBuilder,
  })  : assert(
          child != null || assetPath != null,
          'Either child or assetPath must be provided',
        ),
        assert(
          !(child != null && assetPath != null),
          'Cannot provide both child and assetPath',
        );

  /// Creates a photo card with Ken Burns zoom effect.
  ///
  /// Either [child] or [assetPath] must be provided, but not both.
  factory PhotoCard.withKenBurns({
    Key? key,
    Widget? child,
    @Deprecated('Use child parameter instead') String? assetPath,
    required double width,
    required double height,
    double rotation = 0,
    double elevation = 15,
    double borderRadius = 12,
    double zoomAmount = 0.15,
    Alignment focus = Alignment.center,
    Color? borderColor,
    double borderWidth = 3,
    String? caption,
    TextStyle? captionStyle,
  }) {
    return PhotoCard(
      key: key,
      child: child,
      assetPath: assetPath,
      width: width,
      height: height,
      rotation: rotation,
      elevation: elevation,
      borderRadius: borderRadius,
      kenBurns: true,
      kenBurnsStartScale: 1.0,
      kenBurnsEndScale: 1.0 + zoomAmount,
      kenBurnsStartAlignment: focus,
      kenBurnsEndAlignment: focus,
      borderColor: borderColor,
      borderWidth: borderWidth,
      caption: caption,
      captionStyle: captionStyle,
    );
  }

  /// Creates a photo card with Ken Burns pan effect.
  ///
  /// Either [child] or [assetPath] must be provided, but not both.
  factory PhotoCard.withPan({
    Key? key,
    Widget? child,
    @Deprecated('Use child parameter instead') String? assetPath,
    required double width,
    required double height,
    double rotation = 0,
    double elevation = 15,
    double borderRadius = 12,
    Alignment from = Alignment.centerLeft,
    Alignment to = Alignment.centerRight,
    double scale = 1.2,
    Color? borderColor,
    double borderWidth = 3,
    String? caption,
    TextStyle? captionStyle,
  }) {
    return PhotoCard(
      key: key,
      child: child,
      assetPath: assetPath,
      width: width,
      height: height,
      rotation: rotation,
      elevation: elevation,
      borderRadius: borderRadius,
      kenBurns: true,
      kenBurnsStartScale: scale,
      kenBurnsEndScale: scale,
      kenBurnsStartAlignment: from,
      kenBurnsEndAlignment: to,
      borderColor: borderColor,
      borderWidth: borderWidth,
      caption: caption,
      captionStyle: captionStyle,
    );
  }

  /// Creates a simple photo card without effects.
  ///
  /// Either [child] or [assetPath] must be provided, but not both.
  factory PhotoCard.simple({
    Key? key,
    Widget? child,
    @Deprecated('Use child parameter instead') String? assetPath,
    required double width,
    required double height,
    double borderRadius = 12,
    double elevation = 10,
    String? caption,
    TextStyle? captionStyle,
  }) {
    return PhotoCard(
      key: key,
      child: child,
      assetPath: assetPath,
      width: width,
      height: height,
      borderRadius: borderRadius,
      elevation: elevation,
      caption: caption,
      captionStyle: captionStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageHeight = caption != null ? height - 40 : height;

    Widget imageWidget;

    if (kenBurns) {
      imageWidget = KenBurnsImage(
        child: child,
        assetPath: assetPath,
        width: width,
        height: imageHeight,
        startScale: kenBurnsStartScale,
        endScale: kenBurnsEndScale,
        startAlignment: kenBurnsStartAlignment,
        endAlignment: kenBurnsEndAlignment,
        fit: fit,
        errorBuilder: errorBuilder,
      );
    } else if (child != null) {
      imageWidget = SizedBox(
        width: width,
        height: imageHeight,
        child: FittedBox(
          fit: fit,
          child: child,
        ),
      );
    } else {
      imageWidget = Image.asset(
        assetPath!,
        width: width,
        height: imageHeight,
        fit: fit,
        errorBuilder: errorBuilder ??
            (context, error, stack) => Container(
                  width: width,
                  height: imageHeight,
                  color: Colors.grey[300],
                  child:
                      Icon(Icons.image, size: width * 0.3, color: Colors.grey),
                ),
      );
    }

    Widget card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: elevation,
            offset: Offset(0, elevation * 0.4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(
                borderRadius - (borderColor != null ? borderWidth : 0),
              ),
              bottom: caption != null
                  ? Radius.zero
                  : Radius.circular(
                      borderRadius - (borderColor != null ? borderWidth : 0),
                    ),
            ),
            child: imageWidget,
          ),
          if (caption != null)
            Container(
              width: width,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                caption!,
                style: captionStyle ??
                    const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );

    if (rotation != 0) {
      card = Transform.rotate(angle: rotation, child: card);
    }

    return card;
  }
}

/// A photo card that animates in with optional entry effects.
///
/// You can provide either a [child] widget (recommended) or an [assetPath]
/// string. The [child] parameter allows maximum flexibility, supporting
/// [Image.asset], [Image.network], SVGs, or any custom widget.
///
/// Example:
/// ```dart
/// AnimatedPhotoCard(
///   child: Image.network('https://example.com/photo.jpg', fit: BoxFit.cover),
///   width: 400,
///   height: 300,
///   startFrame: 30,
///   animationDuration: 25,
///   slideFrom: SlideFromDirection.bottom,
/// )
/// ```
class AnimatedPhotoCard extends StatelessWidget {
  /// The child widget to display.
  ///
  /// If provided, [assetPath] must be null. This is the recommended approach
  /// as it supports any widget type including [Image.network], SVGs, etc.
  final Widget? child;

  /// Path to the image asset.
  ///
  /// Deprecated: Use [child] instead for more flexibility.
  @Deprecated('Use child parameter instead. '
      'Example: child: Image.asset("assets/photo.jpg", fit: BoxFit.cover)')
  final String? assetPath;

  /// Width of the card.
  final double width;

  /// Height of the card.
  final double height;

  /// Frame at which the animation starts.
  final int startFrame;

  /// Duration of the entry animation.
  final int animationDuration;

  /// Direction to slide from.
  final SlideFromDirection slideFrom;

  /// Distance to slide.
  final double slideDistance;

  /// Rotation of the card.
  final double rotation;

  /// Elevation/shadow depth.
  final double elevation;

  /// Border radius of the card.
  final double borderRadius;

  /// Whether to apply Ken Burns effect.
  final bool kenBurns;

  /// Easing curve for the animation.
  final Curve curve;

  /// Optional caption.
  final String? caption;

  /// Creates an animated photo card.
  ///
  /// Either [child] or [assetPath] must be provided, but not both.
  const AnimatedPhotoCard({
    super.key,
    this.child,
    @Deprecated('Use child parameter instead. '
        'Example: child: Image.asset("assets/photo.jpg", fit: BoxFit.cover)')
    this.assetPath,
    required this.width,
    required this.height,
    this.startFrame = 0,
    this.animationDuration = 30,
    this.slideFrom = SlideFromDirection.bottom,
    this.slideDistance = 80,
    this.rotation = 0,
    this.elevation = 15,
    this.borderRadius = 12,
    this.kenBurns = true,
    this.curve = Curves.easeOutCubic,
    this.caption,
  })  : assert(
          child != null || assetPath != null,
          'Either child or assetPath must be provided',
        ),
        assert(
          !(child != null && assetPath != null),
          'Cannot provide both child and assetPath',
        );

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final animFrame = frame - startFrame;
        double progress;

        if (animFrame < 0) {
          progress = 0;
        } else if (animFrame >= animationDuration) {
          progress = 1;
        } else {
          progress = animFrame / animationDuration;
        }

        final curvedProgress = curve.transform(progress);

        // Calculate offset based on direction
        Offset offset;
        final remainingDistance = slideDistance * (1 - curvedProgress);

        switch (slideFrom) {
          case SlideFromDirection.left:
            offset = Offset(-remainingDistance, 0);
            break;
          case SlideFromDirection.right:
            offset = Offset(remainingDistance, 0);
            break;
          case SlideFromDirection.top:
            offset = Offset(0, -remainingDistance);
            break;
          case SlideFromDirection.bottom:
            offset = Offset(0, remainingDistance);
            break;
        }

        final opacity = curvedProgress;
        final scale = 0.9 + (0.1 * curvedProgress);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: scale,
              child: PhotoCard(
                child: child,
                assetPath: assetPath,
                width: width,
                height: height,
                rotation: rotation,
                elevation: elevation,
                borderRadius: borderRadius,
                kenBurns: kenBurns,
                caption: caption,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Direction from which an element slides in.
enum SlideFromDirection { left, right, top, bottom }
