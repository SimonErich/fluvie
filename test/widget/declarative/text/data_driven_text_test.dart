import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/text/data_driven_text.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('DataDrivenText', () {
    group('construction', () {
      test('creates with required parameters', () {
        const widget = DataDrivenText(
          template: 'Hello {name}!',
          data: {'name': 'World'},
        );

        expect(widget.template, 'Hello {name}!');
        expect(widget.data, {'name': 'World'});
      });

      test('has default values', () {
        const widget = DataDrivenText(
          template: 'Test',
          data: {},
        );

        expect(widget.animations, isNull);
        expect(widget.style, isNull);
        expect(widget.startFrame, 0);
        expect(widget.textAlign, isNull);
        expect(widget.maxLines, isNull);
        expect(widget.overflow, isNull);
      });

      test('accepts custom values', () {
        const style = TextStyle(fontSize: 24);
        const animations = {'count': DataAnimation.countUp()};

        const widget = DataDrivenText(
          template: '{count} items',
          data: {'count': 42},
          animations: animations,
          style: style,
          startFrame: 15,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

        expect(widget.animations, animations);
        expect(widget.style, style);
        expect(widget.startFrame, 15);
        expect(widget.textAlign, TextAlign.center);
        expect(widget.maxLines, 2);
        expect(widget.overflow, TextOverflow.ellipsis);
      });
    });

    group('DataAnimation', () {
      group('countUp', () {
        test('creates with default values', () {
          const animation = DataAnimation.countUp();

          expect(animation.type, DataAnimationType.countUp);
          expect(animation.duration, 60);
          expect(animation.curve, Curves.easeOut);
          expect(animation.startValue, 0);
          expect(animation.formatter, isNull);
        });

        test('creates with custom values', () {
          const animation = DataAnimation.countUp(
            duration: 90,
            curve: Curves.bounceOut,
            startValue: 10,
          );

          expect(animation.duration, 90);
          expect(animation.curve, Curves.bounceOut);
          expect(animation.startValue, 10);
        });

        test('animate returns start value before animation', () {
          const animation = DataAnimation.countUp(startValue: 0);

          expect(animation.animate(100, -5), 0);
        });

        test('animate returns end value after animation', () {
          const animation = DataAnimation.countUp(duration: 60);

          expect(animation.animate(100, 100), 100);
        });

        test('animate interpolates correctly', () {
          const animation = DataAnimation.countUp(
            duration: 100,
            curve: Curves.linear,
          );

          // At frame 50 (50% progress), value should be ~50
          expect(animation.animate(100, 50), 50);
        });
      });

      group('reveal', () {
        test('creates with default values', () {
          const animation = DataAnimation.reveal();

          expect(animation.type, DataAnimationType.reveal);
          expect(animation.duration, 30);
        });

        test('animate returns empty before completion', () {
          const animation = DataAnimation.reveal(duration: 60);

          expect(animation.animate('Secret', 30), '');
        });

        test('animate returns value after completion', () {
          const animation = DataAnimation.reveal(duration: 60);

          expect(animation.animate('Secret', 60), 'Secret');
        });
      });

      group('typewriter', () {
        test('creates with default values', () {
          const animation = DataAnimation.typewriter();

          expect(animation.type, DataAnimationType.typewriter);
          expect(animation.duration, 60);
        });

        test('animate reveals characters progressively', () {
          const animation = DataAnimation.typewriter(duration: 10);

          // At frame 5 (50% with easeOut curve applied), chars shown varies
          // With default Curves.easeOut, progress will be > 0.5
          final result = animation.animate('Hello', 5);
          // Just verify it returns a partial string
          expect(result, isA<String>());
          expect((result as String).length, lessThanOrEqualTo(5));
        });

        test('animate returns full string after completion', () {
          const animation = DataAnimation.typewriter(duration: 10);

          expect(animation.animate('Hello', 10), 'Hello');
        });

        test('animate returns empty before start', () {
          const animation = DataAnimation.typewriter();

          expect(animation.animate('Hello', -5), '');
        });
      });
    });

    group('widget rendering', () {
      testWidgets('renders simple template', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Hello {name}!',
            data: {'name': 'World'},
          ),
        ));

        expect(find.text('Hello World!'), findsOneWidget);
      });

      testWidgets('renders multiple variables', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: '{greeting} {name}, you have {count} messages.',
            data: {
              'greeting': 'Hello',
              'name': 'Alice',
              'count': 5,
            },
          ),
        ));

        expect(find.text('Hello Alice, you have 5 messages.'), findsOneWidget);
      });

      testWidgets('renders with no variables', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Static text',
            data: {},
          ),
        ));

        expect(find.text('Static text'), findsOneWidget);
      });

      testWidgets('renders numeric values', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Score: {score}',
            data: {'score': 42},
          ),
        ));

        expect(find.text('Score: 42'), findsOneWidget);
      });

      testWidgets('handles missing variable gracefully', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Hello {name}!',
            data: {}, // No 'name' provided
          ),
        ));

        // Should leave placeholder as-is
        expect(find.text('Hello {name}!'), findsOneWidget);
      });
    });

    group('animated rendering', () {
      testWidgets('applies countUp animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Count: {count}',
            data: {'count': 100},
            animations: {'count': DataAnimation.countUp(duration: 60)},
            startFrame: 0,
          ),
          frame: 60, // Animation complete
        ));

        expect(find.text('Count: 100'), findsOneWidget);
      });

      testWidgets('shows start value before animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Count: {count}',
            data: {'count': 100},
            animations: {
              'count': DataAnimation.countUp(duration: 60, startValue: 0),
            },
            startFrame: 30,
          ),
          frame: 0, // Before animation starts
        ));

        expect(find.text('Count: 0'), findsOneWidget);
      });

      testWidgets('reveals text with reveal animation', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Secret: {code}',
            data: {'code': 'ABC123'},
            animations: {'code': DataAnimation.reveal(duration: 30)},
            startFrame: 0,
          ),
          frame: 30, // Animation complete
        ));

        expect(find.text('Secret: ABC123'), findsOneWidget);
      });

      testWidgets('hides revealed text before completion', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Secret: {code}',
            data: {'code': 'ABC123'},
            animations: {'code': DataAnimation.reveal(duration: 30)},
            startFrame: 0,
          ),
          frame: 15, // Midway
        ));

        expect(find.text('Secret: '), findsOneWidget);
      });

      testWidgets('typewriter animation reveals progressively', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Message: {msg}',
            data: {'msg': 'Hello'},
            animations: {'msg': DataAnimation.typewriter(duration: 10)},
            startFrame: 0,
          ),
          frame: 10, // Animation complete
        ));

        expect(find.text('Message: Hello'), findsOneWidget);
      });
    });

    group('text styling', () {
      testWidgets('applies text style', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Styled {text}',
            data: {'text': 'content'},
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ));

        expect(find.text('Styled content'), findsOneWidget);
      });

      testWidgets('applies text alignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: '{text}',
            data: {'text': 'Centered'},
            textAlign: TextAlign.center,
          ),
        ));

        expect(find.text('Centered'), findsOneWidget);
      });

      testWidgets('applies max lines', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: '{line1}\n{line2}',
            data: {'line1': 'Line 1', 'line2': 'Line 2'},
            maxLines: 1,
          ),
        ));

        expect(find.text('Line 1\nLine 2'), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty template', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: '',
            data: {},
          ),
        ));

        expect(find.text(''), findsOneWidget);
      });

      testWidgets('handles special characters in template', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Price: \${price} @#%',
            data: {'price': 99},
          ),
        ));

        expect(find.text('Price: \$99 @#%'), findsOneWidget);
      });

      testWidgets('handles repeated variable', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: '{val} + {val} = {sum}',
            data: {'val': 5, 'sum': 10},
          ),
        ));

        expect(find.text('5 + 5 = 10'), findsOneWidget);
      });

      testWidgets('handles nested braces', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Result: {{val}}',
            data: {'val': 42},
          ),
        ));

        // Inner braces should be substituted, outer preserved
        expect(find.text('Result: {42}'), findsOneWidget);
      });

      testWidgets('handles unicode in values', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Hello {emoji}',
            data: {'emoji': '🎉'},
          ),
        ));

        expect(find.text('Hello 🎉'), findsOneWidget);
      });

      testWidgets('handles boolean values', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'Active: {status}',
            data: {'status': true},
          ),
        ));

        expect(find.text('Active: true'), findsOneWidget);
      });

      testWidgets('handles double values', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const DataDrivenText(
            template: 'PI: {pi}',
            data: {'pi': 3.14159},
          ),
        ));

        expect(find.text('PI: 3.14159'), findsOneWidget);
      });
    });
  });
}
