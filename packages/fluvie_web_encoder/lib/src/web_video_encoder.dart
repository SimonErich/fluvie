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
      // An `image2` `%0Nd` pattern (the bounded-memory PNG frame input) is not a
      // single file: expand it to the per-frame files and copy each in.
      final files = name.contains('%') ? expandImagePattern(name, manifest.frameCount) : [name];
      for (final file in files) {
        await _runtime.writeFile(file, await sandbox.readBytes(file));
      }
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

/// Expands an `image2` [pattern] like `frame_%06d.png` into [count] concrete
/// frame file names (`frame_000000.png`, `frame_000001.png`, …) — the per-frame
/// PNG inputs ffmpeg.wasm reads via the pattern. A pattern with no `%0Nd` token
/// is returned unchanged.
List<String> expandImagePattern(String pattern, int count) {
  final match = RegExp(r'%0(\d+)d').firstMatch(pattern);
  if (match == null) return [pattern];
  final pad = int.parse(match.group(1)!);
  return [
    for (var i = 0; i < count; i++)
      pattern.replaceFirst(match.group(0)!, i.toString().padLeft(pad, '0')),
  ];
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
