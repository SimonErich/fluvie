import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

void main() {
  group('FluvieRenderException', () {
    test('toString carries the message verbatim', () {
      final error = FluvieRenderException('boundary 320x240 expected, got 64x64');
      expect(error.toString(), 'FluvieRenderException: boundary 320x240 expected, got 64x64');
    });

    test('message is stored verbatim', () {
      final error = FluvieRenderException('capture failed');
      expect(error.message, 'capture failed');
    });

    test('is catchable as an Exception', () {
      expect(() => throw FluvieRenderException('boom'), throwsA(isA<Exception>()));
    });
  });
}
