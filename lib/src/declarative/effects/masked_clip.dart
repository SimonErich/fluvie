import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../../presentation/time_consumer.dart';

/// Shape for masking.
enum MaskShape {
  /// Circle mask.
  circle,

  /// Rectangle mask with optional border radius.
  rectangle,

  /// Star shape mask.
  star,

  /// Heart shape mask.
  heart,

  /// Custom path mask.
  custom,
}

/// A widget that clips its child to a shape with optional animation.
///
/// [MaskedClip] provides various shape masks and supports animating
/// the mask boundary for reveal effects.
///
/// Example:
/// ```dart
/// MaskedClip.circle(
///   radius: 200,
///   child: Image.asset('photo.jpg'),
/// )
/// ```
///
/// With animation:
/// ```dart
/// MaskedClip.circle(
///   radius: 200,
///   animation: MaskAnimation.reveal(duration: 30),
///   child: Image.asset('photo.jpg'),
/// )
/// ```
class MaskedClip extends StatelessWidget {
  /// The child widget to mask.
  final Widget child;

  /// The shape of the mask.
  final MaskShape shape;

  /// Radius for circle mask.
  final double? radius;

  /// Border radius for rectangle mask.
  final BorderRadius? borderRadius;

  /// Number of points for star mask.
  final int starPoints;

  /// Custom path for custom shape mask.
  final Path? customPath;

  /// Animation for the mask boundary.
  final MaskAnimation? animation;

  /// Alignment of the mask center.
  final Alignment alignment;

  /// The frame at which the animation starts.
  final int startFrame;

  /// Creates a masked clip widget.
  const MaskedClip({
    super.key,
    required this.child,
    required this.shape,
    this.radius,
    this.borderRadius,
    this.starPoints = 5,
    this.customPath,
    this.animation,
    this.alignment = Alignment.center,
    this.startFrame = 0,
  });

  /// Creates a circle mask.
  const MaskedClip.circle({
    super.key,
    required this.child,
    this.radius,
    this.animation,
    this.alignment = Alignment.center,
    this.startFrame = 0,
  }) : shape = MaskShape.circle,
       borderRadius = null,
       starPoints = 5,
       customPath = null;

  /// Creates a rectangle mask.
  const MaskedClip.rectangle({
    super.key,
    required this.child,
    this.borderRadius,
    this.animation,
    this.alignment = Alignment.center,
    this.startFrame = 0,
  }) : shape = MaskShape.rectangle,
       radius = null,
       starPoints = 5,
       customPath = null;

  /// Creates a star mask.
  const MaskedClip.star({
    super.key,
    required this.child,
    this.starPoints = 5,
    this.radius,
    this.animation,
    this.alignment = Alignment.center,
    this.startFrame = 0,
  }) : shape = MaskShape.star,
       borderRadius = null,
       customPath = null;

  /// Creates a heart mask.
  const MaskedClip.heart({
    super.key,
    required this.child,
    this.radius,
    this.animation,
    this.alignment = Alignment.center,
    this.startFrame = 0,
  }) : shape = MaskShape.heart,
       borderRadius = null,
       starPoints = 5,
       customPath = null;

  /// Creates a custom path mask.
  const MaskedClip.path({
    super.key,
    required this.child,
    required Path path,
    this.animation,
    this.alignment = Alignment.center,
    this.startFrame = 0,
  }) : shape = MaskShape.custom,
       customPath = path,
       radius = null,
       borderRadius = null,
       starPoints = 5;

  @override
  Widget build(BuildContext context) {
    if (animation == null) {
      return _buildClip(1.0);
    }

    return TimeConsumer(
      builder: (context, frame, _) {
        final relativeFrame = frame - startFrame;
        final progress = animation!.progressAt(relativeFrame);
        return _buildClip(progress);
      },
    );
  }

  Widget _buildClip(double progress) {
    return ClipPath(
      clipper: _MaskClipper(
        shape: shape,
        radius: radius,
        borderRadius: borderRadius,
        starPoints: starPoints,
        customPath: customPath,
        alignment: alignment,
        progress: progress,
      ),
      child: child,
    );
  }
}

class _MaskClipper extends CustomClipper<Path> {
  final MaskShape shape;
  final double? radius;
  final BorderRadius? borderRadius;
  final int starPoints;
  final Path? customPath;
  final Alignment alignment;
  final double progress;

