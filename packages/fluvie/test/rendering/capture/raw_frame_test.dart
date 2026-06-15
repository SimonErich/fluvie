import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';

Uint8List _bytes(int length, [int fill = 0]) => Uint8List(length)..fillRange(0, length, fill);

void main() {
  group('RawFrame', () {
    test('constructs when rgba length matches width*height*4', () {
      final frame = RawFrame(frameIndex: 3, width: 4, height: 2, rgba: _bytes(4 * 2 * 4));
      expect(frame.frameIndex, 3);
      expect(frame.width, 4);
      expect(frame.height, 2);
      expect(frame.rgba.length, 32);
    });

    test('length mismatch throws ArgumentError naming the expectation', () {
      expect(
        () => RawFrame(frameIndex: 0, width: 4, height: 2, rgba: _bytes(31)),
        throwsA(
          isA<ArgumentError>().having((e) => e.message, 'message', contains('32')),
        ),
      );
    });

    test('byteLength is width*height*4', () {
      final frame = RawFrame(frameIndex: 0, width: 6, height: 5, rgba: _bytes(6 * 5 * 4));
      expect(frame.byteLength, 120);
    });

    test('equal metadata and bytes are equal with equal hashCodes', () {
      final a = RawFrame(frameIndex: 1, width: 2, height: 2, rgba: _bytes(16, 0xAB));
      final b = RawFrame(frameIndex: 1, width: 2, height: 2, rgba: _bytes(16, 0xAB));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing frameIndex breaks equality', () {
      final a = RawFrame(frameIndex: 1, width: 2, height: 2, rgba: _bytes(16));
      final b = RawFrame(frameIndex: 2, width: 2, height: 2, rgba: _bytes(16));
      expect(a, isNot(b));
    });

    test('differing dimensions break equality', () {
      final a = RawFrame(frameIndex: 0, width: 2, height: 4, rgba: _bytes(32));
      final b = RawFrame(frameIndex: 0, width: 4, height: 2, rgba: _bytes(32));
      expect(a, isNot(b));
    });

    test('a single differing byte breaks equality', () {
      final a = RawFrame(frameIndex: 0, width: 2, height: 2, rgba: _bytes(16, 0xAB));
      final mutated = _bytes(16, 0xAB)..[7] = 0xAC;
      final b = RawFrame(frameIndex: 0, width: 2, height: 2, rgba: mutated);
      expect(a, isNot(b));
    });

    test('is equal to itself (identical short-circuit)', () {
      final frame = RawFrame(frameIndex: 0, width: 2, height: 2, rgba: _bytes(16));
      expect(frame, frame);
    });
  });
}
