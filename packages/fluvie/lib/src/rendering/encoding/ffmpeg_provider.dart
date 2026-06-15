import 'dart:io';

import 'package:fluvie/src/rendering/encoding/ffmpeg_version.dart';

/// An FFmpeg runtime that can probe its version and run one encode from a
/// pre-built **argument array**.
///
/// Two implementations exist: `ProcessFfmpegProvider` spawns a native binary
/// (desktop/CI) and `WasmFfmpegProvider` drives ffmpeg.wasm in a browser.
/// All argument *planning* happens upstream in `FfmpegArgsBuilder`, so both
/// runtimes execute the identical, fully-validated plan — a provider never
/// composes or rewrites arguments.
abstract interface class FfmpegProvider {
  /// The runtime's FFmpeg version, or `null` for an embedded runtime that has
  /// no honest banner to parse (ffmpeg.wasm ships a pinned build).
  ///
  /// The `>= 6.0` floor is enforced only where a real binary is probed: by
  /// `ProcessFfmpegProvider` and by the CLI's own pre-capture gate.
  Future<FfmpegVersion?> probeVersion();

  /// Runs one encode with exactly [args], resolving every relative file name
  /// against [sandbox] (the per-render temp directory that confines all
  /// inputs and the output).
  ///
  /// Throws `FluvieEncodeException` on any failure — a provider never lets a
  /// raw process or runtime error escape.
  Future<void> encode({required List<String> args, required Directory sandbox});
}
