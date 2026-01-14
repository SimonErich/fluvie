import 'package:flutter/widgets.dart';

import '../../presentation/fade_text.dart';
import '../../presentation/time_consumer.dart';

/// A text widget that animates counting from one number to another.
///
/// [CounterText] is useful for displaying statistics, scores, or any
/// numeric value that should animate when appearing.
///
/// Example:
/// ```dart
/// CounterText(
///   value: 1234,
///   startFrame: 30,
///   duration: 60,
///   style: TextStyle(fontSize: 48, color: Colors.white),
///   formatter: (n) => '\$$n',
/// )
/// ```
class CounterText extends StatelessWidget {
  /// The target value to count to.
  final int value;

  /// The starting value (defaults to 0).
  final int startValue;

  /// The frame at which counting begins.
  final int startFrame;

  /// Duration of the counting animation in frames.
  final int duration;

  /// Easing curve for the counting animation.
  final Curve curve;

  /// The style to apply to the text.
  final TextStyle? style;

  /// Optional formatter for the displayed number.
  ///
  /// Example: `(n) => '$n%'` to display as percentage.
  final String Function(int)? formatter;

  /// How the text should be aligned horizontally.
  final TextAlign? textAlign;

  /// Creates a counter text widget.
  const CounterText({
    super.key,
    required this.value,
    this.startValue = 0,
    this.startFrame = 0,
    this.duration = 60,
    this.curve = Curves.easeOut,
    this.style,
    this.formatter,
    this.textAlign,
  });

  /// Creates a counter that counts up from zero.
  const CounterText.countUp({
    super.key,
    required this.value,
    this.startFrame = 0,
    this.duration = 60,
    this.curve = Curves.easeOut,
    this.style,
    this.formatter,
    this.textAlign,
  }) : startValue = 0;

  /// Creates a counter that counts down to zero.
  const CounterText.countDown({
    super.key,
    required int from,
    this.startFrame = 0,
    this.duration = 60,
    this.curve = Curves.easeOut,
    this.style,
    this.formatter,
    this.textAlign,
  })  : value = 0,
        startValue = from;

  /// Creates a percentage counter (0% to value%).
  const CounterText.percentage({
    super.key,
    required this.value,
    this.startFrame = 0,
    this.duration = 60,
    this.curve = Curves.easeOut,
    this.style,
    this.textAlign,
  })  : startValue = 0,
        formatter = _percentageFormatter;

  static String _percentageFormatter(int n) => '$n%';

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Calculate progress within animation window
        final relativeFrame = frame - startFrame;

        int displayValue;
        if (relativeFrame < 0) {
          // Before animation starts
          displayValue = startValue;
        } else if (relativeFrame >= duration) {
          // After animation ends
          displayValue = value;
        } else if (duration <= 0) {
          // Zero duration - stay at initial value
          displayValue = startValue;
        } else {
          // During animation
          final linearProgress = relativeFrame / duration;
          final curvedProgress = curve.transform(linearProgress);
          displayValue =
              (startValue + (value - startValue) * curvedProgress).round();
        }

        // Format the value
        final displayText =
            formatter != null ? formatter!(displayValue) : '$displayValue';

        return FadeText(displayText, style: style, textAlign: textAlign);
      },
    );
  }
}
