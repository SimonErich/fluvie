import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';

/// A widget that floats with a gentle oscillating animation.
///
/// [FloatingElement] creates a natural floating effect by combining
/// vertical oscillation with optional rotation. This is useful for
/// creating dynamic, attention-grabbing elements.
///
/// Example:
/// ```dart
/// FloatingElement(
///   position: Offset(100, 200),
///   floatAmplitude: Offset(0, 10),
///   floatFrequency: 0.5,
///   child: Image.asset('photo.jpg'),
/// )
/// ```
class FloatingElement extends StatelessWidget {
  /// The child widget to float.
  final Widget child;

  /// The base position of the element.
  final Offset position;

  /// The amplitude of the floating motion (x, y).
  final Offset floatAmplitude;

  /// The frequency of the float cycle (cycles per second).
  final double floatFrequency;

  /// Phase offset for the float animation (0.0 to 1.0).
  final double floatPhase;

  /// Base rotation angle in radians.
  final double rotation;

  /// Amplitude of rotation oscillation in radians.
  final double rotationAmplitude;

  /// Whether to include a subtle shadow.
  final bool showShadow;

  /// Shadow blur radius.
  final double shadowBlur;

  /// Shadow offset.
  final Offset shadowOffset;

  /// Shadow color.
  final Color shadowColor;

  /// Creates a floating element.
  const FloatingElement({
    super.key,
    required this.child,
    this.position = Offset.zero,
    this.floatAmplitude = const Offset(0, 10),
    this.floatFrequency = 0.5,
    this.floatPhase = 0.0,
    this.rotation = 0.0,
    this.rotationAmplitude = 0.0,
    this.showShadow = false,
    this.shadowBlur = 10,
    this.shadowOffset = const Offset(0, 5),
    this.shadowColor = const Color(0x40000000),
  });

  /// Creates a floating element with gentle rotation.
  const FloatingElement.withRotation({
    super.key,
    required this.child,
    this.position = Offset.zero,
    this.floatAmplitude = const Offset(0, 8),
    this.floatFrequency = 0.4,
    this.floatPhase = 0.0,
    this.rotation = 0.0,
    double rotationDegrees = 3.0,
    this.showShadow = false,
    this.shadowBlur = 10,
    this.shadowOffset = const Offset(0, 5),
    this.shadowColor = const Color(0x40000000),
  }) : rotationAmplitude = rotationDegrees * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;

        // Calculate float progress based on time
        final secondsElapsed = frame / fps;
        final cycleProgress =
            (secondsElapsed * floatFrequency + floatPhase) * 2 * math.pi;

        // Calculate offsets
        final xOffset = floatAmplitude.dx * math.sin(cycleProgress);
        final yOffset = floatAmplitude.dy * math.sin(cycleProgress);
        final rotationOffset =
            rotationAmplitude * math.sin(cycleProgress * 0.7);

        final totalRotation = rotation + rotationOffset;
        final totalOffset = Offset(
          position.dx + xOffset,
          position.dy + yOffset,
        );

        Widget result = child;

        // Apply rotation if needed
        if (totalRotation != 0) {
          result = Transform.rotate(angle: totalRotation, child: result);
        }

        // Add shadow if requested
        if (showShadow) {
          result = Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: shadowBlur,
                  offset: shadowOffset,
                ),
              ],
            ),
            child: result,
          );
        }

        // Apply position
        return Transform.translate(offset: totalOffset, child: result);
      },
    );
  }
}
