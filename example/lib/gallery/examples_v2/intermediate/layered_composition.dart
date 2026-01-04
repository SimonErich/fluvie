import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';
import '../../example_base.dart';
import '../../models/example_parameter.dart';

/// Layered Composition - Multiple layers with staggered animations
/// Demonstrates: VStack, Stagger, depth through layering
class LayeredCompositionExample extends InteractiveExample {
  @override
  String get title => 'Layered Composition';

  @override
  String get description =>
      'Multiple animated layers with staggered timing creating depth';

  @override
  String get difficulty => 'Intermediate';

  @override
  String get category => 'Animation & Effects';

  @override
  List<String> get features => [
        'VStack',
        'Stagger',
        'Multiple layers',
        'AnimatedProp',
      ];

  @override
  List<ExampleParameter> get parameters => [
        ExampleParameter.slider(
          id: 'layerCount',
          label: 'Layer Count',
          description: 'Number of layers',
          defaultValue: 5,
          minValue: 3,
          maxValue: 8,
        ),
        ExampleParameter.slider(
          id: 'staggerDelay',
          label: 'Stagger Delay (frames)',
          description: 'Delay between each layer animation',
          defaultValue: 8,
          minValue: 3,
          maxValue: 15,
        ),
        ExampleParameter.color(
          id: 'accentColor',
          label: 'Accent Color',
          description: 'Primary color for layers',
          defaultValue: const Color(0xFF6C5CE7),
        ),
      ];

  @override
  List<String> get instructions => [
        'This example demonstrates layered composition with depth in Fluvie.',
        'VStack overlays multiple widgets to create depth and dimensionality.',
        'Stagger creates cascading animations where each layer starts slightly after the previous.',
        'Layers are sized and positioned to create a sense of perspective.',
        'Different animation speeds and opacities enhance the depth effect.',
        'Adjust stagger delay to control the rhythm of the cascade!',
      ];

  @override
  Widget buildWithParameters(Map<String, dynamic> parameterValues) {
    final layerCount = (parameterValues['layerCount'] as num).toInt();
    final staggerDelay = (parameterValues['staggerDelay'] as num).toInt();
    final accentColor = parameterValues['accentColor'] as Color;

    return Video(
      width: 1920,
      height: 1080,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: 180,
          background: Background.gradient(
            colors: {
              0: const Color(0xFF0F2027),
              90: const Color(0xFF203A43),
              180: const Color(0xFF2C5364),
            },
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          children: [
            // Staggered layers
            VStack(
              children: [
                Stagger(
                  staggerDelay: staggerDelay,
                  animationDuration: 50,
                  animation: PropAnimation.combine([
                    PropAnimation.slideUp(distance: 80),
                    PropAnimation.scale(start: 0.5, end: 1.0),
                    PropAnimation.fadeIn(),
                  ]),
                  curve: Curves.elasticOut,
                  children: List.generate(layerCount, (index) {
                    return _buildLayer(
                      index: index,
                      total: layerCount,
                      accentColor: accentColor,
                    );
                  }),
                ),
              ],
            ),
            // Title overlay
            VStack(
              startFrame: 40,
              fadeInFrames: 20,
              children: [
                VCenter(
                  child: AnimatedText.slideUpFade(
                    'Layered Composition',
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    duration: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLayer({
    required int index,
    required int total,
    required Color accentColor,
  }) {
    // Calculate size (back layers are smaller)
    final sizeFactor = 0.4 + (total - index) / total * 0.6;
    final size = 300.0 * sizeFactor;

    // Calculate opacity (back layers are more transparent)
    final opacity = 0.4 + (total - index) / total * 0.4;

    // Calculate color
    final hue = (accentColor.computeLuminance() * 360 + index * 50) % 360;
    final color = HSVColor.fromAHSV(opacity, hue, 0.7, 0.9).toColor();

    // Calculate position
    final leftOffset = 200.0 + (index * 100.0);
    final topOffset = 100.0 + (index * 80.0);

    return Positioned(
      left: leftOffset,
      top: topOffset,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: index % 2 == 0 ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: index % 2 == 1 ? BorderRadius.circular(40) : null,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 40,
              spreadRadius: 15,
            ),
          ],
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: size * 0.3,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }

  @override
  String get sourceCode => '''
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class LayeredCompositionExample extends InteractiveExample {
  @override
  Widget buildWithParameters(Map<String, dynamic> params) {
    final layerCount = params['layerCount'] as int;
    final staggerDelay = params['staggerDelay'] as int;

    return Video(
      width: 1920,
      height: 1080,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: 180,
          background: Background.gradient(
            colors: {
              0: Color(0xFF0F2027),
              90: Color(0xFF203A43),
              180: Color(0xFF2C5364),
            },
          ),
          children: [
            VStack(
              children: [
                Stagger(
                  staggerFrames: staggerDelay,
                  children: List.generate(layerCount, (index) {
                    final size = 300.0 * (0.4 + (layerCount - index) / layerCount * 0.6);
                    final opacity = 0.4 + (layerCount - index) / layerCount * 0.4;

                    return AnimatedProp(
                      duration: 50,
                      animation: PropAnimation.combine([
                        PropAnimation.slideUp(distance: 80),
                        PropAnimation.scale(start: 0.5, end: 1.0),
                        PropAnimation.fadeIn(),
                      ]),
                      curve: Curves.elasticOut,
                      child: Positioned(
                        left: 200.0 + (index * 100.0),
                        top: 100.0 + (index * 80.0),
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(opacity),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
''';
}
