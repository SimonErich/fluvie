import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/render_duration.dart';

void main() {
  group('frameCountFor', () {
    test('multiplies duration by fps', () {
      expect(frameCountFor(const Duration(seconds: 2), 30), 60);
    });

    test('rounds to the nearest frame', () {
      expect(frameCountFor(const Duration(milliseconds: 100), 30), 3);
    });

    test('rounds a sub-frame duration up to one frame', () {
      expect(frameCountFor(const Duration(milliseconds: 1), 30), 1);
    });

    test('rejects non-positive fps', () {
      expect(() => frameCountFor(const Duration(seconds: 1), 0), throwsArgumentError);
    });

    test('rejects non-positive duration', () {
      expect(() => frameCountFor(Duration.zero, 30), throwsArgumentError);
    });
  });
}
