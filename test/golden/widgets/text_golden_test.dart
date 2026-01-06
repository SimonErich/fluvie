@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

import '../../helpers/golden_helpers.dart';

void main() {
  group('Text Widget Goldens', () {
    group('TypewriterText', () {
      testWidgets('at 0% typed', (tester) async {
        await expectGolden(
          tester,
          const VCenter(
            child: TypewriterText(
              'Hello, World!',
              charsPerSecond: 30,
              style: TextStyle(
                fontSize: 32,
                color: Colors.black,
              ),
            ),
          ),
          name: 'widgets/text/typewriter_0',
          frame: 0,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });

      testWidgets('at 50% typed', (tester) async {
        await expectGolden(
          tester,
          const VCenter(
            child: TypewriterText(
              'Hello, World!',
              charsPerSecond: 30,
              style: TextStyle(
                fontSize: 32,
                color: Colors.black,
              ),
            ),
          ),
          name: 'widgets/text/typewriter_50',
          frame: 7,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });

      testWidgets('at 100% typed', (tester) async {
        await expectGolden(
          tester,
          const VCenter(
            child: TypewriterText(
              'Hello, World!',
              charsPerSecond: 30,
              style: TextStyle(
                fontSize: 32,
                color: Colors.black,
              ),
            ),
          ),
          name: 'widgets/text/typewriter_100',
          frame: 15,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });

      testWidgets('with cursor', (tester) async {
        await expectGolden(
          tester,
          const VCenter(
            child: TypewriterText(
              'Typing...',
              charsPerSecond: 15,
              showCursor: true,
              cursorChar: '|',
              style: TextStyle(
                fontSize: 32,
                color: Colors.black,
              ),
            ),
          ),
          name: 'widgets/text/typewriter_cursor',
          frame: 10,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });
    });

    group('CounterText', () {
      testWidgets('at 0%', (tester) async {
        await expectGolden(
          tester,
          const VCenter(
            child: CounterText(
              value: 1000,
              startValue: 0,
              duration: 60,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          name: 'widgets/text/counter_0',
          frame: 0,
          size: GoldenConfig.smallSize,
          durationInFrames: 90,
        );
      });

      testWidgets('at 50%', (tester) async {
        await expectGolden(
          tester,
          const VCenter(
            child: CounterText(
              value: 1000,
              startValue: 0,
              duration: 60,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          name: 'widgets/text/counter_50',
          frame: 30,
          size: GoldenConfig.smallSize,
          durationInFrames: 90,
        );
      });

      testWidgets('at 100%', (tester) async {
        await expectGolden(
          tester,
          const VCenter(
            child: CounterText(
              value: 1000,
              startValue: 0,
              duration: 60,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          name: 'widgets/text/counter_100',
          frame: 60,
          size: GoldenConfig.smallSize,
          durationInFrames: 90,
        );
      });

      testWidgets('with formatter', (tester) async {
        await expectGolden(
          tester,
          VCenter(
            child: CounterText(
              value: 100,
              startValue: 0,
              duration: 30,
              formatter: (n) => '\$$n k',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
          name: 'widgets/text/counter_formatter',
          frame: 30,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });

      testWidgets('percentage preset', (tester) async {
        await expectGolden(
          tester,
          const VCenter(
            child: CounterText.percentage(
              value: 100,
              duration: 30,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          name: 'widgets/text/counter_percentage',
          frame: 30,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });
    });

    group('DataDrivenText', () {
      testWidgets('renders template', (tester) async {
        await expectGolden(
          tester,
          const VCenter(
            child: DataDrivenText(
              template: 'Hello, {name}!',
              data: {'name': 'World'},
              style: TextStyle(
                fontSize: 32,
                color: Colors.black,
              ),
            ),
          ),
          name: 'widgets/text/data_driven',
          size: GoldenConfig.smallSize,
        );
      });

      testWidgets('with multiple placeholders', (tester) async {
        await expectGolden(
          tester,
          const VCenter(
            child: DataDrivenText(
              template: '{greeting}, {name}! You have {count} messages.',
              data: {
                'greeting': 'Hello',
                'name': 'User',
                'count': '5',
              },
              style: TextStyle(
                fontSize: 24,
                color: Colors.black,
              ),
            ),
          ),
          name: 'widgets/text/data_driven_multiple',
          size: GoldenConfig.smallSize,
        );
      });
    });
  });
}
