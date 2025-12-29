import 'package:flutter/widgets.dart';

import 'fade.dart';

/// A container widget that automatically applies opacity from ancestor [Fade] widgets.
///
/// Unlike wrapping [Container] with Flutter's [Opacity] widget, [FadeContainer]
/// applies opacity directly to the container's colors (background color, border
/// colors, gradient colors). This avoids the `saveLayer()` call that [Opacity]
/// uses, which creates intermediate buffers with transparent backgrounds that
/// cause black rectangle artifacts when capturing frames for video rendering.
///
/// Example:
/// ```dart
/// Fade(
///   opacity: 0.5,
///   child: FadeContainer(
///     width: 200,
///     height: 100,
///     decoration: BoxDecoration(
///       color: Colors.blue,
///       borderRadius: BorderRadius.circular(8),
///     ),
///     child: FadeText('Hello'),
///   ),
/// )
/// ```
class FadeContainer extends StatelessWidget {
  /// The child widget.
  final Widget? child;

  /// The alignment of the child within the container.
  final AlignmentGeometry? alignment;

  /// The padding inside the container.
  final EdgeInsetsGeometry? padding;

  /// The background color of the container.
  ///
  /// The color's alpha will be multiplied by the fade opacity.
  /// Note: If [decoration] is provided, use the color in the decoration instead.
  final Color? color;

  /// The decoration to paint behind the child.
  ///
  /// Colors in the decoration (background color, gradient colors, border colors)
  /// will have their alpha multiplied by the fade opacity.
  final Decoration? decoration;

  /// The decoration to paint in front of the child.
  final Decoration? foregroundDecoration;

  /// The width of the container.
  final double? width;

  /// The height of the container.
  final double? height;

  /// The constraints to apply to the child.
  final BoxConstraints? constraints;

  /// The margin around the container.
  final EdgeInsetsGeometry? margin;

  /// The transformation matrix to apply.
  final Matrix4? transform;

  /// The alignment of the transform.
  final AlignmentGeometry? transformAlignment;

  /// The clip behavior for the container.
  final Clip clipBehavior;

  const FadeContainer({
    super.key,
    this.child,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    this.width,
    this.height,
    this.constraints,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final fadeOpacity = FadeValue.of(context);

    // Apply fade to color
    final fadedColor = color?.withFadeOpacity(fadeOpacity);

    // Apply fade to decoration
    final fadedDecoration = decoration != null
        ? _applyFadeToDecoration(decoration!, fadeOpacity)
        : null;

    // Apply fade to foreground decoration
    final fadedForegroundDecoration = foregroundDecoration != null
        ? _applyFadeToDecoration(foregroundDecoration!, fadeOpacity)
        : null;

    return Container(
      alignment: alignment,
      padding: padding,
      color: fadedDecoration == null ? fadedColor : null,
      decoration: fadedDecoration,
      foregroundDecoration: fadedForegroundDecoration,
      width: width,
      height: height,
      constraints: constraints,
      margin: margin,
      transform: transform,
      transformAlignment: transformAlignment,
      clipBehavior: clipBehavior,
      child: child,
    );
  }

  Decoration _applyFadeToDecoration(Decoration decoration, double fadeOpacity) {
    if (decoration is BoxDecoration) {
      return _applyFadeToBoxDecoration(decoration, fadeOpacity);
    }
    if (decoration is ShapeDecoration) {
      return _applyFadeToShapeDecoration(decoration, fadeOpacity);
    }
    // For other decoration types, return as-is
    // Users can extend this for custom decorations
    return decoration;
  }

  BoxDecoration _applyFadeToBoxDecoration(
    BoxDecoration decoration,
    double fadeOpacity,
  ) {
    return BoxDecoration(
      color: decoration.color?.withFadeOpacity(fadeOpacity),
      image: decoration.image,
      border: decoration.border != null
          ? _applyFadeToBorder(decoration.border!, fadeOpacity)
          : null,
      borderRadius: decoration.borderRadius,
      boxShadow: decoration.boxShadow?.map((shadow) {
        return BoxShadow(
          color: shadow.color.withFadeOpacity(fadeOpacity),
          offset: shadow.offset,
          blurRadius: shadow.blurRadius,
          spreadRadius: shadow.spreadRadius,
          blurStyle: shadow.blurStyle,
        );
      }).toList(),
      gradient: decoration.gradient != null
          ? _applyFadeToGradient(decoration.gradient!, fadeOpacity)
          : null,
      backgroundBlendMode: decoration.backgroundBlendMode,
      shape: decoration.shape,
    );
  }

  ShapeDecoration _applyFadeToShapeDecoration(
    ShapeDecoration decoration,
    double fadeOpacity,
  ) {
    return ShapeDecoration(
      color: decoration.color?.withFadeOpacity(fadeOpacity),
      image: decoration.image,
      gradient: decoration.gradient != null
          ? _applyFadeToGradient(decoration.gradient!, fadeOpacity)
          : null,
      shadows: decoration.shadows?.map((shadow) {
        return BoxShadow(
          color: shadow.color.withFadeOpacity(fadeOpacity),
          offset: shadow.offset,
          blurRadius: shadow.blurRadius,
          spreadRadius: shadow.spreadRadius,
          blurStyle: shadow.blurStyle,
        );
      }).toList(),
      shape: decoration.shape,
    );
  }

  BoxBorder _applyFadeToBorder(BoxBorder border, double fadeOpacity) {
    if (border is Border) {
      return Border(
        top: _applyFadeToBorderSide(border.top, fadeOpacity),
        right: _applyFadeToBorderSide(border.right, fadeOpacity),
        bottom: _applyFadeToBorderSide(border.bottom, fadeOpacity),
        left: _applyFadeToBorderSide(border.left, fadeOpacity),
      );
    }
    // For other border types, return as-is
    return border;
  }

  BorderSide _applyFadeToBorderSide(BorderSide side, double fadeOpacity) {
    return BorderSide(
      color: side.color.withFadeOpacity(fadeOpacity),
      width: side.width,
      style: side.style,
      strokeAlign: side.strokeAlign,
    );
  }

  Gradient _applyFadeToGradient(Gradient gradient, double fadeOpacity) {
    final fadedColors = gradient.colors
        .map((color) => color.withFadeOpacity(fadeOpacity))
        .toList();

    if (gradient is LinearGradient) {
      return LinearGradient(
        begin: gradient.begin,
        end: gradient.end,
        colors: fadedColors,
        stops: gradient.stops,
        tileMode: gradient.tileMode,
        transform: gradient.transform,
      );
    }
    if (gradient is RadialGradient) {
      return RadialGradient(
        center: gradient.center,
        radius: gradient.radius,
        colors: fadedColors,
        stops: gradient.stops,
        tileMode: gradient.tileMode,
        focal: gradient.focal,
        focalRadius: gradient.focalRadius,
        transform: gradient.transform,
      );
    }
    if (gradient is SweepGradient) {
      return SweepGradient(
        center: gradient.center,
        startAngle: gradient.startAngle,
        endAngle: gradient.endAngle,
        colors: fadedColors,
        stops: gradient.stops,
        tileMode: gradient.tileMode,
        transform: gradient.transform,
      );
    }
    // For other gradient types, return with faded colors if possible
    return gradient;
  }
}
