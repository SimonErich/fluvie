import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';
import '../../example_base.dart';
import '../../models/example_parameter.dart';

/// Simple Slideshow - Photo slideshow with transitions
/// Demonstrates: Multiple scenes, SceneTransition, Images
class SimpleSlideshowExample extends InteractiveExample {
  @override
  String get title => 'Simple Slideshow';

  @override
  String get description =>
      'A photo slideshow with smooth transitions between scenes';

  @override
  String get difficulty => 'Beginner';

  @override
  String get category => 'Getting Started';

  @override
  List<String> get features => [
    'Video',
    'Multiple Scenes',
    'SceneTransition.crossFade',
    'Background.solid',
  ];

  @override
  List<ExampleParameter> get parameters => [
    ExampleParameter.slider(
      id: 'sceneDuration',
      label: 'Scene Duration (frames)',
      description: 'How long each scene appears',
      defaultValue: 90,
      minValue: 60,
      maxValue: 180,
    ),
    ExampleParameter.slider(
      id: 'transitionDuration',
      label: 'Transition Duration (frames)',
      description: 'Length of the fade transition',
      defaultValue: 30,
      minValue: 15,
      maxValue: 60,
    ),
    ExampleParameter.dropdown(
      id: 'transitionType',
      label: 'Transition Type',
      description: 'Type of transition between scenes',
      defaultValue: 'crossFade',
      options: const [
        DropdownOption(
          value: 'crossFade',
          label: 'Cross Fade',
          description: 'Smooth fade between scenes',
        ),
        DropdownOption(
          value: 'none',
          label: 'None',
          description: 'Instant cut',
        ),
      ],
    ),
    ExampleParameter.color(
      id: 'color1',
      label: 'Color 1',
      description: 'First scene color',
      defaultValue: const Color(0xFFFF6B6B),
    ),
    ExampleParameter.color(
      id: 'color2',
      label: 'Color 2',
      description: 'Second scene color',
      defaultValue: const Color(0xFF4ECDC4),
    ),
    ExampleParameter.color(
      id: 'color3',
      label: 'Color 3',
      description: 'Third scene color',
      defaultValue: const Color(0xFFFFE66D),
    ),
  ];

  @override
  List<String> get instructions => [
    'This example demonstrates how to create a video with multiple scenes.',
    'Each Scene represents a distinct section of your video with its own content.',
    'SceneTransition controls how one scene transitions to the next.',
    'Cross fade smoothly blends between scenes, creating a professional look.',
    'The Video widget automatically handles timing and transitions between scenes.',
    'Try changing transition types and durations to see different effects!',
  ];

  @override
  Widget buildWithParameters(Map<String, dynamic> parameterValues) {
    final sceneDuration =
        (parameterValues['sceneDuration'] as num?)?.toInt() ?? 90;
    final transitionDuration =
        (parameterValues['transitionDuration'] as num?)?.toInt() ?? 30;
    final transitionType =
        parameterValues['transitionType'] as String? ?? 'crossFade';
    final color1 =
        parameterValues['color1'] as Color? ?? const Color(0xFFFF6B6B);
    final color2 =
        parameterValues['color2'] as Color? ?? const Color(0xFF4ECDC4);
    final color3 =
        parameterValues['color3'] as Color? ?? const Color(0xFFFFE66D);

    final transition = _getTransition(transitionType, transitionDuration);

    return Video(
      width: 1920,
      height: 1080,
      fps: 30,
      scenes: [
        // Scene 1
        Scene(
          durationInFrames: sceneDuration,
          background: Background.solid(color1),
          transitionOut: transition,
          children: [
            VCenter(
              child: Text(
                'Scene 1',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),

        // Scene 2
        Scene(
          durationInFrames: sceneDuration,
          background: Background.solid(color2),
          transitionOut: transition,
          children: [
            VCenter(
              child: Text(
                'Scene 2',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),

        // Scene 3
        Scene(
          durationInFrames: sceneDuration,
          background: Background.solid(color3),
          children: [
            VCenter(
              child: Text(
                'Scene 3',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  SceneTransition _getTransition(String type, int duration) {
    switch (type) {
      case 'crossFade':
        return SceneTransition.crossFade(durationInFrames: duration);
      case 'none':
      default:
        return SceneTransition.none();
    }
  }

  @override
  String get sourceCode => '''
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class SimpleSlideshowExample extends InteractiveExample {
  @override
  Widget buildWithParameters(Map<String, dynamic> params) {
    final sceneDuration = params['sceneDuration'] as int;
    final transitionDuration = params['transitionDuration'] as int;
    final color1 = params['color1'] as Color;
    final color2 = params['color2'] as Color;
    final color3 = params['color3'] as Color;

    final transition = SceneTransition.crossFade(
      durationInFrames: transitionDuration,
    );

    return Video(
      width: 1920,
      height: 1080,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: sceneDuration,
          background: Background.solid(color1),
          transitionOut: transition,
          children: [
            VCenter(
              child: Text('Scene 1', style: TextStyle(
                fontSize: 72, color: Colors.white)),
            ),
          ],
        ),
        Scene(
          durationInFrames: sceneDuration,
          background: Background.solid(color2),
          transitionOut: transition,
          children: [
            VCenter(
              child: Text('Scene 2', style: TextStyle(
                fontSize: 72, color: Colors.white)),
            ),
          ],
        ),
        Scene(
          durationInFrames: sceneDuration,
          background: Background.solid(color3),
          children: [
            VCenter(
              child: Text('Scene 3', style: TextStyle(
                fontSize: 72, color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }
}
''';
}
