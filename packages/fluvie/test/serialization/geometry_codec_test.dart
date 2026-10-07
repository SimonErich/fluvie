import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/codecs/geometry_codec.dart';

void main() {
  group('decodeOffset', () {
    test('reads {x, y}', () {
      expect(decodeOffset({'x': 10, 'y': 20.5}), const Offset(10, 20.5));
    });

    test('rejects a non-object and missing coordinates', () {
      expect(() => decodeOffset('nope'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeOffset({'x': 1}), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeOffset({'x': 'one', 'y': 2}), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('decodeRect', () {
    test('reads {x, y, w, h}', () {
      expect(decodeRect({'x': 1, 'y': 2, 'w': 3, 'h': 4}), const Rect.fromLTWH(1, 2, 3, 4));
    });

    test('rejects a non-object and missing fields', () {
      expect(() => decodeRect([1, 2, 3, 4]), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeRect({'x': 1, 'y': 2, 'w': 3}), throwsA(isA<FluvieSpecError>()));
    });
  });
}
