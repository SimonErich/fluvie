import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';
import '../../example_base.dart';
import '../../models/example_parameter.dart';

/// Entry Effects Gallery - Showcase of different entry animations
/// Demonstrates: Various entry effects, AnimatedProp, staggered timing
class EntryEffectsGalleryExample extends InteractiveExample {
  @override
  String get title => 'Entry Effects Gallery';

  @override
  String get description =>
      'Showcase of different entry animation styles side-by-side';

  @override
  String get difficulty => 'Intermediate';

  @override
  String get category => 'Animation & Effects';

  @override
  List<String> get features => [
        'AnimatedProp',
        'Entry effects',
        'VRow',
        'Multiple animations',
      ];

  @override
  List<ExampleParameter> get parameters => [
        ExampleParameter.slider(
          id: 'animationDuration',
          label: 'Animation Duration (frames)',
          description: 'How long each entry animation lasts',
          defaultValue: 45,
          minValue: 20,
          maxValue: 90,
        ),
        ExampleParameter.dropdown(
          id: 'easingCurve',
          label: 'Easing Curve',
          description: 'Animation easing style',
          defaultValue: 'easeOut',
          options: const [
            DropdownOption(value: 'easeOut', label: 'Ease Out'),
            DropdownOption(value: 'bounceOut', label: 'Bounce Out'),
            DropdownOption(value: 'elasticOut', label: 'Elastic Out'),
          ],
        ),
      ];

  @override
  List<String> get instructions => [
        'This gallery demonstrates different entry animation effects.',
        'Each box shows a distinct animation: Slide Up, Slide Down, Scale, Rotate, and Fade.',
        'All animations start at the same time to allow easy comparison.',
        'AnimatedProp applies the property animations to standard Flutter widgets.',
        'Different curves create different feels - bounce, elastic, and ease all have unique character.',
        'Experiment with duration and curves to find the perfect timing!',
      ];

  @override
  Widget buildWithParameters(Map<String, dynamic> parameterValues) {
    final animationDuration =
        (parameterValues['animationDuration'] as num).toInt();
    final easingCurve = parameterValues['easingCurve'] as String;
    final curve = _getCurve(easingCurve);

    final effects = [
      ('Slide Up', PropAnimation.slideUpFade(distance: 100)),
      (
        'Slide Down',
        PropAnimation.combine([
          PropAnimation.translate(
            start: const Offset(0, -100),
            end: Offset.zero,
          ),
          PropAnimation.fadeIn(),
        ]),
      ),
      (
        'Scale In',
        PropAnimation.combine([
          PropAnimation.scale(start: 0.0, end: 1.0),
          PropAnimation.fadeIn(),
        ]),
      ),
      (
        'Rotate In',
        PropAnimation.combine([
          PropAnimation.rotate(start: -1.57, end: 0), // -π/2 to 0
          PropAnimation.fadeIn(),
        ]),
      ),
      ('Fade In', PropAnimation.fadeIn()),
    ];

    return Video(
      width: 1920,
      height: 1080,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: 150,
          background: Background.gradient(
            colors: {0: const Color(0xFF1A1A2E), 150: const Color(0xFF16213E)},
          ),
          children: [
            VCenter(
              child: VRow(
                spacing: 30,
                mainAxisAlignment: MainAxisAlignment.center,
                children: effects.map((effect) {
                  return _buildEffectBox(
                    label: effect.$1,
                    animation: effect.$2,
                    duration: animationDuration,
                    curve: curve,
                  );
                }).toList(),
              ),
            ),
            VStack(
              startFrame: 90,
              fadeInFrames: 15,
              children: [
                VPositioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedText.slideUpFade(
                      'Entry Effects Gallery',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      duration: 30,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEffectBox({
    required String label,
    required PropAnimation animation,
    required int duration,
    required Curve curve,
  }) {
    return AnimatedProp(
      startFrame: 20,
      duration: duration,
      animation: animation,
      curve: curve,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Curve _getCurve(String curveName) {
    switch (curveName) {
      case 'easeOut':
        return Curves.easeOut;
      case 'bounceOut':
        return Curves.bounceOut;
      case 'elasticOut':
        return Curves.elasticOut;
      default:
        return Curves.easeOut;
    }
  }

  @override
  String get sourceCode => '''
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class EntryEffectsGalleryExample extends InteractiveExample {
  @override
  Widget buildWithParameters(Map<String, dynamic> params) {
    final duration = params['animationDuration'] as int;

    final effects = [
      ('Slide Up', PropAnimation.slideUpFade(distance: 100)),
      ('Scale In', PropAnimation.combine([
        PropAnimation.scale(start: 0.0, end: 1.0),
        PropAnimation.fadeIn(),
      ])),
      ('Rotate In', PropAnimation.combine([
        PropAnimation.rotate(start: -1.57, end: 0),
        PropAnimation.fadeIn(),
      ])),
    ];

    return Video(
      width: 1920,
      height: 1080,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: 150,
          background: Background.solid(Color(0xFF1A1A2E)),
          children: [
            VCenter(
              child: VRow(
                spacing: 30,
                children: effects.map((effect) {
                  return AnimatedProp(
                    startFrame: 20,
                    duration: duration,
                    animation: effect.\$2,
                    curve: Curves.easeOut,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(child: Text(effect.\$1)),
                    ),
                  );
                }).toList(),
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