  _MaskClipper({
    required this.shape,
    required this.radius,
    required this.borderRadius,
    required this.starPoints,
    required this.customPath,
    required this.alignment,
    required this.progress,
  });

  @override
  Path getClip(Size size) {
    final center = alignment.alongSize(size);
    final effectiveRadius = radius ?? math.min(size.width, size.height) / 2;
    final scaledRadius = effectiveRadius * progress;

    switch (shape) {
      case MaskShape.circle:
        return Path()
          ..addOval(Rect.fromCircle(center: center, radius: scaledRadius));

      case MaskShape.rectangle:
        final scaledSize = Size(size.width * progress, size.height * progress);
        final rect = Rect.fromCenter(
          center: center,
          width: scaledSize.width,
          height: scaledSize.height,
        );
        if (borderRadius != null) {
          return Path()..addRRect(borderRadius!.toRRect(rect));
        }
        return Path()..addRect(rect);

      case MaskShape.star:
        return _createStarPath(center, scaledRadius, starPoints);

      case MaskShape.heart:
        return _createHeartPath(center, scaledRadius);

      case MaskShape.custom:
        if (customPath != null) {
          // Scale the custom path using manual matrix composition
          final bounds = customPath!.getBounds();
          final scaleX = (size.width * progress) / bounds.width;
          final scaleY = (size.height * progress) / bounds.height;
          // Create transform: translate to center, scale, translate back
          final matrix = Matrix4.identity();
          matrix.setEntry(0, 3, center.dx - bounds.center.dx * scaleX);
          matrix.setEntry(1, 3, center.dy - bounds.center.dy * scaleY);
          matrix.setEntry(0, 0, scaleX);
          matrix.setEntry(1, 1, scaleY);
          return customPath!.transform(matrix.storage);
        }
        return Path()..addRect(Offset.zero & size);
    }
  }

  Path _createStarPath(Offset center, double radius, int points) {
    final path = Path();
    final innerRadius = radius * 0.4;

    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final r = i.isEven ? radius : innerRadius;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    return path;
  }

  Path _createHeartPath(Offset center, double radius) {
    final path = Path();
    final width = radius * 2;
    final height = radius * 1.8;

    // Heart shape using bezier curves
    path.moveTo(center.dx, center.dy + height * 0.35);

    // Left side
    path.cubicTo(
      center.dx - width * 0.5,
      center.dy + height * 0.1,
      center.dx - width * 0.5,
      center.dy - height * 0.35,
      center.dx,
      center.dy - height * 0.15,
    );

    // Right side
    path.cubicTo(
      center.dx + width * 0.5,
      center.dy - height * 0.35,
      center.dx + width * 0.5,
      center.dy + height * 0.1,
      center.dx,
      center.dy + height * 0.35,
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _MaskClipper oldClipper) {
    return oldClipper.progress != progress ||
        oldClipper.shape != shape ||
        oldClipper.radius != radius;
  }
}

/// Animation configuration for mask transitions.
class MaskAnimation {
  /// The type of animation.
  final MaskAnimationType type;

  /// Duration of the animation in frames.
  final int duration;

  /// Easing curve for the animation.
  final Curve curve;

  const MaskAnimation._({
    required this.type,
    required this.duration,
    this.curve = Curves.easeOut,
  });

  /// Creates a reveal animation (expands from center).
  const MaskAnimation.reveal({int duration = 30, Curve curve = Curves.easeOut})
    : this._(type: MaskAnimationType.reveal, duration: duration, curve: curve);

  /// Creates a hide animation (contracts to center).
  const MaskAnimation.hide({int duration = 30, Curve curve = Curves.easeIn})
    : this._(type: MaskAnimationType.hide, duration: duration, curve: curve);

  /// Calculates the progress at the given frame.
  double progressAt(int frame) {
    if (frame < 0) {
      return type == MaskAnimationType.reveal ? 0.0 : 1.0;
    }
    if (frame >= duration) {
      return type == MaskAnimationType.reveal ? 1.0 : 0.0;
    }

    final linearProgress = frame / duration;
    final curvedProgress = curve.transform(linearProgress);

    return type == MaskAnimationType.reveal
        ? curvedProgress
        : 1.0 - curvedProgress;
  }
}

/// Types of mask animation.
enum MaskAnimationType {
  /// Reveal animation (expands from center).
  reveal,

  /// Hide animation (contracts to center).
  hide,
}
