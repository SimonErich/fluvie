// WI-16 (D-Captions-types, §17, key-resolution #6): CaptionPosition is the
// explicit value type behind the spec's `Align.thirds.bottom` shorthand. Each
// factory resolves to an Alignment plus a safe-area inset; value-equal so a
// styled track caches stably.

import 'package:flutter/painting.dart' show Alignment;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/caption_position.dart';

void main() {
  group('CaptionPosition factories resolve to the right alignment', () {
    test('bottomThird sits in the lower third', () {
      const position = CaptionPosition.bottomThird();
      expect(position.alignment, const Alignment(0, 1 / 3));
    });

    test('topThird sits in the upper third', () {
      const position = CaptionPosition.topThird();
      expect(position.alignment, const Alignment(0, -1 / 3));
    });

    test('center sits dead center', () {
      const position = CaptionPosition.center();
      expect(position.alignment, Alignment.center);
    });

    test('custom carries the explicit alignment', () {
      const position = CaptionPosition.custom(Alignment.topLeft);
      expect(position.alignment, Alignment.topLeft);
    });
  });

  group('CaptionPosition safe-area inset', () {
    test('the third presets carry a non-zero safe-area inset', () {
      expect(const CaptionPosition.bottomThird().safeArea, greaterThan(0));
      expect(const CaptionPosition.topThird().safeArea, greaterThan(0));
    });

    test('center carries no inset by default', () {
      expect(const CaptionPosition.center().safeArea, 0);
    });

    test('custom takes an explicit safe area', () {
      const position = CaptionPosition.custom(Alignment.bottomCenter, safeArea: 48);
      expect(position.safeArea, 48);
    });
  });

  group('CaptionPosition equality', () {
    test('is value-equal with a matching hashCode', () {
      expect(const CaptionPosition.bottomThird(), const CaptionPosition.bottomThird());
      expect(
        const CaptionPosition.bottomThird().hashCode,
        const CaptionPosition.bottomThird().hashCode,
      );
    });

    test('differs by alignment and safe area', () {
      expect(const CaptionPosition.bottomThird(), isNot(const CaptionPosition.topThird()));
      expect(
        const CaptionPosition.custom(Alignment.center, safeArea: 1),
        isNot(const CaptionPosition.custom(Alignment.center, safeArea: 2)),
      );
    });

    test('is const-constructible (a compile-time value)', () {
      expect(
        identical(const CaptionPosition.bottomThird(), const CaptionPosition.bottomThird()),
        isTrue,
      );
    });
  });
}
