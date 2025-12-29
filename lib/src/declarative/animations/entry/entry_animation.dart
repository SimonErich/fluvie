import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/prop_animation.dart';

/// Slide direction for entry animations.
///
/// Note: This is named EntrySlideDirection to avoid conflict with
/// the SlideDirection enum in the slide_in.dart animation.
enum EntrySlideDirection { fromLeft, fromRight, fromTop, fromBottom }

/// Shape for masked wipe animations.
enum WipeShape { circle, star, diamond, hexagon, heart }

/// Base class for entry animations that reveal elements.
///
/// Entry animations transform a widget from an initial hidden/transformed state
/// to its final visible state over a duration. They are designed to be used
/// with [AnimatedProp] or as standalone widgets.
///
/// Example:
/// ```dart
/// AnimatedProp(
///   animation: EntryAnimation.elasticPop(
///     overshoot: 1.15,
///     startScale: 0.0,
///   ),
///   duration: 45,
///   child: MyWidget(),
/// )
/// ```
abstract class EntryAnimation extends PropAnimation {
  const EntryAnimation();

  /// The default duration in frames for this animation.
  int get defaultDuration;

  /// The recommended curve for this animation.
  Curve get recommendedCurve;

  /// Creates an elastic pop animation that scales with overshoot.
  ///
  /// The element scales from [startScale] to [overshoot] (typically > 1.0),
  /// then settles back to 1.0 creating a spring-like effect.
  ///
  /// Parameters:
  /// - [overshoot]: The maximum scale to reach before settling (default: 1.1)
  /// - [startScale]: The initial scale (default: 0.0)
  /// - [alignment]: Scale alignment (default: center)
  const factory EntryAnimation.elasticPop({
    double overshoot,
    double startScale,
    Alignment alignment,
  }) = ElasticPopAnimation;

  /// Creates a strobe reveal animation with flickering opacity.
  ///
  /// The element flickers rapidly using a sine wave pattern,
  /// dampening over time until fully visible.
  ///
  /// Parameters:
  /// - [flickerCount]: Number of flicker cycles (default: 5)
  /// - [flickerIntensity]: Strength of the flicker effect 0-1 (default: 0.7)
  const factory EntryAnimation.strobeReveal({
    int flickerCount,
    double flickerIntensity,
  }) = StrobeRevealAnimation;

  /// Creates a glitch slide animation with RGB echo effect.
  ///
  /// The element slides in from [direction] with trailing red/cyan
  /// "echoes" that create a chromatic aberration glitch effect.
  ///
  /// Parameters:
  /// - [direction]: Direction to slide from (default: fromLeft)
  /// - [distance]: Slide distance in pixels (default: 200)
  /// - [rgbOffset]: RGB channel separation in pixels (default: 8)
  /// - [echoOpacity]: Opacity of the RGB echoes (default: 0.4)
  const factory EntryAnimation.glitchSlide({
    EntrySlideDirection direction,
    double distance,
    double rgbOffset,
    double echoOpacity,
  }) = GlitchSlideAnimation;

  /// Creates a masked wipe reveal animation.
  ///
  /// The element is revealed through an expanding geometric shape
  /// (circle, star, diamond, etc.) creating a cinematic wipe effect.
  ///
  /// Parameters:
  /// - [shape]: The shape of the mask (default: circle)
  /// - [origin]: Where the mask expands from (default: center)
  const factory EntryAnimation.maskedWipe({WipeShape shape, Alignment origin}) =
      MaskedWipeAnimation;
}

/// An elastic pop animation that scales from 0 to overshoot to 1.0.
///
/// Creates a spring-like effect where the element "pops" into view,
/// overshoots slightly, then settles into place.
class ElasticPopAnimation extends EntryAnimation {
  /// The maximum scale to reach before settling (typically > 1.0).
  final double overshoot;

  /// The initial scale before animation starts.
  final double startScale;

  /// The alignment for the scale transform.
  final Alignment alignment;

  const ElasticPopAnimation({
    this.overshoot = 1.1,
    this.startScale = 0.0,
    this.alignment = Alignment.center,
  });

