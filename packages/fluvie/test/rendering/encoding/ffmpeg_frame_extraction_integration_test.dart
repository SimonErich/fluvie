// WI-15/WI-16 (D8): the real-ffmpeg extraction integration. Tagged `ffmpeg`
// (a local /usr/bin/ffmpeg is required), it extracts a known frame from the
// committed clip_1s.mp4 fixture and asserts the RawFrame dimensions and the
// full RGBA byte length. The VP9-alpha group synthesizes its own webm rather
// than committing one: no mocked runner can catch a decoder that silently drops
// an alpha layer, and the file is 1 KB to make. Excluded from the default run.
@Tags(['ffmpeg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';

/// The committed 320x240, 30fps, 1s test clip, relative to the repo root.
/// Synthesized with:
///   ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=30 \
///     -pix_fmt yuv420p examples/gallery/assets/fixtures/clip_1s.mp4
File _fixture() {
  for (final candidate in const [
    'examples/gallery/assets/fixtures/clip_1s.mp4',
    '../../examples/gallery/assets/fixtures/clip_1s.mp4',
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

  group('a VP9 source with a coded alpha layer', () {
    late Uri webm;

    setUpAll(() async {
      final dir = Directory.systemTemp.createTempSync('fluvie_alpha_webm_');
      addTearDown(() => dir.deleteSync(recursive: true));
      webm = Uri.file(await _synthesizeAlphaWebm(dir));
    });

    test('the libvpx-vp9 decoder keeps the alpha layer', () async {
      final frame = await service.extractFrame(
        webm,
        0,
        width: _webmSize,
        height: _webmSize,
        decoder: 'libvpx-vp9',
      );

      final alpha = [
        for (var i = 3; i < frame.rgba.length; i += 4) frame.rgba[i],
      ];
      expect(alpha.reduce((a, b) => a < b ? a : b), 0, reason: 'the padding is transparent');
      expect(alpha.reduce((a, b) => a > b ? a : b), 255, reason: 'the square is opaque');
      expect(_alphaAt(frame, 0, 0), lessThan(8), reason: 'the corner is padding');
      expect(_alphaAt(frame, _webmSize ~/ 2, _webmSize ~/ 2), greaterThan(247));
    }, tags: ['ffmpeg']);

    // The regression this whole decoder choice exists for: VP9 codes alpha as a
    // separate layer that only libvpx-vp9 reads, so the default decoder returns
    // a fully opaque frame instead of failing. A render composites it over black
    // and still "succeeds", which is why the check is on the pixels here rather
    // than on a black-box render. If ffmpeg ever teaches its native decoder to
    // read the layer, this fails and the decoder plumbing can go.
    test("ffmpeg's default vp9 decoder drops the alpha layer", () async {
      final frame = await service.extractFrame(webm, 0, width: _webmSize, height: _webmSize);

      expect(_alphaAt(frame, 0, 0), 255, reason: 'the transparent padding decodes opaque');
    }, tags: ['ffmpeg']);

    test(
      'the probe derives a frame count Matroska never stores, and reads the alpha tag',
      () async {
        const probe = FfprobeVideoProbeService();

        final result = await probe.probe(webm.toFilePath());

        expect(result.codec, 'vp9');
        expect(result.hasAlpha, isTrue, reason: 'the muxer wrote ALPHA_MODE=1');
        expect(result.nbFrames, _webmFrames, reason: 'counted: the container reports no nb_frames');
        expect(result.width, _webmSize);
      },
      tags: ['ffmpeg'],
    );
  });
}

/// The synthesized clip's size and length: a 64x64 frame with an opaque red
/// 32x32 square centred in fully transparent padding, 10 frames at 10fps.
const int _webmSize = 64;
const int _webmFrames = 10;

/// The alpha byte of the pixel at ([x], [y]).
int _alphaAt(RawFrame frame, int x, int y) => frame.rgba[(y * frame.width + x) * 4 + 3];

/// Writes a tiny VP9-with-alpha webm into [dir] and returns its path.
///
/// `format=rgba` before the pad is load-bearing: without it the filter graph
/// negotiates an opaque format and the padding is flattened to black before it
/// ever reaches the encoder, so the fixture would carry an `ALPHA_MODE` tag over
/// a uniformly opaque alpha plane and prove nothing.
Future<String> _synthesizeAlphaWebm(Directory dir) async {
  final path = '${dir.path}/alpha.webm';
  final result = await Process.run('ffmpeg', [
    '-v',
    'error',
    '-nostdin',
    '-f',
    'lavfi',
    '-i',
    'color=c=red:s=32x32:d=1:r=$_webmFrames',
    '-vf',
    'format=rgba,pad=$_webmSize:$_webmSize:16:16:color=0x00000000',
    '-c:v',
    'libvpx-vp9',
    '-pix_fmt',
    'yuva420p',
    '-y',
    path,
  ]);
  if (result.exitCode != 0) {
    fail('could not synthesize the VP9-alpha fixture: ${result.stderr}');
  }
  return path;
}
