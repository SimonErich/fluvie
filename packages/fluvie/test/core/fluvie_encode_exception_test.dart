import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

void main() {
  group('FluvieEncodeException', () {
    test('toString carries the message verbatim', () {
      final error = FluvieEncodeException('ffmpeg failed');
      expect(error.toString(), contains('ffmpeg failed'));
    });

    test('toString includes the exit code when present', () {
      final error = FluvieEncodeException('ffmpeg failed', exitCode: 187);
      expect(error.toString(), contains('exit code 187'));
    });

    test('toString includes the stderr tail when present', () {
      final error = FluvieEncodeException(
        'ffmpeg failed',
        exitCode: 1,
        stderrTail: 'Invalid pixel format',
      );
      final text = error.toString();
      expect(text, contains('exit code 1'));
      expect(text, contains('Invalid pixel format'));
    });

    test('toString omits exit code and stderr when absent', () {
      final error = FluvieEncodeException('ffmpeg failed');
      final text = error.toString();
      expect(text, isNot(contains('exit code')));
      expect(text, isNot(contains('stderr')));
    });

    test('is-a FluvieRenderException', () {
      final error = FluvieEncodeException('ffmpeg failed');
      expect(error, isA<FluvieRenderException>());
    });

    test('is catchable as an Exception', () {
      expect(() => throw FluvieEncodeException('boom'), throwsA(isA<Exception>()));
    });

    test('exitCode and stderrTail default to null', () {
      final error = FluvieEncodeException('ffmpeg failed');
      expect(error.exitCode, isNull);
      expect(error.stderrTail, isNull);
    });
  });
}
