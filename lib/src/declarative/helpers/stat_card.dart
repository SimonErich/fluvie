import 'package:flutter/widgets.dart';

import '../../presentation/fade_text.dart';
import '../../presentation/time_consumer.dart';

/// A widget that displays a statistic with an animated counter.
///
/// [StatCard] is useful for displaying metrics, scores, or any numeric
/// value with optional counting animation and styling.
///
/// Example:
/// ```dart
/// StatCard(
///   value: 1234,
///   label: 'Photos',
///   sublabel: 'This Year',
///   color: Colors.blue,
///   startFrame: 30,
///   countDuration: 60,
/// )
/// ```
class StatCard extends StatelessWidget {
  /// The numeric value to display.
  final int value;

  /// Main label below the value.
  final String label;

  /// Optional secondary label.
  final String? sublabel;

  /// Accent color for the value.
  final Color color;

  /// The frame at which counting animation starts.
  final int startFrame;

  /// Duration of the counting animation in frames.
  final int countDuration;

  /// Easing curve for the count animation.
  final Curve countCurve;

  /// Optional fixed size for the card.
  final Size? size;

  /// Background color of the card.
  final Color? backgroundColor;

  /// Border radius of the card.
  final double borderRadius;

  /// Padding inside the card.
  final EdgeInsets padding;

  /// Style for the value text.
  final TextStyle? valueStyle;

  /// Style for the label text.
  final TextStyle? labelStyle;

  /// Style for the sublabel text.
  final TextStyle? sublabelStyle;

  /// Optional formatter for the value.
  final String Function(int)? formatter;

  /// Creates a stat card.
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.sublabel,
    this.color = const Color(0xFF2196F3),
    this.startFrame = 0,
    this.countDuration = 60,
    this.countCurve = Curves.easeOut,
    this.size,
    this.backgroundColor,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(24),
    this.valueStyle,
    this.labelStyle,
    this.sublabelStyle,
    this.formatter,
  });

  /// Creates a stat card with percentage formatting.
  const StatCard.percentage({
    super.key,
    required this.value,
    required this.label,
    this.sublabel,
    this.color = const Color(0xFF4CAF50),
    this.startFrame = 0,
    this.countDuration = 60,
    this.countCurve = Curves.easeOut,
    this.size,
    this.backgroundColor,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(24),
    this.valueStyle,
    this.labelStyle,
    this.sublabelStyle,
  }) : formatter = _percentageFormatter;

  static String _percentageFormatter(int n) => '$n%';

  /// Creates a stat card with currency formatting.
  StatCard.currency({
    super.key,
    required this.value,
    required this.label,
    this.sublabel,
    this.color = const Color(0xFFFF9800),
    this.startFrame = 0,
    this.countDuration = 60,
    this.countCurve = Curves.easeOut,
    this.size,
    this.backgroundColor,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(24),
    this.valueStyle,
    this.labelStyle,
    this.sublabelStyle,
    String currencySymbol = '\$',
  }) : formatter = ((int n) => '$currencySymbol$n');

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Calculate animated value
        final relativeFrame = frame - startFrame;
        int displayValue;

        if (relativeFrame < 0) {
          displayValue = 0;
        } else if (relativeFrame >= countDuration) {
          displayValue = value;
        } else {
          final progress = relativeFrame / countDuration;
          final curvedProgress = countCurve.transform(progress);
          displayValue = (value * curvedProgress).round();
        }

        final displayText =
            formatter != null ? formatter!(displayValue) : '$displayValue';

        return Container(
          width: size?.width,
          height: size?.height,
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Value
              FadeText(
                displayText,
                style: valueStyle ??
                    TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Label
              FadeText(
                label,
                style: labelStyle ??
                    const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFFFFFFF),
                    ),
                textAlign: TextAlign.center,
              ),
              // Sublabel
              if (sublabel != null) ...[
                const SizedBox(height: 4),
                FadeText(
                  sublabel!,
                  style: sublabelStyle ??
                      TextStyle(
                        fontSize: 14,
                        color: const Color(0xFFFFFFFF).withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
