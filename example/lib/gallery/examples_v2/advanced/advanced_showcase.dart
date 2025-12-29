import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';
import '../../example_base.dart';
import '../../models/example_parameter.dart';

/// Advanced Showcase - Multi-scene composition with complex animations
/// Demonstrates: Multiple scenes, transitions, complex layouts, all features combined
class AdvancedShowcaseExample extends InteractiveExample {
  @override
  String get title => 'Advanced Showcase';

  @override
  String get description =>
      'Multi-scene video combining all intermediate techniques';

  @override
  String get difficulty => 'Advanced';

  @override
  String get category => 'Complete Examples';

  @override
  List<String> get features => [
        'Multi-scene',
        'Scene transitions',
        'Complex animations',
        'All widgets combined',
      ];

  @override
  List<ExampleParameter> get parameters => [
        ExampleParameter.text(
          id: 'projectName',
          label: 'Project Name',
          description: 'Name of your project',
          defaultValue: 'Fluvie',
        ),
        ExampleParameter.text(
          id: 'tagline',
          label: 'Tagline',
          description: 'Project tagline',
          defaultValue: 'Create Videos with Flutter',
        ),
        ExampleParameter.color(
          id: 'brandColor',
          label: 'Brand Color',
          description: 'Primary brand color',
          defaultValue: const Color(0xFF6C5CE7),
        ),
      ];

  @override
  List<String> get instructions => [
        'This advanced example combines multiple scenes into a complete video.',
        'Scene 1: Animated title with particle-like elements.',
        'Scene 2: Feature showcase with staggered entry.',
        'Scene 3: Statistics dashboard with counters.',
        'Scene transitions create smooth flow between sections.',
        'This demonstrates how to build complete, production-ready videos!',
      ];

  @override
  Widget buildWithParameters(Map<String, dynamic> parameterValues) {
    final projectName = parameterValues['projectName'] as String;
    final tagline = parameterValues['tagline'] as String;
    final brandColor = parameterValues['brandColor'] as Color;

    return Video(
      width: 1920,
      height: 1080,
      fps: 30,
      scenes: [
        // Scene 1: Opening title
        _buildTitleScene(projectName, tagline, brandColor),

        // Scene 2: Features showcase
        _buildFeaturesScene(brandColor),

        // Scene 3: Stats dashboard
        _buildStatsScene(brandColor),
      ],
    );
  }

  Scene _buildTitleScene(String projectName, String tagline, Color brandColor) {
    return Scene(
      durationInFrames: 90,
      background: Background.gradient(
        colors: {
          0: const Color(0xFF0F0C29),
          45: const Color(0xFF302B63),
          90: const Color(0xFF24243E),
        },
        type: GradientType.radial,
      ),
      transitionOut: SceneTransition.crossFade(durationInFrames: 15),
      children: [
        // Animated background elements
        VStack(
          children: List.generate(5, (i) {
            return AnimatedProp(
              startFrame: i * 3,
              duration: 50,
              animation: PropAnimation.combine([
                PropAnimation.scale(start: 0.0, end: 1.0),
                PropAnimation.fadeIn(),
              ]),
              curve: Curves.elasticOut,
              child: Positioned(
                left: 200.0 + (i * 300.0),
                top: 100.0 + (i * 150.0) % 900,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        ),
        // Title
        VCenter(
          child: VColumn(
            spacing: 20,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedText.slideUpFade(
                projectName,
                style: TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.bold,
                  color: brandColor,
                  letterSpacing: 2,
                ),
                startFrame: 15,
                duration: 40,
              ),
              AnimatedText.fadeIn(
                tagline,
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.white70,
                  fontWeight: FontWeight.w300,
                ),
                startFrame: 35,
                duration: 30,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Scene _buildFeaturesScene(Color brandColor) {
    final features = [
      ('Declarative API', Icons.code),
      ('Beautiful Animations', Icons.animation),
      ('Easy to Use', Icons.check_circle),
    ];

    return Scene(
      durationInFrames: 90,
      background: Background.gradient(
        colors: {
          0: const Color(0xFF24243E),
          90: const Color(0xFF0F0C29),
        },
      ),
      transitionOut: SceneTransition.crossFade(durationInFrames: 15),
      children: [
        VCenter(
          child: VColumn(
            spacing: 40,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedText.slideUpFade(
                'Key Features',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                duration: 30,
              ),
              const SizedBox(height: 20),
              Stagger(
                staggerDelay: 10,
                animationDuration: 35,
                animation: PropAnimation.slideUpFade(distance: 50),
                children: features.map((feature) {
                  return Container(
                    width: 600,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: brandColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(feature.$2, size: 50, color: brandColor),
                        const SizedBox(width: 20),
                        Text(
                          feature.$1,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Scene _buildStatsScene(Color brandColor) {
    return Scene(
      durationInFrames: 90,
      background: Background.gradient(
        colors: {
          0: const Color(0xFF0F0C29),
          90: const Color(0xFF302B63),
        },
      ),
      children: [
        VCenter(
          child: VColumn(
            spacing: 50,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedText.slideUpFade(
                'Growing Fast',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                duration: 30,
              ),
              Stagger(
                staggerDelay: 12,
                animationDuration: 40,
                animation: PropAnimation.slideUpFade(),
                children: [
                  _buildStatCard('Downloads', 5000, brandColor),
                  _buildStatCard('Stars', 1200, const Color(0xFFFFD700)),
                  _buildStatCard('Contributors', 45, const Color(0xFF00D9FF)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Container(
      width: 500,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 10),
          CounterText(
            value: value,
            duration: 45,
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  String get sourceCode => '''
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class AdvancedShowcaseExample extends InteractiveExample {
  @override
  Widget buildWithParameters(Map<String, dynamic> params) {
    final projectName = params['projectName'] as String;
    final brandColor = params['brandColor'] as Color;

    return Video(
      width: 1920,
      height: 1080,
      fps: 30,
      scenes: [
        // Title scene
        Scene(
          durationInFrames: 90,
          background: Background.gradient(
            colors: {0: Color(0xFF0F0C29), 90: Color(0xFF24243E)},
          ),
          transitionOut: SceneTransition.crossFade(durationInFrames: 15),
          children: [
            VCenter(
              child: AnimatedText.slideUpFade(
                projectName,
                style: TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.bold,
                  color: brandColor,
                ),
                duration: 40,
              ),
            ),
          ],
        ),
        // Features scene
        Scene(
          durationInFrames: 90,
          background: Background.solid(Color(0xFF24243E)),
          children: [
            VCenter(
              child: VColumn(
                children: [
                  AnimatedText('Features', style: TextStyle(fontSize: 56)),
                  Stagger(
                    staggerDelay: 10,
                    children: [
                      Text('Feature 1'),
                      Text('Feature 2'),
                      Text('Feature 3'),
                    ],
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