  @override
  int get defaultDuration => 45;

  @override
  Curve get recommendedCurve => Curves.easeOutBack;

  @override
  Widget apply(Widget child, double progress) {
    // Scale: startScale -> overshoot -> 1.0
    // Uses a custom curve that overshoots then settles
    double scale;
    if (progress < 0.7) {
      // Scale up past target
      final t = progress / 0.7;
      scale = startScale + (overshoot - startScale) * t;
    } else {
      // Settle back to 1.0
      final t = (progress - 0.7) / 0.3;
      scale = overshoot - (overshoot - 1.0) * t;
    }

    return Transform.scale(
      scale: scale.clamp(0.0, 2.0),
      alignment: alignment,
      child: child,
    );
  }
}

/// A strobe/flicker reveal animation using sine wave oscillation.
///
/// Creates a flickering effect where the element blinks rapidly
/// before settling to full opacity.
class StrobeRevealAnimation extends EntryAnimation {
  /// Number of complete flicker cycles during the animation.
  final int flickerCount;

  /// Intensity of the flicker effect (0.0 - 1.0).
  final double flickerIntensity;

  const StrobeRevealAnimation({
    this.flickerCount = 5,
    this.flickerIntensity = 0.7,
  });

  @override
  int get defaultDuration => 30;

  @override
  Curve get recommendedCurve => Curves.linear;

  @override
  Widget apply(Widget child, double progress) {
    // Sine wave creates flicker, dampened over time
    final dampening = 1.0 - progress; // Reduces flicker as we approach end
    final flicker = math.sin(progress * flickerCount * 2 * math.pi);
    final flickerAmount = flicker * flickerIntensity * dampening;

    // Base opacity increases over time, flicker affects it
    final baseOpacity = progress;
    final opacity = (baseOpacity - flickerAmount.abs() * 0.5).clamp(0.0, 1.0);

    return Opacity(opacity: opacity, child: child);
  }
}

/// A glitch slide animation with RGB color separation echo effect.
///
/// The element slides in while trailing RGB "echoes" create a
/// chromatic aberration glitch effect.
class GlitchSlideAnimation extends EntryAnimation {
  /// Direction to slide from.
  final EntrySlideDirection direction;

  /// Distance to slide in pixels.
  final double distance;

  /// RGB channel separation in pixels.
  final double rgbOffset;

  /// Opacity of the RGB echo layers (0.0 - 1.0).
  final double echoOpacity;

  const GlitchSlideAnimation({
    this.direction = EntrySlideDirection.fromLeft,
    this.distance = 200,
    this.rgbOffset = 8,
    this.echoOpacity = 0.4,
  });

  @override
  int get defaultDuration => 40;

  @override
  Curve get recommendedCurve => Curves.easeOutExpo;

  @override
  Widget apply(Widget child, double progress) {
    final slideOffset = _calculateSlideOffset(progress);
    final glitchActive = progress < 0.7;

    if (!glitchActive) {
      // No glitch effect, just position
      return Transform.translate(offset: slideOffset, child: child);
    }

    // Glitch intensity decreases as animation progresses
    final glitchStrength = (1.0 - progress / 0.7).clamp(0.0, 1.0);
    final currentRgbOffset = rgbOffset * glitchStrength;

    // Build glitch stack with RGB echoes
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Red channel echo (offset one direction)
        Transform.translate(
          offset: slideOffset + Offset(-currentRgbOffset, 0),
          child: Opacity(
            opacity: echoOpacity * glitchStrength,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0xFFFF0000),
                BlendMode.srcATop,
              ),
              child: child,
            ),
          ),
        ),
        // Cyan channel echo (offset opposite direction)
        Transform.translate(
          offset: slideOffset + Offset(currentRgbOffset, 0),
          child: Opacity(
            opacity: echoOpacity * glitchStrength,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0xFF00FFFF),
                BlendMode.srcATop,
              ),
              child: child,
            ),
          ),
        ),
        // Main element
        Transform.translate(offset: slideOffset, child: child),
      ],
    );
  }

  Offset _calculateSlideOffset(double progress) {
    final remaining = distance * (1 - progress);
    switch (direction) {
      case EntrySlideDirection.fromLeft:
        return Offset(-remaining, 0);
      case EntrySlideDirection.fromRight:
        return Offset(remaining, 0);
      case EntrySlideDirection.fromTop:
        return Offset(0, -remaining);
      case EntrySlideDirection.fromBottom:
        return Offset(0, remaining);
    }
  }
}

