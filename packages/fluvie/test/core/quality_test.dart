import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/quality.dart';

void main() {
  group('Quality', () {
    test('declares exactly four levels in ascending visual order', () {
      expect(
        Quality.values,
        const [Quality.low, Quality.medium, Quality.high, Quality.max],
      );
    });

    test('indices are stable (RenderConfig JSON relies on the order)', () {
      expect(Quality.low.index, 0);
      expect(Quality.medium.index, 1);
      expect(Quality.high.index, 2);
      expect(Quality.max.index, 3);
    });

    test('every name round-trips through values.byName', () {
      for (final quality in Quality.values) {
        expect(Quality.values.byName(quality.name), quality);
      }
    });

    test('unknown name throws (fromJson guard relies on byName throwing)', () {
      expect(() => Quality.values.byName('ultra'), throwsArgumentError);
    });
  });
}
