import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['FLUVIE_TEST_NATIVE_MEDIA'] == '1';
  late Directory directory;
  late FfmpegMediaTools tools;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fluvie_native_fixture_');
    tools = FfmpegMediaTools();
  });
  tearDown(() async {
    tools.close();
    await directory.delete(recursive: true);
  });

  Future<void> encode(List<String> arguments) async {
    final result = await tools.run(tools.ffmpegPath, ['-v', 'error', '-y', ...arguments]);
    expect(result.exitCode, 0, reason: result.stderr);
  }

  test(
    'VFR source indices and coded alpha survive one exact native batch',
    () async {
      final rgba = Uint8List(4 * 16 * 8 * 4);
      const pixels = [
        [255, 0, 0, 255],
        [0, 255, 0, 128],
        [0, 0, 255, 64],
        [255, 255, 0, 0],
      ];
      for (var frame = 0; frame < pixels.length; frame++) {
        for (var pixel = 0; pixel < 16 * 8; pixel++) {
          rgba.setRange(
            (frame * 16 * 8 + pixel) * 4,
            (frame * 16 * 8 + pixel + 1) * 4,
            pixels[frame],
          );
        }
      }
      final input = File('${directory.path}/input.rgba');
      await input.writeAsBytes(rgba);
      final output = '${directory.path}/variable.mkv';
      await encode([
        '-f',
        'rawvideo',
        '-pixel_format',
        'rgba',
        '-video_size',
        '16x8',
        '-framerate',
        '10',
        '-i',
        input.path,
        '-vf',
        r'settb=1/1000,setpts=if(eq(N\,0)\,0\,if(eq(N\,1)\,100\,if(eq(N\,2)\,400\,900)))',
        '-fps_mode',
        'vfr',
        '-c:v',
        'ffv1',
        '-pix_fmt',
        'bgra',
        output,
      ]);
      final metadata = await tools.probe(output);
      expect(metadata.frameCount, 4);
      expect(metadata.hasAlpha, isTrue);
      final timeline = await tools.probeTimeline(output);
      expect(timeline.frameAt(0.35), 1);
      expect(timeline.frameAt(0.89), 2);
      expect(timeline.timeForFrame(3), 0.9);
      expect(timeline.durationSeconds, 1);
      final frames = await tools.extractFrames(Uri.file(output), [3, 0, 1], width: 16, height: 8);
      expect(frames.keys, [0, 1, 3]);
      for (final index in frames.keys) {
        expect(frames[index]!.rgba.sublist(0, 4), pixels[index]);
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'VP9 alpha uses the explicit alpha-aware decoder without flattening',
    () async {
      final input = File('${directory.path}/alpha.rgba');
      await input.writeAsBytes(
        List.generate(16 * 8, (_) => [120, 60, 30, 128]).expand((pixel) => pixel).toList(),
      );
      final output = '${directory.path}/alpha.webm';
      await encode([
        '-f',
        'rawvideo',
        '-pixel_format',
        'rgba',
        '-video_size',
        '16x8',
        '-framerate',
        '1',
        '-i',
        input.path,
        '-c:v',
        'libvpx-vp9',
        '-pix_fmt',
        'yuva420p',
        '-lossless',
        '1',
        '-auto-alt-ref',
        '0',
        output,
      ]);
      final metadata = await tools.probe(output);
      expect(metadata.hasAlpha, isTrue);
      final frames = await tools.extractFrames(
        Uri.file(output),
        [0],
        width: 16,
        height: 8,
        decoder: 'libvpx-vp9',
      );
      // The VP9 alpha plane can quantize one level during RGBA → YUVA encode.
      expect(frames[0]!.rgba[3], inInclusiveRange(127, 129));
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'display rotation agrees with the native decoded raster',
    () async {
      final original = '${directory.path}/original.mp4';
      await encode([
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=16x8:rate=2',
        '-t',
        '1',
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        original,
      ]);
      final rotated = '${directory.path}/rotated.mp4';
      await encode(['-display_rotation', '90', '-i', original, '-c', 'copy', rotated]);
      final metadata = await tools.probe(rotated);
      expect(metadata.width, 8);
      expect(metadata.height, 16);
      final frames = await tools.extractFrames(Uri.file(rotated), [0], width: 8, height: 16);
      expect(frames[0]!.rgba, hasLength(8 * 16 * 4));
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