/// A masked wipe reveal through an expanding geometric shape.
///
/// The element is revealed through an expanding shape (circle, star,
/// diamond, etc.) creating a cinematic wipe effect.
class MaskedWipeAnimation extends EntryAnimation {
  /// The shape of the expanding mask.
  final WipeShape shape;

  /// Where the mask expands from.
  final Alignment origin;

  const MaskedWipeAnimation({
    this.shape = WipeShape.circle,
    this.origin = Alignment.center,
  });

  @override
  int get defaultDuration => 45;

  @override
  Curve get recommendedCurve => Curves.easeOutCubic;

  @override
  Widget apply(Widget child, double progress) {
    return ClipPath(
      clipper: _WipeShapeClipper(
        shape: shape,
        origin: origin,
        progress: progress,
      ),
      child: child,
    );
  }
}

/// Custom clipper for wipe shape animations.
class _WipeShapeClipper extends CustomClipper<Path> {
  final WipeShape shape;
  final Alignment origin;
  final double progress;

  _WipeShapeClipper({
    required this.shape,
    required this.origin,
    required this.progress,
  });

  @override
  Path getClip(Size size) {
    // Calculate center based on alignment
    final centerX = size.width * (0.5 + origin.x * 0.5);
    final centerY = size.height * (0.5 + origin.y * 0.5);

    // Maximum radius to cover entire area
    final maxRadius = math.sqrt(
      math.pow(math.max(centerX, size.width - centerX), 2) +
          math.pow(math.max(centerY, size.height - centerY), 2),
    );

    final currentRadius = maxRadius * progress * 1.2; // Slight overshoot

    switch (shape) {
      case WipeShape.circle:
        return _createCirclePath(centerX, centerY, currentRadius);
      case WipeShape.star:
        return _createStarPath(centerX, centerY, currentRadius);
      case WipeShape.diamond:
        return _createDiamondPath(centerX, centerY, currentRadius);
      case WipeShape.hexagon:
        return _createHexagonPath(centerX, centerY, currentRadius);
      case WipeShape.heart:
        return _createHeartPath(centerX, centerY, currentRadius);
    }
  }

  Path _createCirclePath(double cx, double cy, double radius) {
    return Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
  }

  Path _createStarPath(double cx, double cy, double radius) {
    final path = Path();
    const points = 5;
    const innerRadiusRatio = 0.5;

    for (var i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final r = i.isEven ? radius : radius * innerRadiusRatio;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _createDiamondPath(double cx, double cy, double radius) {
    return Path()
      ..moveTo(cx, cy - radius)
      ..lineTo(cx + radius, cy)
      ..lineTo(cx, cy + radius)
      ..lineTo(cx - radius, cy)
      ..close();
  }

  Path _createHexagonPath(double cx, double cy, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) - math.pi / 6;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _createHeartPath(double cx, double cy, double radius) {
    final path = Path();
    final width = radius * 2;
    final height = radius * 1.8;

    // Heart shape using cubic bezier curves
    path.moveTo(cx, cy + height * 0.3);

    // Left curve
    path.cubicTo(
      cx - width * 0.5,
      cy - height * 0.15,
      cx - width * 0.5,
      cy - height * 0.5,
      cx,
      cy - height * 0.15,
    );

    // Right curve
    path.cubicTo(
      cx + width * 0.5,
      cy - height * 0.5,
      cx + width * 0.5,
      cy - height * 0.15,
      cx,
      cy + height * 0.3,
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _WipeShapeClipper oldClipper) {
    return oldClipper.progress != progress ||
        oldClipper.shape != shape ||
        oldClipper.origin != origin;
  }
}
