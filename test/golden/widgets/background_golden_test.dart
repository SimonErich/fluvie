@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

import '../../helpers/golden_helpers.dart';

void main() {
  group('Background Widget Goldens', () {
    group('Background.solid', () {
      testWidgets('solid color', (tester) async {
        await expectGolden(
          tester,
          Builder(
            builder: (context) {
              return Background.solid(Colors.deepPurple).build(context, 60);
            },
          ),
          name: 'widgets/background/solid',
          size: GoldenConfig.smallSize,
        );
      });
    });

    group('Background.gradient', () {
      testWidgets('linear gradient with keyframes', (tester) async {
        await expectGolden(
          tester,
          Builder(
            builder: (context) {
              return Background.gradient(
                colors: {0: Colors.blue, 60: Colors.purple},
                type: GradientType.linear,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).build(context, 90);
            },
          ),
          name: 'widgets/background/gradient_linear',
          frame: 30,
          size: GoldenConfig.smallSize,
          durationInFrames: 90,
        );
      });

      testWidgets('radial gradient', (tester) async {
        await expectGolden(
          tester,
          Builder(
            builder: (context) {
              return Background.radial(
                centerColor: Colors.yellow,
                edgeColor: Colors.red,
              ).build(context, 60);
            },
          ),
          name: 'widgets/background/gradient_radial',
          size: GoldenConfig.smallSize,
        );
      });
    });

    group('AnimatedGradient', () {
      testWidgets('at frame 0', (tester) async {
        await expectGolden(
          tester,
          AnimatedGradient(
            startColors: {0: Colors.red, 60: Colors.blue},
            endColors: {0: Colors.orange, 60: Colors.purple},
          ),
          name: 'widgets/background/animated_gradient_0',
          frame: 0,
          size: GoldenConfig.smallSize,
          durationInFrames: 90,
        );
      });

      testWidgets('at frame 30', (tester) async {
        await expectGolden(
          tester,
          AnimatedGradient(
            startColors: {0: Colors.red, 60: Colors.blue},
            endColors: {0: Colors.orange, 60: Colors.purple},
          ),
          name: 'widgets/background/animated_gradient_30',
          frame: 30,
          size: GoldenConfig.smallSize,
          durationInFrames: 90,
        );
      });

      testWidgets('at frame 60', (tester) async {
        await expectGolden(
          tester,
          AnimatedGradient(
            startColors: {0: Colors.red, 60: Colors.blue},
            endColors: {0: Colors.orange, 60: Colors.purple},
          ),
          name: 'widgets/background/animated_gradient_60',
          frame: 60,
          size: GoldenConfig.smallSize,
          durationInFrames: 90,
        );
      });

      testWidgets('radial type', (tester) async {
        await expectGolden(
          tester,
          AnimatedGradient(
            startColors: {0: Colors.cyan, 60: Colors.teal},
            endColors: {0: Colors.blue, 60: Colors.indigo},
            type: AnimatedGradientType.radial,
            radius: 0.8,
          ),
          name: 'widgets/background/animated_gradient_radial',
          frame: 30,
          size: GoldenConfig.smallSize,
          durationInFrames: 90,
        );
      });

      testWidgets('sweep type', (tester) async {
        await expectGolden(
          tester,
          AnimatedGradient(
            startColors: {0: Colors.pink, 60: Colors.purple},
            endColors: {0: Colors.amber, 60: Colors.deepOrange},
            type: AnimatedGradientType.sweep,
          ),
          name: 'widgets/background/animated_gradient_sweep',
          frame: 30,
          size: GoldenConfig.smallSize,
          durationInFrames: 90,
        );
      });
    });

    group('Background.noise', () {
      testWidgets('default noise', (tester) async {
        await expectGolden(
          tester,
          Builder(
            builder: (context) {
              return Background.noise().build(context, 60);
            },
          ),
          name: 'widgets/background/noise_default',
          size: GoldenConfig.smallSize,
        );
      });

      testWidgets('high intensity', (tester) async {
        await expectGolden(
          tester,
          Builder(
            builder: (context) {
              return Background.noise(
                intensity: 0.3,
                color: Colors.white,
              ).build(context, 60);
            },
          ),
          name: 'widgets/background/noise_high',
          size: GoldenConfig.smallSize,
        );
      });
    });

    group('Background.vhs', () {
      testWidgets('default vhs effect', (tester) async {
        await expectGolden(
          tester,
          Builder(
            builder: (context) {
              return Background.vhs().build(context, 60);
            },
          ),
          name: 'widgets/background/vhs_default',
          size: GoldenConfig.smallSize,
        );
      });

      testWidgets('with all effects', (tester) async {
        await expectGolden(
          tester,
          Builder(
            builder: (context) {
              return Background.vhs(
                showScanlines: true,
                showChromatic: true,
                showTracking: true,
                intensity: 0.8,
              ).build(context, 60);
            },
          ),
          name: 'widgets/background/vhs_full',
          size: GoldenConfig.smallSize,
        );
      });
    });
  });
}
