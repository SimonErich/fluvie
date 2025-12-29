import 'package:flutter/widgets.dart';

/// Provides an opacity multiplier to descendant widgets.
///
/// This is used by fade-aware widgets (like [FadeText], [FadeContainer]) to
/// apply opacity directly to their colors, avoiding Flutter's [Opacity] widget
/// which uses `saveLayer()` and creates intermediate buffers with transparent
/// backgrounds.
///
/// When capturing frames for video rendering, these transparent buffers cause
/// black rectangle artifacts. By using [FadeValue] and fade-aware widgets,
/// opacity is applied directly to paint colors, which renders correctly.
///
/// Example:
/// ```dart
/// Fade(
///   opacity: 0.5,
///   child: FadeText('Hello'), // Text color will be at 50% opacity
/// )
/// ```
class FadeValue extends InheritedWidget {
  /// The opacity value (0.0 to 1.0) to apply to descendant fade-aware widgets.
  final double opacity;

  const FadeValue({super.key, required this.opacity, required super.child});

  /// Gets the current opacity from the nearest [FadeValue] ancestor.
  /// Returns 1.0 if no [FadeValue] is found.
  static double of(BuildContext context) {
    final fadeValue = context.dependOnInheritedWidgetOfExactType<FadeValue>();
    return fadeValue?.opacity ?? 1.0;
  }

  /// Gets the current opacity without registering for updates.
  /// Returns 1.0 if no [FadeValue] is found.
  static double maybeOf(BuildContext context) {
    final fadeValue = context.getInheritedWidgetOfExactType<FadeValue>();
    return fadeValue?.opacity ?? 1.0;
  }

  @override
  bool updateShouldNotify(FadeValue oldWidget) {
    return opacity != oldWidget.opacity;
  }
}

/// A widget that provides opacity to its descendants without using `saveLayer()`.
///
/// Unlike Flutter's [Opacity] widget, [Fade] does not create an intermediate
/// buffer. Instead, it provides an opacity value via [FadeValue] that
/// fade-aware widgets (like [FadeText], [FadeContainer]) use to modify their
/// colors directly.
///
/// This approach:
/// - Does NOT use `saveLayer()` (no intermediate buffers)
/// - Applies opacity directly to paint colors
/// - Renders correctly when captured with `toImage()` for video encoding
/// - Has better performance than [Opacity] widget
///
/// **Important**: Only fade-aware widgets will respond to [Fade]. Standard
/// Flutter widgets like [Text] will not automatically fade. Use [FadeText]
/// instead.
///
/// Example:
/// ```dart
/// Fade(
///   opacity: 0.5,
///   child: Column(
///     children: [
///       FadeText('This will be 50% opacity'),
///       Text('This will NOT fade - use FadeText instead'),
///     ],
///   ),
/// )
/// ```
///
/// Nested [Fade] widgets multiply their opacity values:
/// ```dart
/// Fade(
///   opacity: 0.5,
///   child: Fade(
///     opacity: 0.5,
///     child: FadeText('This will be 25% opacity (0.5 * 0.5)'),
///   ),
/// )
/// ```
class Fade extends StatelessWidget {
  /// The opacity to apply (0.0 = fully transparent, 1.0 = fully opaque).
  final double opacity;

  /// The widget subtree to apply opacity to.
  final Widget child;

  const Fade({super.key, required this.opacity, required this.child});

  @override
  Widget build(BuildContext context) {
    // Multiply with parent opacity for nested Fade widgets
    final parentOpacity = FadeValue.of(context);
    final effectiveOpacity = (parentOpacity * opacity).clamp(0.0, 1.0);

    // If fully transparent, don't render at all (same as Opacity behavior)
    if (effectiveOpacity == 0.0) {
      return const SizedBox.shrink();
    }

    // If fully opaque and no parent fade, skip the FadeValue wrapper
    if (effectiveOpacity == 1.0) {
      return child;
    }

    return FadeValue(opacity: effectiveOpacity, child: child);
  }
}

/// Extension to apply fade value to colors.
extension FadeColorExtension on Color {
  /// Returns this color with its alpha multiplied by the given opacity.
  Color withFadeOpacity(double fadeOpacity) {
    final newAlpha = (a * fadeOpacity).clamp(0.0, 1.0);
    return withValues(alpha: newAlpha);
  }
}
