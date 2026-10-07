import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show FrameRange;

void main() {
  test('holds a forward frame span', () {
    const range = FrameRange(10, 20);
    expect(range.start, 10);
    expect(range.end, 20);
    expect(range.lengthFrames, 10);
  });

  test('rejects a negative start and an inverted or empty span', () {
    expect(() => FrameRange(-1, 5), throwsAssertionError);
    expect(() => FrameRange(5, 5), throwsAssertionError);
    expect(() => FrameRange(5, 4), throwsAssertionError);
  });

  test('contains frames from the start up to, not including, the end', () {
    const range = FrameRange(10, 20);
    expect(range.contains(9), isFalse);
    expect(range.contains(10), isTrue);
    expect(range.contains(19), isTrue);
    expect(range.contains(20), isFalse);
  });

  test('equal spans are equal', () {
    expect(const FrameRange(1, 4), const FrameRange(1, 4));
    expect(const FrameRange(1, 4).hashCode, const FrameRange(1, 4).hashCode);
    expect(const FrameRange(1, 4), isNot(const FrameRange(1, 5)));
    expect(const FrameRange(1, 4), isNot(const FrameRange(2, 4)));
  });

  test('describes itself in frames', () {
    expect(const FrameRange(3, 12).toString(), 'FrameRange(3..12)');
  });
}
