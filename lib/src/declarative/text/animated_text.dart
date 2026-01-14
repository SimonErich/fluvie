import 'package:flutter/widgets.dart';

import '../../presentation/fade_text.dart';
import '../../presentation/time_consumer.dart';
import '../animations/core/prop_animation.dart';

/// A text widget with built-in animation support.
///
/// [AnimatedText] combines text rendering with [PropAnimation] for easy
/// animated text effects like fade-in, slide-up, scale, etc.
///
/// Example:
/// ```dart
/// AnimatedText(
///   'Hello World',
///   style: TextStyle(fontSize: 48, color: Colors.white),
///   animation: PropAnimation.slideUpFade(),
///   duration: 30,
/// )
/// ```
class AnimatedText extends StatelessWidget {
  /// The text to display.
  final String text;

  /// The style to apply to the text.
  final TextStyle? style;

  /// The animation to apply.
  final PropAnimation? animation;

  /// The frame at which to start the animation (relative to scene start).
  final int startFrame;

  /// Duration of the animation in frames.
  final int duration;

  /// Easing curve for the animation.
  final Curve curve;

  /// How the text should be aligned horizontally.
  final TextAlign? textAlign;

  /// The maximum number of lines for the text.
  final int? maxLines;

  /// How visual overflow should be handled.
  final TextOverflow? overflow;

  /// Creates an animated text widget.
  const AnimatedText(
    this.text, {
    super.key,
    this.style,
    this.animation,
    this.startFrame = 0,
    this.duration = 30,
    this.curve = Curves.easeOut,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  /// Creates a fade-in animated text.
  const AnimatedText.fadeIn(
    this.text, {
    super.key,
    this.style,
    this.startFrame = 0,
    this.duration = 30,
    this.curve = Curves.easeOut,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : animation = const FadeAnimation(start: 0.0, end: 1.0);

  /// Creates a slide-up animated text.
  AnimatedText.slideUp(
    this.text, {
    super.key,
    this.style,
    this.startFrame = 0,
    this.duration = 30,
    this.curve = Curves.easeOut,
    this.textAlign,
    this.maxLines,
    this.overflow,
    double distance = 30,
  }) : animation = TranslateAnimation(
          start: Offset(0, distance),
          end: Offset.zero,
        );

  /// Creates a slide-up with fade animated text.
  AnimatedText.slideUpFade(
    this.text, {
    super.key,
    this.style,
    this.startFrame = 0,
    this.duration = 30,
    this.curve = Curves.easeOut,
    this.textAlign,
    this.maxLines,
    this.overflow,
    double distance = 30,
  }) : animation = CombinedAnimation([
          TranslateAnimation(start: Offset(0, distance), end: Offset.zero),
          const FadeAnimation(start: 0.0, end: 1.0),
        ]);

  /// Creates a scale animated text.
  AnimatedText.scale(
    this.text, {
    super.key,
    this.style,
    this.startFrame = 0,
    this.duration = 30,
    this.curve = Curves.easeOut,
    this.textAlign,
    this.maxLines,
    this.overflow,
    double start = 0.5,
  }) : animation = ScaleAnimation(start: start, end: 1.0);

  /// Creates a scale with fade animated text.
  AnimatedText.scaleFade(
    this.text, {
    super.key,
    this.style,
    this.startFrame = 0,
    this.duration = 30,
    this.curve = Curves.easeOut,
    this.textAlign,
    this.maxLines,
    this.overflow,
    double startScale = 0.8,
  }) : animation = CombinedAnimation([
          ScaleAnimation(start: startScale, end: 1.0),
          const FadeAnimation(start: 0.0, end: 1.0),
        ]);

  @override
  Widget build(BuildContext context) {
    final textWidget = FadeText(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );

    if (animation == null) {
      return textWidget;
    }

    return TimeConsumer(
      builder: (context, frame, _) {
        // Calculate progress within animation window
        final relativeFrame = frame - startFrame;
        if (relativeFrame < 0) {
          // Before animation starts
          return animation!.apply(textWidget, 0.0);
        }
        if (relativeFrame >= duration) {
          // After animation ends
          return animation!.apply(textWidget, 1.0);
        }

        // During animation
        if (duration <= 0) {
          return animation!.apply(textWidget, 0.0);
        }
        final linearProgress = relativeFrame / duration;
        final curvedProgress = curve.transform(linearProgress);
        return animation!.apply(textWidget, curvedProgress);
      },
    );
  }
}
