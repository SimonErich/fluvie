import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';

import 'fake_frame_extraction_service.dart';

RawFrame _frame(int index, int seed) => RawFrame(
  frameIndex: index,
  width: 2,
  height: 1,
  rgba: Uint8List.fromList([seed, seed, seed, 255, 0, 0, 0, 255]),
);

void main() {
  final clip = Uri.parse('https://example.com/clip.mp4');
  final other = Uri.parse('https://example.com/other.mp4');

  group('FakeFrameExtractionService', () {
    test('round-trips canned frames per source and index', () async {
      final service = FakeFrameExtractionService({
        clip: {0: _frame(0, 10), 5: _frame(5, 50)},
      });

      expect(await service.extractFrame(clip, 0, width: 2, height: 1), _frame(0, 10));
      expect(await service.extractFrame(clip, 5, width: 2, height: 1), _frame(5, 50));
    });

    test('a missing source throws a typed error naming it', () async {
      final service = FakeFrameExtractionService({
        clip: {0: _frame(0, 10)},
      });

      await expectLater(
        () => service.extractFrame(other, 0, width: 2, height: 1),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('$other')),
        ),
      );
    });

    test('a missing frame index throws a typed error naming it', () async {
      final service = FakeFrameExtractionService({
        clip: {0: _frame(0, 10)},
      });

      await expectLater(
        () => service.extractFrame(clip, 99, width: 2, height: 1),
        throwsA(isA<FluvieRenderException>().having((e) => e.message, 'message', contains('99'))),
      );
    });

    test('repeat reads are deterministic (same frame both times)', () async {
      final service = FakeFrameExtractionService({
        clip: {3: _frame(3, 30)},
      });

      final first = await service.extractFrame(clip, 3, width: 2, height: 1);
      final second = await service.extractFrame(clip, 3, width: 2, height: 1);

      expect(first, second);
    });
  });
}
