import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';

void main() {
  group('FluvieTimingError', () {
    test('toString carries the message verbatim', () {
      final error = FluvieTimingError('cycle detected between intro and outro');
      expect(error.toString(), contains('cycle detected between intro and outro'));
    });

    test('toString names anchors in the order given', () {
      final intro = Anchor('intro');
      final outro = Anchor('outro');
      final error = FluvieTimingError('cycle detected', anchors: [intro, outro]);
      final text = error.toString();
      expect(text, contains('intro'));
      expect(text, contains('outro'));
      expect(text.indexOf('intro'), lessThan(text.indexOf('outro')));
    });

    test('an unnamed anchor falls back to Anchor#identityHashCode', () {
      final unnamed = Anchor();
      final error = FluvieTimingError('dangling trigger', anchors: [unnamed]);
      expect(error.toString(), contains('Anchor#${identityHashCode(unnamed)}'));
    });

    test('is catchable as an Exception', () {
      expect(() => throw FluvieTimingError('boom'), throwsA(isA<Exception>()));
    });

    test('anchors defaults to an empty list and toString stays message-only', () {
      final error = FluvieTimingError('no anchors involved');
      expect(error.anchors, isEmpty);
      expect(error.toString(), 'FluvieTimingError: no anchors involved');
    });
  });
}
