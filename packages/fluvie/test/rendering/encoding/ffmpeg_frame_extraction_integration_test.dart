// WI-15/WI-16 (D8): the real-ffmpeg extraction integration. Tagged `ffmpeg`
// (a local /usr/bin/ffmpeg is required), it extracts a known frame from the
// committed clip_1s.mp4 fixture and asserts the RawFrame dimensions and the
// full RGBA byte length. Excluded from the default test run.
@Tags(['ffmpeg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';

/// The committed 320x240, 30fps, 1s test clip, relative to the repo root.
/// Synthesized with:
///   ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=30 \
///     -pix_fmt yuv420p example/assets/fixtures/clip_1s.mp4
File _fixture() {
  for (final candidate in const [
    'example/assets/fixtures/clip_1s.mp4',
    '../../example/assets/fixtures/clip_1s.mp4',
  ]) {
    final file = File(candidate);
    if (file.existsSync()) return file.absolute;
  }
  fail('clip_1s.mp4 fixture not found (run from the repo root or packages/fluvie).');
}

void main() {
  const service = FfmpegFrameExtractionService();

  test('extracts a known frame at the requested size', () async {
    final frame = await service.extractFrame(
      Uri.file(_fixture().path),
      0,
      width: 320,
      height: 240,
    );

    expect(frame.width, 320);
    expect(frame.height, 240);
    expect(frame.frameIndex, 0);
    expect(frame.rgba.length, 320 * 240 * 4);
  }, tags: ['ffmpeg']);

  test('two extractions of the same frame are byte-identical (determinism)', () async {
    final path = Uri.file(_fixture().path);
    final a = await service.extractFrame(path, 12, width: 320, height: 240);
    final b = await service.extractFrame(path, 12, width: 320, height: 240);

    expect(a, b, reason: 'the same source frame must extract to identical bytes');
  }, tags: ['ffmpeg']);

  test('a later frame index differs from frame 0', () async {
    final path = Uri.file(_fixture().path);
    final first = await service.extractFrame(path, 0, width: 320, height: 240);
    final later = await service.extractFrame(path, 20, width: 320, height: 240);

    expect(first.rgba, isNot(later.rgba), reason: 'testsrc changes across frames');
  }, tags: ['ffmpeg']);
}
