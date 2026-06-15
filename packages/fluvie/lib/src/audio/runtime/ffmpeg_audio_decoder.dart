import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie/src/audio/runtime/audio_decode_args.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

/// Decodes one audio file to raw 32-bit-float mono PCM at 44.1 kHz by spawning
/// a local FFmpeg binary with the pure [audioDecodeArgs] array.
///
/// This is the thin spawn glue over `dart:io`'s [Process.start]: the argument
/// array is built and validated purely (and unit-tested) by [audioDecodeArgs];
/// only the process plumbing lives here, behind a `// coverage:ignore` because
/// it cannot run without a real binary (it is exercised by the `ffmpeg`-tagged
/// integration test). The PCM stream is read off raw stdout (never the
/// text-decoding `ProcessRunner`, which would corrupt binary samples) and
/// returned as a little-endian [Float32List].
final class FfmpegAudioDecoder {
  /// Creates a decoder running `binaryPath` (default `ffmpeg` on `PATH`).
  const FfmpegAudioDecoder({this.binaryPath = 'ffmpeg'});

  /// The FFmpeg binary this decoder spawns.
  final String binaryPath;

  /// Spawns FFmpeg to decode the sandbox-relative [name] (resolved against
  /// [workingDirectory]) to mono `f32le` PCM at 44.1 kHz.
  ///
  /// Throws a [FluvieRenderException] on a non-zero exit. The returned samples
  /// are reproducible per machine; the bytes themselves are the documented
  /// per-machine exception (ffmpeg builds differ), but the analysis derived
  /// from them is stable.
  // Reason: process glue. It spawns the real ffmpeg binary, so it runs only
  // under the ffmpeg-tagged integration suite, never the unit gate.
  // coverage:ignore-start
  Future<Float32List> decode(String name, {required String workingDirectory}) async {
    final args = audioDecodeArgs(name);
    final process = await Process.start(binaryPath, args, workingDirectory: workingDirectory);
    final stdoutBytes = BytesBuilder(copy: false);
    final stdoutDone = process.stdout.forEach(stdoutBytes.add);
    final stderr = await process.stderr.fold<List<int>>(
      <int>[],
      (acc, chunk) => acc..addAll(chunk),
    );
    final exitCode = await process.exitCode;
    await stdoutDone;
    if (exitCode != 0) {
      throw FluvieRenderException(
        'FFmpeg ("$binaryPath") exited $exitCode decoding audio "$name": '
        '${String.fromCharCodes(stderr)}',
      );
    }
    final bytes = stdoutBytes.toBytes();
    return bytes.buffer.asFloat32List(0, bytes.lengthInBytes ~/ 4);
    // coverage:ignore-end
  }
}
