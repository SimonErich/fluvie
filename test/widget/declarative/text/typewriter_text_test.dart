import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/text/typewriter_text.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('TypewriterText', () {
    group('construction', () {
      test('creates with required text', () {
        const widget = TypewriterText('Hello World');

        expect(widget.text, 'Hello World');
      });

      test('has default values', () {
        const widget = TypewriterText('Test');

        expect(widget.style, isNull);
        expect(widget.startFrame, 0);
        expect(widget.charsPerSecond, 15);
        expect(widget.showCursor, isTrue);
        expect(widget.cursorChar, '|');
        expect(widget.cursorBlinkFrames, 15);
        expect(widget.textAlign, isNull);
        expect(widget.maxLines, isNull);
        expect(widget.overflow, isNull);
      });

      test('accepts custom values', () {
        const style = TextStyle(fontSize: 24);
        const widget = TypewriterText(
          'Custom',
          style: style,
          startFrame: 10,
          charsPerSecond: 20,
          showCursor: false,
          cursorChar: '_',
          cursorBlinkFrames: 10,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

        expect(widget.text, 'Custom');
        expect(widget.style, style);
        expect(widget.startFrame, 10);
        expect(widget.charsPerSecond, 20);
        expect(widget.showCursor, isFalse);
        expect(widget.cursorChar, '_');
        expect(widget.cursorBlinkFrames, 10);
        expect(widget.textAlign, TextAlign.center);
        expect(widget.maxLines, 2);
        expect(widget.overflow, TextOverflow.ellipsis);
      });
    });

    group('totalDuration', () {
      test('calculates correct duration for text', () {
        const widget = TypewriterText(
          'Hello', // 5 characters
          charsPerSecond: 15,
        );

        // At 30fps: 15 chars/sec = 0.5 chars/frame
        // 5 chars / 0.5 = 10 frames
        expect(widget.totalDuration(30), 10);
      });

      test('calculates duration with different fps', () {
        const widget = TypewriterText(
          'Hello World', // 11 characters
          charsPerSecond: 10,
        );

        // At 60fps: 10 chars/sec = 1/6 chars/frame
        // 11 chars / (10/60) = 66 frames
        expect(widget.totalDuration(60), 66);
      });

      test('handles empty text', () {
        const widget = TypewriterText('');

        // 0 chars means 0 frames
        expect(widget.totalDuration(30), 0);
      });
    });

    group('widget rendering', () {
      testWidgets('shows cursor before typing starts', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Hello',
            startFrame: 30,
            showCursor: true,
            cursorChar: '|',
          ),
          frame: 0,
        ));

        // Before start, should show just cursor
        expect(find.text('|'), findsOneWidget);
      });

      testWidgets('shows nothing before start when cursor disabled', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Hello',
            startFrame: 30,
            showCursor: false,
          ),
          frame: 0,
        ));

        expect(find.text(''), findsOneWidget);
      });

      testWidgets('reveals characters progressively', (tester) async {
        // At 30fps with 15 chars/sec, we get 0.5 chars/frame
        // So at frame 2 (2 frames elapsed), we should have 1 char
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Hello',
            startFrame: 0,
            charsPerSecond: 15,
            showCursor: true,
            cursorChar: '|',
          ),
          frame: 2,
        ));

        expect(find.text('H|'), findsOneWidget);
      });

      testWidgets('shows more characters as time progresses', (tester) async {
        // At frame 6 with 0.5 chars/frame = 3 chars
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Hello',
            startFrame: 0,
            charsPerSecond: 15,
            showCursor: true,
            cursorChar: '|',
          ),
          frame: 6,
        ));

        expect(find.text('Hel|'), findsOneWidget);
      });

      testWidgets('shows full text after completion', (tester) async {
        // 5 chars at 0.5 chars/frame = 10 frames
        // At frame 30, should show full text
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Hello',
            startFrame: 0,
            charsPerSecond: 15,
            showCursor: false,
          ),
          frame: 30,
        ));

        expect(find.text('Hello'), findsOneWidget);
      });

      testWidgets('handles delayed start', (tester) async {
        // startFrame: 10, at frame 12, 2 frames elapsed = 1 char
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Test',
            startFrame: 10,
            charsPerSecond: 15,
            showCursor: true,
            cursorChar: '|',
          ),
          frame: 12,
        ));

        expect(find.text('T|'), findsOneWidget);
      });
    });

    group('cursor behavior', () {
      testWidgets('cursor blinks on and off', (tester) async {
        // At frame 0, cursor should be visible (phase 0)
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Hi',
            startFrame: 0,
            charsPerSecond: 15,
            showCursor: true,
            cursorChar: '_',
            cursorBlinkFrames: 15,
          ),
          frame: 0,
        ));

        expect(find.text('_'), findsOneWidget);
      });

      testWidgets('uses custom cursor character', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Hello',
            startFrame: 0,
            showCursor: true,
            cursorChar: '▊',
          ),
          frame: 0,
        ));

        // Should use custom cursor
        expect(find.textContaining('▊'), findsOneWidget);
      });

      testWidgets('no cursor when showCursor is false', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Hello',
            startFrame: 0,
            charsPerSecond: 15,
            showCursor: false,
          ),
          frame: 4,
        ));

        // Should not contain cursor
        expect(find.text('He'), findsOneWidget);
      });
    });

    group('text styling', () {
      testWidgets('applies text style', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Styled',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            showCursor: false,
          ),
          frame: 100,
        ));

        expect(find.text('Styled'), findsOneWidget);
      });

      testWidgets('applies text alignment', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Centered',
            textAlign: TextAlign.center,
            showCursor: false,
          ),
          frame: 100,
        ));

        expect(find.text('Centered'), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles empty text', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            '',
            showCursor: false,
          ),
        ));

        expect(find.text(''), findsOneWidget);
      });

      testWidgets('handles long text', (tester) async {
        final longText = 'A' * 100;
        await tester.pumpWidget(wrapWithApp(
          TypewriterText(
            longText,
            showCursor: false,
          ),
          frame: 1000,
        ));

        expect(find.text(longText), findsOneWidget);
      });

      testWidgets('handles special characters', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Hello! @#\$% 你好',
            showCursor: false,
          ),
          frame: 100,
        ));

        expect(find.text('Hello! @#\$% 你好'), findsOneWidget);
      });

      testWidgets('handles high charsPerSecond', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Fast',
            charsPerSecond: 100,
            showCursor: false,
          ),
          frame: 5,
        ));

        expect(find.text('Fast'), findsOneWidget);
      });

      testWidgets('handles low charsPerSecond', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Slow',
            charsPerSecond: 1, // 1 char per second
            showCursor: false,
          ),
          frame: 30, // 1 second at 30fps = 1 char
        ));

        expect(find.text('S'), findsOneWidget);
      });

      testWidgets('handles multiline text', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const TypewriterText(
            'Line 1\nLine 2',
            showCursor: false,
          ),
          frame: 100,
        ));

        expect(find.text('Line 1\nLine 2'), findsOneWidget);
      });
    });
  });
}
