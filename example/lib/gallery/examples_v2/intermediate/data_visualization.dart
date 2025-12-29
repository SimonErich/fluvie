import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';
import '../../example_base.dart';
import '../../models/example_parameter.dart';

/// Data Visualization - Animated statistics and counters
/// Demonstrates: CounterText, animated charts, data presentation
class DataVisualizationExample extends InteractiveExample {
  @override
  String get title => 'Data Visualization';

  @override
  String get description =>
      'Animated statistics dashboard with counters and progress bars';

  @override
  String get difficulty => 'Intermediate';

  @override
  String get category => 'Data & Charts';

  @override
  List<String> get features => [
    'CounterText',
    'Animated bars',
    'VColumn',
    'Stagger',
  ];

  @override
  List<ExampleParameter> get parameters => [
    ExampleParameter.slider(
      id: 'targetValue1',
      label: 'Metric 1 Target',
      description: 'First metric value',
      defaultValue: 1234,
      minValue: 100,
      maxValue: 9999,
    ),
    ExampleParameter.slider(
      id: 'targetValue2',
      label: 'Metric 2 Target',
      description: 'Second metric value',
      defaultValue: 567,
      minValue: 100,
      maxValue: 9999,
    ),
    ExampleParameter.slider(
      id: 'targetValue3',
      label: 'Metric 3 Target',
      description: 'Third metric value',
      defaultValue: 890,
      minValue: 100,
      maxValue: 9999,
    ),
  ];

  @override
  List<String> get instructions => [
    'This example demonstrates data visualization in Fluvie.',
    'CounterText animates numbers smoothly from 0 to the target value.',
    'Stagger creates a cascading reveal of metrics for visual interest.',
    'Progress bars use AnimatedProp to grow from 0% to their target width.',
    'The combination creates an engaging data dashboard animation.',
    'Adjust target values to see how the animation adapts!',
  ];

  @override
  Widget buildWithParameters(Map<String, dynamic> parameterValues) {
    final target1 = (parameterValues['targetValue1'] as num).toInt();
    final target2 = (parameterValues['targetValue2'] as num).toInt();
    final target3 = (parameterValues['targetValue3'] as num).toInt();

    final metrics = [
      ('Active Users', target1, Colors.blue),
      ('Downloads', target2, Colors.green),
      ('Reviews', target3, Colors.orange),
    ];

    return Video(
      width: 1080,
      height: 1920,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: 150,
          background: Background.gradient(
            colors: {0: const Color(0xFF0F0C29), 150: const Color(0xFF24243E)},
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          children: [
            VStack(
              startFrame: 10,
              fadeInFrames: 15,
              children: [
                VCenter(
                  child: VColumn(
                    spacing: 60,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedText.slideUpFade(
                        'Statistics Dashboard',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        duration: 30,
                      ),
                      const SizedBox(height: 40),
                      Stagger(
                        staggerDelay: 15,
                        animationDuration: 40,
                        animation: PropAnimation.slideUpFade(distance: 60),
                        children: metrics.map((metric) {
                          return _buildMetricCard(
                            label: metric.$1,
                            value: metric.$2,
                            color: metric.$3,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required int value,
    required Color color,
  }) {
    final percentage = (value / 10000 * 100).clamp(0, 100);

    return Container(
      width: 800,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 15),
          CounterText(
            value: value,
            duration: 50,
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            formatter: (n) => n.toString(),
          ),
          const SizedBox(height: 20),
          AnimatedProp(
            duration: 50,
            animation: PropAnimation.scale(
              start: 0.0,
              end: 1.0,
              alignment: Alignment.centerLeft,
            ),
            child: Container(
              height: 12,
              width: percentage / 100 * 740,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.6)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
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

class DataVisualizationExample extends InteractiveExample {
  @override
  Widget buildWithParameters(Map<String, dynamic> params) {
    final target1 = params['targetValue1'] as int;
    final target2 = params['targetValue2'] as int;
    final target3 = params['targetValue3'] as int;

    final metrics = [
      ('Active Users', target1, Colors.blue),
      ('Downloads', target2, Colors.green),
      ('Reviews', target3, Colors.orange),
    ];

    return Video(
      width: 1080,
      height: 1920,
      fps: 30,
      scenes: [
        Scene(
          durationInFrames: 150,
          background: Background.gradient(
            colors: {0: Color(0xFF0F0C29), 150: Color(0xFF24243E)},
          ),
          children: [
            VCenter(
              child: VColumn(
                spacing: 60,
                children: [
                  AnimatedText.slideUpFade(
                    'Statistics Dashboard',
                    style: TextStyle(fontSize: 48, color: Colors.white),
                    duration: 30,
                  ),
                  Stagger(
                    staggerDelay: 15,
                    animationDuration: 40,
                    animation: PropAnimation.slideUpFade(),
                    children: metrics.map((m) => Container(
                      width: 800,
                      padding: EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Text(m.\$1),
                          CounterText(
                            value: m.\$2,
                            duration: 50,
                            style: TextStyle(fontSize: 56, color: m.\$3),
                          ),
                        ],
                      ),
                    )).toList(),
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
