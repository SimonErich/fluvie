import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';
import 'package:fluvie_web_encoder/src/web_video_encoder.dart' show fileInputNames;

import 'fake_wasm_runtime.dart';

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
}
