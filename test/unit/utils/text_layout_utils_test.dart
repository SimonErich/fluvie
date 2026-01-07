import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/utils/text_layout_utils.dart';

void main() {
  group('TextLayoutUtils', () {
    group('measureText', () {
      testWidgets('returns non-zero size for text', (tester) async {
        final size = TextLayoutUtils.measureText(
          'Hello World',
          const TextStyle(fontSize: 16),
        );

        expect(size.width, greaterThan(0));
        expect(size.height, greaterThan(0));
      });

      testWidgets('returns zero width for empty string', (tester) async {
        final size = TextLayoutUtils.measureText(
          '',
          const TextStyle(fontSize: 16),
        );

        expect(size.width, 0);
        expect(
            size.height, greaterThan(0)); // Height is still based on font size
      });

      testWidgets('larger font size results in larger dimensions',
          (tester) async {
        final smallSize = TextLayoutUtils.measureText(
          'Test',
          const TextStyle(fontSize: 12),
        );

        final largeSize = TextLayoutUtils.measureText(
          'Test',
          const TextStyle(fontSize: 24),
        );

        expect(largeSize.width, greaterThan(smallSize.width));
        expect(largeSize.height, greaterThan(smallSize.height));
      });

      testWidgets('longer text has greater width', (tester) async {
        final shortSize = TextLayoutUtils.measureText(
          'Hi',
          const TextStyle(fontSize: 16),
        );

        final longSize = TextLayoutUtils.measureText(
          'Hello World',
          const TextStyle(fontSize: 16),
        );

        expect(longSize.width, greaterThan(shortSize.width));
      });

      testWidgets('respects maxWidth constraint', (tester) async {
        final unconstrainedSize = TextLayoutUtils.measureText(
          'This is a very long text that should wrap',
          const TextStyle(fontSize: 16),
        );

        final constrainedSize = TextLayoutUtils.measureText(
          'This is a very long text that should wrap',
          const TextStyle(fontSize: 16),
          maxWidth: 100,
        );

        // When maxWidth is smaller than text width, width is constrained
        expect(constrainedSize.width, lessThanOrEqualTo(100));
        expect(unconstrainedSize.width, greaterThan(100));
      });

      testWidgets('handles different font families', (tester) async {
        final serifSize = TextLayoutUtils.measureText(
          'Test',
          const TextStyle(fontSize: 16, fontFamily: 'serif'),
        );

        final monoSize = TextLayoutUtils.measureText(
          'Test',
          const TextStyle(fontSize: 16, fontFamily: 'monospace'),
        );

        // Both should have valid dimensions
        expect(serifSize.width, greaterThan(0));
        expect(monoSize.width, greaterThan(0));
      });

      testWidgets('handles bold text', (tester) async {
        final normalSize = TextLayoutUtils.measureText(
          'Test',
          const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        );

        final boldSize = TextLayoutUtils.measureText(
          'Test',
          const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        );

        // Bold text may be slightly wider
        expect(boldSize.width, greaterThanOrEqualTo(normalSize.width * 0.9));
        expect(boldSize.height, closeTo(normalSize.height, 5));
      });

      testWidgets('handles italic text', (tester) async {
        final size = TextLayoutUtils.measureText(
          'Test',
          const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
        );

        expect(size.width, greaterThan(0));
        expect(size.height, greaterThan(0));
      });

      testWidgets('handles special characters', (tester) async {
        final size = TextLayoutUtils.measureText(
          '🎬🎥📹',
          const TextStyle(fontSize: 16),
        );

        expect(size.width, greaterThan(0));
        expect(size.height, greaterThan(0));
      });

      testWidgets('handles whitespace only', (tester) async {
        final size = TextLayoutUtils.measureText(
          '   ',
          const TextStyle(fontSize: 16),
        );

        // Whitespace should have some width
        expect(size.width, greaterThan(0));
      });

      testWidgets('handles single character', (tester) async {
        final size = TextLayoutUtils.measureText(
          'A',
          const TextStyle(fontSize: 16),
        );

        expect(size.width, greaterThan(0));
        expect(size.height, greaterThan(0));
      });

      testWidgets('handles very long single word', (tester) async {
        final size = TextLayoutUtils.measureText(
          'Supercalifragilisticexpialidocious',
          const TextStyle(fontSize: 16),
        );

        expect(size.width, greaterThan(0));
        expect(size.height, greaterThan(0));
      });

      testWidgets('handles letter spacing', (tester) async {
        final normalSize = TextLayoutUtils.measureText(
          'Test',
          const TextStyle(fontSize: 16, letterSpacing: 0),
        );

        final spacedSize = TextLayoutUtils.measureText(
          'Test',
          const TextStyle(fontSize: 16, letterSpacing: 5),
        );

        expect(spacedSize.width, greaterThan(normalSize.width));
      });

      testWidgets('handles text with newlines as single line', (tester) async {
        // measureText uses maxLines: 1, so newlines should be treated as spaces
        final size = TextLayoutUtils.measureText(
          'Line1\nLine2',
          const TextStyle(fontSize: 16),
        );

        expect(size.width, greaterThan(0));
        // Height should be single line height
      });
    });
  });
}
