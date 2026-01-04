import 'package:flutter/widgets.dart';

import 'fade.dart';

/// A text widget that automatically applies opacity from ancestor [Fade] widgets.
///
/// Unlike wrapping [Text] with Flutter's [Opacity] widget, [FadeText] applies
/// opacity directly to the text color. This avoids the `saveLayer()` call that
/// [Opacity] uses, which creates intermediate buffers with transparent backgrounds
/// that cause black rectangle artifacts when capturing frames for video rendering.
///
/// Example:
/// ```dart
/// Fade(
///   opacity: 0.5,
///   child: FadeText(
///     'Hello World',
///     style: TextStyle(color: Colors.white, fontSize: 24),
///   ),
/// )
/// ```
///
/// The text color's alpha will be multiplied by the fade opacity:
/// - If the style color is `Colors.white` (alpha = 1.0) and fade opacity is 0.5,
///   the rendered color will have alpha = 0.5
/// - If the style color already has alpha (e.g., `Colors.white.withValues(alpha: 0.8)`)
///   and fade opacity is 0.5, the rendered color will have alpha = 0.4 (0.8 * 0.5)
class FadeText extends StatelessWidget {
  /// The text to display.
  final String data;

  /// The style to apply to the text.
  ///
  /// The color's alpha will be multiplied by the fade opacity from
  /// ancestor [Fade] widgets.
  final TextStyle? style;

  /// How the text should be aligned horizontally.
  final TextAlign? textAlign;

  /// The directionality of the text.
  final TextDirection? textDirection;

  /// Whether the text should break at soft line breaks.
  final bool? softWrap;

  /// How visual overflow should be handled.
  final TextOverflow? overflow;

  /// The number of font pixels for each logical pixel.
  final double? textScaleFactor;

  /// The maximum number of lines for the text to span.
  final int? maxLines;

  /// An alternative semantics label for this text.
  final String? semanticsLabel;

  /// The width basis for the text.
  final TextWidthBasis? textWidthBasis;

  /// The height behavior for the text.
  final TextHeightBehavior? textHeightBehavior;

  /// The selection color for the text.
  final Color? selectionColor;

  const FadeText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  @override
  Widget build(BuildContext context) {
    final fadeOpacity = FadeValue.of(context);

    // Get the effective style, falling back to default text style
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = defaultStyle.merge(style);

    // Apply fade opacity to the text color
    final baseColor = effectiveStyle.color ?? const Color(0xFFFFFFFF);
    final fadedColor = baseColor.withFadeOpacity(fadeOpacity);

    return Text(
      data,
      style: effectiveStyle.copyWith(color: fadedColor),
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
