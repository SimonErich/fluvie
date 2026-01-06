@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

import '../../helpers/golden_helpers.dart';

void main() {
  group('Animation Widget Goldens', () {
    group('AnimatedProp slideUp', () {
      testWidgets('at 0% progress', (tester) async {
        await expectGolden(
          tester,
          AnimatedProp(
            animation: PropAnimation.slideUp(),
            child: Container(
              width: 200,
              height: 200,
              color: Colors.blue,
              child: const Center(
                child: Text(
                  'Slide Up',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          name: 'widgets/animations/slide_up_0',
          frame: 0,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });

      testWidgets('at 50% progress', (tester) async {
        await expectGolden(
          tester,
          AnimatedProp(
            animation: PropAnimation.slideUp(),
            child: Container(
              width: 200,
              height: 200,
              color: Colors.blue,
              child: const Center(
                child: Text(
                  'Slide Up',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          name: 'widgets/animations/slide_up_50',
          frame: 15,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });

      testWidgets('at 100% progress', (tester) async {
        await expectGolden(
          tester,
          AnimatedProp(
            animation: PropAnimation.slideUp(),
            child: Container(
              width: 200,
              height: 200,
              color: Colors.blue,
              child: const Center(
                child: Text(
                  'Slide Up',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          name: 'widgets/animations/slide_up_100',
          frame: 30,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });
    });

    group('AnimatedProp fadeIn', () {
      testWidgets('at 0% progress', (tester) async {
        await expectGolden(
          tester,
          AnimatedProp(
            animation: PropAnimation.fadeIn(),
            child: Container(
              width: 200,
              height: 200,
              color: Colors.green,
              child: const Center(
                child: Text(
                  'Fade In',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          name: 'widgets/animations/fade_in_0',
          frame: 0,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });

      testWidgets('at 100% progress', (tester) async {
        await expectGolden(
          tester,
          AnimatedProp(
            animation: PropAnimation.fadeIn(),
            child: Container(
              width: 200,
              height: 200,
              color: Colors.green,
              child: const Center(
                child: Text(
                  'Fade In',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          name: 'widgets/animations/fade_in_100',
          frame: 30,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });
    });

    group('AnimatedProp zoomIn', () {
      testWidgets('at 0% progress', (tester) async {
        await expectGolden(
          tester,
          AnimatedProp(
            animation: PropAnimation.zoomIn(),
            child: Container(
              width: 200,
              height: 200,
              color: Colors.red,
              child: const Center(
                child: Text(
                  'Zoom In',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          name: 'widgets/animations/zoom_in_0',
          frame: 0,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });

      testWidgets('at 100% progress', (tester) async {
        await expectGolden(
          tester,
          AnimatedProp(
            animation: PropAnimation.zoomIn(),
            child: Container(
              width: 200,
              height: 200,
              color: Colors.red,
              child: const Center(
                child: Text(
                  'Zoom In',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          name: 'widgets/animations/zoom_in_100',
          frame: 30,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });
    });

    group('Stagger', () {
      testWidgets('staggered children at 0%', (tester) async {
        await expectGolden(
          tester,
          Stagger(
            staggerDelay: 15,
            animationDuration: 15,
            children: [
              Container(
                width: 100,
                height: 50,
                color: Colors.red,
              ),
              Container(
                width: 100,
                height: 50,
                color: Colors.green,
              ),
              Container(
                width: 100,
                height: 50,
                color: Colors.blue,
              ),
            ],
          ),
          name: 'widgets/animations/stagger_0',
          frame: 0,
          size: GoldenConfig.smallSize,
          durationInFrames: 90,
        );
      });

      testWidgets('staggered children at 50%', (tester) async {
        await expectGolden(
          tester,
          Stagger(
            staggerDelay: 15,
            animationDuration: 15,
            children: [
              Container(
                width: 100,
                height: 50,
                color: Colors.red,
              ),
              Container(
                width: 100,
                height: 50,
                color: Colors.green,
              ),
              Container(
                width: 100,
                height: 50,
                color: Colors.blue,
              ),
            ],
          ),
          name: 'widgets/animations/stagger_50',
          frame: 30,
          size: GoldenConfig.smallSize,
          durationInFrames: 90,
        );
      });

      testWidgets('staggered children at 100%', (tester) async {
        await expectGolden(
          tester,
          Stagger(
            staggerDelay: 15,
            animationDuration: 15,
            children: [
              Container(
                width: 100,
                height: 50,
                color: Colors.red,
              ),
              Container(
                width: 100,
                height: 50,
                color: Colors.green,
              ),
              Container(
                width: 100,
                height: 50,
                color: Colors.blue,
              ),
            ],
          ),
          name: 'widgets/animations/stagger_100',
          frame: 60,
          size: GoldenConfig.smallSize,
          durationInFrames: 90,
        );
      });
    });
  });
}
