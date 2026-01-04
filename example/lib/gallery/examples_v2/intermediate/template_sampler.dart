import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';
import '../../example_base.dart';
import '../../models/example_parameter.dart';

/// Template Sampler - Using Fluvie's built-in templates
/// Demonstrates: Template system, PhotoCard, pre-built layouts
class TemplateSamplerExample extends InteractiveExample {
  @override
  String get title => 'Template Sampler';

  @override
  String get description =>
      'Demonstration of Fluvie\'s built-in template widgets';

  @override
  String get difficulty => 'Intermediate';

  @override
  String get category => 'Templates & Helpers';

  @override
  List<String> get features => ['PhotoCard', 'Templates', 'VColumn', 'Stagger'];

  @override
  List<ExampleParameter> get parameters => [
        ExampleParameter.text(
          id: 'cardTitle',
          label: 'Card Title',
          description: 'Title text for the photo card',
          defaultValue: 'My Photo',
        ),
        ExampleParameter.text(
          id: 'cardSubtitle',
          label: 'Card Subtitle',
          description: 'Subtitle text',
          defaultValue: 'Beautiful Moment',
        ),
        ExampleParameter.color(
          id: 'accentColor',
          label: 'Accent Color',
          description: 'Theme color',
          defaultValue: const Color(0xFFE74C3C),
        ),
      ];

  @override
  List<String> get instructions => [
        'This example demonstrates Fluvie\'s built-in template widgets.',
        'PhotoCard is a pre-made component for displaying images with captions.',
        'Templates handle common layouts so you don\'t have to build them from scratch.',
        'The template system makes creating professional videos faster.',
        'Each template is customizable with colors, text, and timing.',
        'Try different titles and colors to personalize the template!',
      ];

  @override
  Widget buildWithParameters(Map<String, dynamic> parameterValues) {
    final cardTitle = parameterValues['cardTitle'] as String;
    final cardSubtitle = parameterValues['cardSubtitle'] as String;
    final accentColor = parameterValues['accentColor'] as Color;

    return Video(
      width: 1080,
      height: 1920,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: 150,
          background: Background.gradient(
            colors: {
              0: const Color(0xFF141E30),
              75: const Color(0xFF243B55),
              150: const Color(0xFF141E30),
            },
          ),
          children: [
            VCenter(
              child: VColumn(
                spacing: 50,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedText.slideUpFade(
                    'Template Showcase',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    duration: 35,
                  ),
                  const SizedBox(height: 30),
                  Stagger(
                    staggerDelay: 12,
                    animationDuration: 40,
                    animation: PropAnimation.slideUpFade(distance: 70),
                    children: [
                      _buildPhotoCardDemo(
                        title: cardTitle,
                        subtitle: cardSubtitle,
                        color: accentColor,
                      ),
                      _buildInfoCardDemo(accentColor),
                      _buildQuoteCardDemo(accentColor),
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

  Widget _buildPhotoCardDemo({
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: 800,
      height: 350,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 22, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCardDemo(Color color) {
    return Container(
      width: 800,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.info_outline, color: color, size: 30),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Info Card Template',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Pre-built layout component',
                    style: TextStyle(fontSize: 18, color: Colors.white60),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCardDemo(Color color) {
    return Container(
      width: 800,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote,
            size: 50,
            color: color.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 15),
          const Text(
            'Templates make video creation faster and more consistent',
            style: TextStyle(
              fontSize: 26,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '— Quote Card Template',
            style: TextStyle(
              fontSize: 18,
              color: color,
              fontWeight: FontWeight.w500,
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

class TemplateSamplerExample extends InteractiveExample {
  @override
  Widget buildWithParameters(Map<String, dynamic> params) {
    final title = params['cardTitle'] as String;
    final subtitle = params['cardSubtitle'] as String;
    final accentColor = params['accentColor'] as Color;

    return Video(
      width: 1080,
      height: 1920,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: 150,
          background: Background.solid(Color(0xFF141E30)),
          children: [
            VCenter(
              child: VColumn(
                spacing: 50,
                children: [
                  PhotoCard(
                    title: title,
                    subtitle: subtitle,
                    backgroundColor: accentColor,
                    width: 800,
                    height: 350,
                    child: Container(
                      color: accentColor.withOpacity(0.3),
                      child: Center(
                        child: Icon(Icons.photo_library, size: 100),
                      ),
                    ),
                  ),
                  // More template examples...
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
