import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_version.dart';
import 'package:fluvie/src/rendering/platform/wasm_runtime.dart';

/// Reads one named encode input (for example `frames.rgba`) as bytes.
typedef WasmInputReader = Future<Uint8List> Function(String name);

/// Receives the encoded output file's bytes under its name.
typedef WasmOutputWriter = void Function(String name, Uint8List bytes);

/// The browser [FfmpegRunner]: drives ffmpeg.wasm through a [WasmRuntime].
///
/// All argument *planning* is shared with the native path (the same
/// `FfmpegArgsBuilder` plan runs unchanged); this provider only moves bytes:
/// it lazily loads the runtime exactly once, copies every file input into the
/// wasm virtual file system via the injected reader, executes the plan, and
/// hands the output bytes to the injected writer. The `sandbox` directory is
/// unused — a browser has no real file system, so the callbacks *are* the IO.
final class WasmFfmpegRunner implements FfmpegRunner {
  /// Creates a provider over `runtime`, reading inputs through `readInput`
  /// and delivering the encoded file through `writeOutput`.
  WasmFfmpegRunner({
    required this._runtime,
    required this._readInput,
    required this._writeOutput,
  });

  final WasmRuntime _runtime;
  final WasmInputReader _readInput;
  final WasmOutputWriter _writeOutput;
  Future<void>? _loading;

  /// Always `null`: ffmpeg.wasm ships a pinned build with no honest version
  /// banner to parse, so no floor check happens here.
  @override
  Future<FfmpegVersion?> probeVersion() async => null;

  @override
  Future<void> encode({required List<String> args, required Directory sandbox}) async {
    await (_loading ??= _runtime.load());
    for (final name in _fileInputNames(args)) {
      await _runtime.writeFile(name, await _readInput(name));
    }
    final exitCode = await _runtime.exec(args);
    if (exitCode != 0) {
      throw FluvieEncodeException('ffmpeg.wasm exited non-zero.', exitCode: exitCode);
    }
    final outputName = args.last;
    _writeOutput(outputName, await _runtime.readFile(outputName));
  }

  /// The names following `-i` that are real files to copy into the wasm FS.
  /// A `lavfi` input (its `-f lavfi` immediately precedes the `-i`) is a
  /// generated source, not a file, and is skipped.
  static List<String> _fileInputNames(List<String> args) {
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
}
