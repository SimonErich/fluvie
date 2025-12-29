import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';
import '../../example_base.dart';
import '../../models/example_parameter.dart';

/// Hello Fluvie - The simplest possible example
/// Demonstrates: Basic Video, Scene, AnimatedText, Background.gradient
class HelloFluvieExample extends InteractiveExample {
  @override
  String get title => 'Hello Fluvie';

  @override
  String get description =>
      'A minimal example showing basic text animation with a gradient background';

  @override
  String get difficulty => 'Beginner';

  @override
  String get category => 'Getting Started';

  @override
  List<String> get features => [
        'Video',
        'Scene',
        'AnimatedText.slideUpFade',
        'Background.gradient',
      ];

  @override
  List<ExampleParameter> get parameters => [
        ExampleParameter.slider(
          id: 'duration',
          label: 'Duration (frames)',
          description: 'Total length of the video',
          defaultValue: 90,
          minValue: 60,
          maxValue: 180,
        ),
        ExampleParameter.text(
          id: 'text',
          label: 'Text',
          description: 'The text to display',
          defaultValue: 'Hello Fluvie!',
        ),
        ExampleParameter.slider(
          id: 'fontSize',
          label: 'Font Size',
          description: 'Size of the text',
          defaultValue: 64.0,
          minValue: 32.0,
          maxValue: 96.0,
          divisions: 64,
        ),
        ExampleParameter.color(
          id: 'colorStart',
          label: 'Gradient Start',
          description: 'Starting color of the gradient',
          defaultValue: const Color(0xFF667EEA),
        ),
        ExampleParameter.color(
          id: 'colorEnd',
          label: 'Gradient End',
          description: 'Ending color of the gradient',
          defaultValue: const Color(0xFF764BA2),
        ),
        ExampleParameter.dropdown(
          id: 'curve',
          label: 'Animation Curve',
          description: 'Easing curve for the animation',
          defaultValue: 'easeOut',
          options: const [
            DropdownOption(
              value: 'linear',
              label: 'Linear',
              description: 'Constant speed',
            ),
            DropdownOption(
              value: 'easeIn',
              label: 'Ease In',
              description: 'Starts slow',
            ),
            DropdownOption(
              value: 'easeOut',
              label: 'Ease Out',
              description: 'Ends slow',
            ),
            DropdownOption(
              value: 'easeInOut',
              label: 'Ease In Out',
              description: 'Slow start and end',
            ),
          ],
        ),
      ];

  @override
  List<String> get instructions => [
        'This is the simplest Fluvie example. It creates a video with a single scene.',
        'The Video widget is the root of all Fluvie compositions. It defines the format (1080x1080) and framerate (30 fps).',
        'The Scene widget represents a time-bounded section of the video. Here it lasts for the full duration.',
        'Background.gradient creates a smooth color transition behind our content.',
        'AnimatedText.slideUpFade animates the text entering from below while fading in.',
        'VCenter positions the text in the center of the screen.',
        'Try adjusting the parameters to see how they affect the animation!',
      ];

  @override
  Widget buildWithParameters(Map<String, dynamic> parameterValues) {
    // Extract parameters
    final duration = (parameterValues['duration'] as num).toInt();
    final text = parameterValues['text'] as String;
    final fontSize = (parameterValues['fontSize'] as num).toDouble();
    final colorStart = parameterValues['colorStart'] as Color;
    final colorEnd = parameterValues['colorEnd'] as Color;
    final curveString = parameterValues['curve'] as String;

    // Convert curve string to Curve
    final curve = _getCurve(curveString);

    return Video(
      // Video format: 1080x1080 square at 30fps
      width: 1080,
      height: 1080,
      fps: 30,
      scenes: [
        Scene(
          // Scene lasts for the full video duration
          durationInFrames: duration,

          // Gradient background
          background: Background.gradient(
            colors: {0: colorStart, duration: colorEnd},
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),

          children: [
            VCenter(
              // Text slides up and fades in over first 30 frames
              child: AnimatedText.slideUpFade(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                duration: 30,
                curve: curve,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Curve _getCurve(String curveName) {
    switch (curveName) {
      case 'linear':
        return Curves.linear;
      case 'easeIn':
        return Curves.easeIn;
      case 'easeOut':
        return Curves.easeOut;
      case 'easeInOut':
        return Curves.easeInOut;
      default:
        return Curves.easeOut;
    }
  }

  @override
  String get sourceCode => '''
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

/// Hello Fluvie - The simplest possible example
class HelloFluvieExample extends InteractiveExample {
  @override
  Widget buildWithParameters(Map<String, dynamic> params) {
    final duration = params['duration'] as int;
    final text = params['text'] as String;
    final fontSize = params['fontSize'] as double;
    final colorStart = params['colorStart'] as Color;
    final colorEnd = params['colorEnd'] as Color;

    return Video(
      width: 1080,
      height: 1080,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: duration,
          background: Background.gradient(
            colors: {0: colorStart, duration: colorEnd},
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          children: [
            VCenter(
              child: AnimatedText.slideUpFade(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                duration: 30,
                curve: Curves.easeOut,
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
