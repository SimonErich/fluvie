import 'package:flutter/widgets.dart';

import '../../presentation/fade_text.dart';
import '../../presentation/time_consumer.dart';

/// A text widget that renders a template with dynamic variable substitution.
///
/// [DataDrivenText] allows you to create text with placeholders that are
/// replaced with actual values at render time. Variables can optionally
/// be animated.
///
/// Example:
/// ```dart
/// DataDrivenText(
///   template: 'You achieved {count} goals this year!',
///   data: {'count': 42},
///   style: TextStyle(fontSize: 24, color: Colors.white),
/// )
/// ```
///
/// With animated values:
/// ```dart
/// DataDrivenText(
///   template: 'Score: {score}',
///   data: {'score': 1000},
///   animations: {
///     'score': DataAnimation.countUp(duration: 60),
///   },
///   startFrame: 30,
/// )
/// ```
class DataDrivenText extends StatelessWidget {
  /// The template string with {variable} placeholders.
  final String template;

  /// Map of variable names to their values.
  final Map<String, dynamic> data;

  /// Optional animations for specific variables.
  final Map<String, DataAnimation>? animations;

  /// The style to apply to the text.
  final TextStyle? style;

  /// The frame at which animations start.
  final int startFrame;

  /// How the text should be aligned horizontally.
  final TextAlign? textAlign;

  /// The maximum number of lines for the text.
  final int? maxLines;

  /// How visual overflow should be handled.
  final TextOverflow? overflow;

  /// Creates a data-driven text widget.
  const DataDrivenText({
    super.key,
    required this.template,
    required this.data,
    this.animations,
    this.style,
    this.startFrame = 0,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (animations == null || animations!.isEmpty) {
      // No animations, just substitute and render
      return FadeText(
        _substituteVariables(data),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return TimeConsumer(
      builder: (context, frame, _) {
        final relativeFrame = frame - startFrame;
        final animatedData = Map<String, dynamic>.from(data);

        // Apply animations to relevant variables
        for (final entry in animations!.entries) {
          final varName = entry.key;
          final animation = entry.value;
          final originalValue = data[varName];

          if (originalValue != null) {
            animatedData[varName] = animation.animate(
              originalValue,
              relativeFrame,
            );
          }
        }

        return FadeText(
          _substituteVariables(animatedData),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }

  String _substituteVariables(Map<String, dynamic> values) {
    var result = template;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }
}

/// Animation configuration for data values in [DataDrivenText].
class DataAnimation {
  /// The type of animation.
  final DataAnimationType type;

  /// Duration of the animation in frames.
  final int duration;

  /// Easing curve for the animation.
  final Curve curve;

  /// Starting value for countUp (defaults to 0).
  final int? startValue;

  /// Custom formatter for numeric values.
  final String Function(dynamic)? formatter;

  const DataAnimation._({
    required this.type,
    required this.duration,
    this.curve = Curves.easeOut,
    this.startValue,
    this.formatter,
  });

  /// Creates a count-up animation for numeric values.
  const DataAnimation.countUp({
    int duration = 60,
    Curve curve = Curves.easeOut,
    int startValue = 0,
    String Function(dynamic)? formatter,
  }) : this._(
          type: DataAnimationType.countUp,
          duration: duration,
          curve: curve,
          startValue: startValue,
          formatter: formatter,
        );

  /// Creates a reveal animation (shows full value at end).
  const DataAnimation.reveal({int duration = 30, Curve curve = Curves.easeOut})
      : this._(
            type: DataAnimationType.reveal, duration: duration, curve: curve);

  /// Creates a typewriter animation for string values.
  const DataAnimation.typewriter({int duration = 60})
      : this._(type: DataAnimationType.typewriter, duration: duration);

  /// Animates the value based on the current frame.
  dynamic animate(dynamic originalValue, int frame) {
    if (frame < 0) {
      return _getStartValue(originalValue);
    }
    if (frame >= duration) {
      return _formatValue(originalValue);
    }
    if (duration <= 0) {
      return _getStartValue(originalValue);
    }

    final progress = curve.transform(frame / duration);

    switch (type) {
      case DataAnimationType.countUp:
        if (originalValue is num) {
          final start = startValue ?? 0;
          final animated = start + (originalValue - start) * progress;
          final result = originalValue is int ? animated.round() : animated;
          return formatter != null ? formatter!(result) : result;
        }
        return _formatValue(originalValue);

      case DataAnimationType.reveal:
        return progress >= 1.0 ? _formatValue(originalValue) : '';

      case DataAnimationType.typewriter:
        if (originalValue is String) {
          final charsToShow = (originalValue.length * progress).floor();
          return originalValue.substring(0, charsToShow);
        }
        return _formatValue(originalValue);
    }
  }

  dynamic _getStartValue(dynamic originalValue) {
    switch (type) {
      case DataAnimationType.countUp:
        return formatter != null
            ? formatter!(startValue ?? 0)
            : startValue ?? 0;
      case DataAnimationType.reveal:
        return '';
      case DataAnimationType.typewriter:
        return '';
    }
  }

  dynamic _formatValue(dynamic value) {
    return formatter != null ? formatter!(value) : value;
  }
}

/// Types of data animation.
enum DataAnimationType {
  /// Count from a start value to the target value.
  countUp,

  /// Reveal the full value at the end of the animation.
  reveal,

  /// Reveal characters one by one.
  typewriter,
}
