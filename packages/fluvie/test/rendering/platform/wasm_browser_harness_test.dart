@Tags(['wasm'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_args.dart';
import 'package:fluvie/src/rendering/platform/wasm_ffmpeg_provider.dart';
import 'package:fluvie/src/rendering/platform/wasm_runtime_bindings.dart';

/// Manual browser harness (D13): real ffmpeg.wasm, real chrome, no network.
///
/// Run it locally against a *local* ffmpeg.wasm checkout (the network
/// allowlist stays empty) with a page that installs the `FluvieFfmpeg`
/// bridge object for [createWasmRuntime]:
///
/// ```sh
/// flutter test --platform chrome --tags wasm \
///   --dart-define=FLUVIE_WASM_PATH=/abs/path/to/ffmpeg.wasm \
///   test/rendering/platform/wasm_browser_harness_test.dart
/// ```
///
/// Without the define every case is skipped, so VM and CI runs stay green.
const String _wasmPath = String.fromEnvironment('FLUVIE_WASM_PATH');

const int _width = 64;
const int _height = 64;
const int _frameCount = 5;

/// Deterministic synthetic RGBA frames: integer math on the frame index only.
Uint8List _syntheticFrames() {
  final bytes = Uint8List(_frameCount * _width * _height * 4);
  var offset = 0;
  for (var frame = 0; frame < _frameCount; frame++) {
    for (var pixel = 0; pixel < _width * _height; pixel++) {
      bytes[offset++] = (frame * 40) % 256;
      bytes[offset++] = (pixel * 3) % 256;
      bytes[offset++] = (frame * 11 + pixel) % 256;
      bytes[offset++] = 255;
    }
  }
  return bytes;
}

void main() {
  test('encodes $_frameCount synthetic frames through real ffmpeg.wasm in chrome', () async {
    if (_wasmPath.isEmpty) {
      markTestSkipped(
        'Manual harness: pass --dart-define=FLUVIE_WASM_PATH=<local ffmpeg.wasm> '
        'and run on chrome (see the library dartdoc).',
      );
      return;
    }
    final args =
        (FfmpegArgsBuilder()
              ..addRawVideoInput(name: 'frames.rgba', width: _width, height: _height, fps: 30)
              ..setH264Output(name: 'out.mp4', quality: Quality.low, fps: 30))
            .build();
    Uint8List? output;
    final provider = WasmFfmpegProvider(
      runtime: createWasmRuntime(),
      readInput: (name) async => _syntheticFrames(),
      writeOutput: (name, bytes) => output = bytes,
    );
    await provider.encode(args: args, sandbox: Directory('unused-on-wasm'));
    expect(output, isNotNull);
    expect(output, isNotEmpty);
  }, timeout: Timeout.none);
}
