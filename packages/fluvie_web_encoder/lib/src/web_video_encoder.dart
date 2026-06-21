import 'dart:typed_data';

import 'package:fluvie/fluvie.dart';

/// Encodes the frames a render captured into a [RenderSandbox] to MP4 bytes,
/// using ffmpeg.wasm through Fluvie's [WasmRuntime].
///
/// ffmpeg.wasm **is** FFmpeg, so the encode runs the exact `RenderManifest`
/// argument array the desktop and server paths use — H.264, GIF, transparent
/// WebM, image sequences — with no reimplementation. This driver only moves
/// bytes: it loads the runtime once, copies every file input from the sandbox
/// into the wasm virtual file system, runs the plan, and reads the output back.
final class WebVideoEncoder {
  /// Creates an encoder over [runtime] (defaults to the page's ffmpeg.wasm
  /// bridge via [createWasmRuntime]).
  WebVideoEncoder({WasmRuntime? runtime}) : _runtime = runtime ?? createWasmRuntime();

  final WasmRuntime _runtime;
  Future<void>? _loading;

  /// Encodes the frames in [sandbox] per [manifest], writing the result back
  /// into the sandbox under `manifest.outputFileName` and returning its bytes.
  ///
  /// Throws a [FluvieEncodeException] when ffmpeg.wasm exits non-zero.
  Future<Uint8List> encode({
    required RenderManifest manifest,
    required RenderSandbox sandbox,
  }) async {
    await (_loading ??= _runtime.load());
    for (final name in fileInputNames(manifest.ffmpegArgs)) {
      await _runtime.writeFile(name, await sandbox.readBytes(name));
    }
    final exitCode = await _runtime.exec(manifest.ffmpegArgs);
    if (exitCode != 0) {
      throw FluvieEncodeException('ffmpeg.wasm exited non-zero.', exitCode: exitCode);
    }
    final output = await _runtime.readFile(manifest.outputFileName);
    await sandbox.writeBytes(manifest.outputFileName, output);
    return output;
  }
}

/// The names following `-i` in [args] that are real files to copy into the wasm
/// virtual file system. A `lavfi` input (its `-f lavfi` immediately precedes the
/// `-i`) is a generated source, not a file, and is skipped.
List<String> fileInputNames(List<String> args) {
  final names = <String>[];
  String? pendingFormat;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '-f') pendingFormat = args[i + 1];
    if (args[i] == '-i') {
      if (pendingFormat != 'lavfi') names.add(args[i + 1]);
      pendingFormat = null;
    }
  }
  return names;
}
