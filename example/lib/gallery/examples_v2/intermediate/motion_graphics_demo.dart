import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';
import '../../example_base.dart';
import '../../models/example_parameter.dart';

/// Motion Graphics Demo - Animated shapes with combined transformations
/// Demonstrates: PropAnimation.combine, translate/rotate/scale, VStack
class MotionGraphicsDemoExample extends InteractiveExample {
  @override
  String get title => 'Motion Graphics Demo';

  @override
  String get description =>
      'Animated shapes demonstrating combined property animations';

  @override
  String get difficulty => 'Intermediate';

  @override
  String get category => 'Animation & Effects';

  @override
  List<String> get features => [
    'PropAnimation.combine',
    'Translate',
    'Rotate',
    'Scale',
    'VStack',
  ];

  @override
  List<ExampleParameter> get parameters => [
    ExampleParameter.slider(
      id: 'shapeCount',
      label: 'Shape Count',
      description: 'Number of animated shapes',
      defaultValue: 5,
      minValue: 3,
      maxValue: 8,
    ),
    ExampleParameter.slider(
      id: 'animationDuration',
      label: 'Animation Duration (frames)',
      description: 'How long each shape animates',
      defaultValue: 60,
      minValue: 30,
      maxValue: 120,
    ),
    ExampleParameter.dropdown(
      id: 'easingCurve',
      label: 'Easing Curve',
      description: 'Animation easing style',
      defaultValue: 'easeInOut',
      options: const [
        DropdownOption(
          value: 'linear',
          label: 'Linear',
          description: 'Constant speed',
        ),
        DropdownOption(
          value: 'easeInOut',
          label: 'Ease In Out',
          description: 'Smooth acceleration and deceleration',
        ),
        DropdownOption(
          value: 'elasticOut',
          label: 'Elastic Out',
          description: 'Bouncy overshoot',
        ),
      ],
    ),
    ExampleParameter.color(
      id: 'primaryColor',
      label: 'Primary Color',
      description: 'Color for shapes',
      defaultValue: const Color(0xFF6C5CE7),
    ),
  ];

  @override
  List<String> get instructions => [
    'This example demonstrates combined property animations in Fluvie.',
    'PropAnimation.combine merges multiple transformations: translate, rotate, and scale.',
    'Each shape uses a staggered delay based on its index for a cascading effect.',
    'VStack layers the shapes on top of each other with timing control.',
    'The animations use different easing curves to create varied motion feels.',
    'Experiment with different shape counts and curves to see unique patterns!',
  ];

  @override
  Widget buildWithParameters(Map<String, dynamic> parameterValues) {
    final shapeCount = (parameterValues['shapeCount'] as num).toInt();
    final animationDuration = (parameterValues['animationDuration'] as num)
        .toInt();
    final easingCurve = parameterValues['easingCurve'] as String;
    final primaryColor = parameterValues['primaryColor'] as Color;

    final curve = _getCurve(easingCurve);

    return Video(
      width: 1080,
      height: 1080,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: 150,
          background: Background.gradient(
            colors: {0: const Color(0xFF1E1E2E), 150: const Color(0xFF2C2C3E)},
            type: GradientType.radial,
          ),
          children: [
            VCenter(
              child: VStack(
                alignment: Alignment.center,
                children: List.generate(shapeCount, (index) {
                  return _buildAnimatedShape(
                    index: index,
                    total: shapeCount,
                    duration: animationDuration,
                    curve: curve,
                    color: primaryColor,
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedShape({
    required int index,
    required int total,
    required int duration,
    required Curve curve,
    required Color color,
  }) {
    // Stagger the animation start based on index
    final staggerDelay = (index * 5);

    // Calculate rotation and scale for variety
    final rotationAmount = (index % 2 == 0 ? math.pi * 2 : -math.pi * 2);
    final startScale = 0.3 + (index * 0.1);

    // Create combined animation
    final animation = PropAnimation.combine([
      PropAnimation.translate(
        start: Offset(0, -100 - (index * 20).toDouble()),
        end: Offset.zero,
      ),
      PropAnimation.rotate(start: 0, end: rotationAmount),
      PropAnimation.scale(start: startScale, end: 1.0),
      PropAnimation.fade(start: 0.0, end: 0.8 - (index * 0.1)),
    ]);

    return AnimatedProp(
      startFrame: staggerDelay,
      duration: duration,
      animation: animation,
      curve: curve,
      child: _buildShape(index, total, color),
    );
  }

  Widget _buildShape(int index, int total, Color color) {
    final size = 150.0 - (index * 15.0);
    final hue = (color.computeLuminance() * 360 + (index * 30)) % 360;
    final shapeColor = HSVColor.fromAHSV(1.0, hue, 0.7, 0.9).toColor();

    // Alternate between circle and square
    if (index % 2 == 0) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: shapeColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: shapeColor.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: shapeColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: shapeColor.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
      );
    }
  }

  Curve _getCurve(String curveName) {
    switch (curveName) {
      case 'linear':
        return Curves.linear;
      case 'easeInOut':
        return Curves.easeInOut;
      case 'elasticOut':
        return Curves.elasticOut;
      default:
        return Curves.easeInOut;
    }
  }

  @override
  String get sourceCode => '''
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class MotionGraphicsDemoExample extends InteractiveExample {
  @override
  Widget buildWithParameters(Map<String, dynamic> params) {
    final shapeCount = params['shapeCount'] as int;
    final animationDuration = params['animationDuration'] as int;
    final primaryColor = params['primaryColor'] as Color;

    return Video(
      width: 1080,
      height: 1080,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: 150,
          background: Background.gradient(
            colors: {0: Color(0xFF1E1E2E), 150: Color(0xFF2C2C3E)},
            type: GradientType.radial,
          ),
          children: [
            VCenter(
              child: VStack(
                alignment: Alignment.center,
                children: List.generate(shapeCount, (index) {
                  final staggerDelay = index * 5;
                  final rotationAmount = index % 2 == 0 ? math.pi * 2 : -math.pi * 2;
                  final startScale = 0.3 + (index * 0.1);

                  // Combined animation
                  final animation = PropAnimation.combine([
                    PropAnimation.translate(
                      start: Offset(0, -100 - (index * 20).toDouble()),
                      end: Offset.zero,
                    ),
                    PropAnimation.rotate(start: 0, end: rotationAmount),
                    PropAnimation.scale(start: startScale, end: 1.0),
                    PropAnimation.fade(start: 0.0, end: 0.8),
                  ]);

                  return AnimatedProp(
                    startFrame: staggerDelay,
                    duration: animationDuration,
                    animation: animation,
                    curve: Curves.easeInOut,
                    child: Container(
                      width: 150.0 - (index * 15.0),
                      height: 150.0 - (index * 15.0),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: index % 2 == 0
                            ? BoxShape.circle
                            : BoxShape.rectangle,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
''';
}
