import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';
import 'package:fluvie_web_encoder/src/web_video_encoder.dart'
    show expandImagePattern, fileInputNames;

import 'fakes/fake_wasm_runtime.dart';

void main() {
  RenderManifest manifest(List<String> args) => RenderManifest(
    width: 4,
    height: 4,
    fps: 30,
    frameCount: 1,
    framesFileName: 'frames.rgba',
    outputFileName: 'out.mp4',
    renderDigest: 'digest',
    ffmpegArgs: args,
  );

  test('copies sandbox inputs into wasm, runs, returns + stores the output', () async {
    final runtime = FakeWasmRuntime();
    final sandbox = MemoryRenderSandbox();
    await sandbox.writeBytes('frames.rgba', Uint8List.fromList([1, 2, 3]));

    final out = await WebVideoEncoder(runtime: runtime).encode(
      manifest: manifest(['-i', 'frames.rgba', 'out.mp4']),
      sandbox: sandbox,
    );

    expect(runtime.files['frames.rgba'], [1, 2, 3]);
    expect(out, isNotEmpty);
    expect(await sandbox.readBytes('out.mp4'), out);
  });

  test('throws a FluvieEncodeException on a non-zero exit', () async {
    final sandbox = MemoryRenderSandbox();
    await sandbox.writeBytes('frames.rgba', Uint8List.fromList([0]));

    await expectLater(
      WebVideoEncoder(runtime: FakeWasmRuntime(exitCode: 1)).encode(
        manifest: manifest(['-i', 'frames.rgba', 'out.mp4']),
        sandbox: sandbox,
      ),
      throwsA(isA<FluvieEncodeException>()),
    );
  });

  test('fileInputNames skips a lavfi generated input', () {
    expect(
      fileInputNames(['-f', 'lavfi', '-i', 'anullsrc', '-i', 'frames.rgba', 'out.mp4']),
      ['frames.rgba'],
    );
  });

  test('expandImagePattern lists every numbered frame file for the count', () {
    expect(expandImagePattern('frame_%06d.png', 3), [
      'frame_000000.png',
      'frame_000001.png',
      'frame_000002.png',
    ]);
    expect(expandImagePattern('frames.rgba', 5), ['frames.rgba']);
  });

  test('expands a PNG frame pattern and copies each frame into wasm', () async {
    final runtime = FakeWasmRuntime();
    final sandbox = MemoryRenderSandbox();
    await sandbox.writeBytes('frame_000000.png', Uint8List.fromList([1]));
    await sandbox.writeBytes('frame_000001.png', Uint8List.fromList([2]));

    final pngManifest = RenderManifest(
      width: 4,
      height: 4,
      fps: 30,
      frameCount: 2,
      framesFileName: 'frame_%06d.png',
      outputFileName: 'out.mp4',
      renderDigest: 'digest',
      ffmpegArgs: const ['-framerate', '30', '-i', 'frame_%06d.png', 'out.mp4'],
    );

    await WebVideoEncoder(runtime: runtime).encode(manifest: pngManifest, sandbox: sandbox);

    expect(runtime.files['frame_000000.png'], [1]);
    expect(runtime.files['frame_000001.png'], [2]);
  });
}
