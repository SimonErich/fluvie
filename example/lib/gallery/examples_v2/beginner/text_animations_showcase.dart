import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';
import '../../example_base.dart';
import '../../models/example_parameter.dart';

/// Text Animations Showcase - Different text animation types
/// Demonstrates: TypewriterText, CounterText, AnimatedText
class TextAnimationsShowcaseExample extends InteractiveExample {
  @override
  String get title => 'Text Animations Showcase';

  @override
  String get description =>
      'Side-by-side comparison of different text animation types';

  @override
  String get difficulty => 'Beginner';

  @override
  String get category => 'Text & Typography';

  @override
  List<String> get features => [
        'TypewriterText',
        'CounterText',
        'AnimatedText',
        'VColumn',
      ];

  @override
  List<ExampleParameter> get parameters => [
        ExampleParameter.slider(
          id: 'typewriterSpeed',
          label: 'Typewriter Speed',
          description: 'Characters per second',
          defaultValue: 15.0,
          minValue: 5.0,
          maxValue: 30.0,
          divisions: 25,
        ),
        ExampleParameter.slider(
          id: 'counterTarget',
          label: 'Counter Target',
          description: 'Number to count to',
          defaultValue: 1000,
          minValue: 100,
          maxValue: 9999,
        ),
        ExampleParameter.dropdown(
          id: 'animationStyle',
          label: 'Animation Style',
          description: 'Type of animation for third text',
          defaultValue: 'slideUpFade',
          options: const [
            DropdownOption(
              value: 'slideUpFade',
              label: 'Slide Up Fade',
            ),
            DropdownOption(
              value: 'scaleFade',
              label: 'Scale Fade',
            ),
            DropdownOption(
              value: 'fadeIn',
              label: 'Fade In',
            ),
          ],
        ),
      ];

  @override
  List<String> get instructions => [
        'This example showcases three different text animation types in Fluvie.',
        'TypewriterText reveals characters one at a time, like typing.',
        'CounterText animates numbers from a starting value to a target.',
        'AnimatedText provides various preset animations like slide, scale, and fade.',
        'VColumn arranges the text elements vertically with spacing.',
        'All three animations run simultaneously, each with their own timing.',
      ];

  @override
  Widget buildWithParameters(Map<String, dynamic> parameterValues) {
    final speed = (parameterValues['typewriterSpeed'] as num).toDouble();
    final target = (parameterValues['counterTarget'] as num).toInt();
    final style = parameterValues['animationStyle'] as String;

    return Video(
      width: 1080,
      height: 1920,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: 150,
          background: Background.gradient(
            colors: {0: const Color(0xFF2C3E50), 150: const Color(0xFF3498DB)},
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          children: [
            VCenter(
              child: VColumn(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 40,
                children: [
                  // Typewriter text
                  TypewriterText(
                    'Welcome to Fluvie',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    charsPerSecond: speed,
                  ),

                  // Counter text
                  CounterText(
                    value: target,
                    duration: 60,
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                    ),
                  ),

                  // Animated text
                  _buildAnimatedText(style),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedText(String style) {
    const textStyle = TextStyle(
      fontSize: 36,
      color: Colors.white70,
    );

    switch (style) {
      case 'slideUpFade':
        return AnimatedText.slideUpFade(
          'Create amazing videos',
          style: textStyle,
          duration: 40,
        );
      case 'scaleFade':
        return AnimatedText.scaleFade(
          'Create amazing videos',
          style: textStyle,
          duration: 40,
        );
      case 'fadeIn':
        return AnimatedText.fadeIn(
          'Create amazing videos',
          style: textStyle,
          duration: 40,
        );
      default:
        return AnimatedText.slideUpFade(
          'Create amazing videos',
          style: textStyle,
          duration: 40,
        );
    }
  }

  @override
  String get sourceCode => '''
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class TextAnimationsShowcaseExample extends InteractiveExample {
  @override
  Widget buildWithParameters(Map<String, dynamic> params) {
    return Video(
      width: 1080,
      height: 1920,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: 150,
          background: Background.gradient(
            colors: {0: Color(0xFF2C3E50), 150: Color(0xFF3498DB)},
          ),
          children: [
            VCenter(
              child: VColumn(
                spacing: 40,
                children: [
                  // Typewriter text
                  TypewriterText(
                    'Welcome to Fluvie',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    charsPerSecond: 15.0,
                  ),

                  // Counter text
                  CounterText(
                    value: 1000,
                    duration: 60,
                    style: const TextStyle(
                      fontSize: 72,
                      color: Color(0xFFFFD700),
                    ),
                  ),

                  // Animated text
                  AnimatedText.slideUpFade(
                    'Create amazing videos',
                    style: const TextStyle(fontSize: 36),
                    duration: 40,
                  ),
                ],
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
