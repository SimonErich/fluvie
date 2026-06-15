import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

/// An encoding failure: FFmpeg (native process or wasm runtime) exited
/// non-zero, produced no output, or could not be probed at a usable version.
///
/// Carries the process [exitCode] and the retained [stderrTail] when the
/// runner provides them, so the actual FFmpeg diagnostic reaches the caller
/// instead of a bare "encode failed". Both are optional: a wasm runtime may
/// surface neither.
class FluvieEncodeException extends FluvieRenderException {
  /// Creates an encode exception described by `message`, optionally carrying
  /// the process [exitCode] and the last portion of its stderr.
  FluvieEncodeException(super.message, {this.exitCode, this.stderrTail});

  /// The encoder process's exit code, or `null` when no process was spawned
  /// (or the runtime reports none).
  final int? exitCode;

  /// The tail of the encoder's stderr output (the runner retains the last
  /// few KiB), or `null` when none was captured.
  final String? stderrTail;

  @override
  String toString() {
    final buffer = StringBuffer('FluvieEncodeException: $message');
    if (exitCode != null) buffer.write(' (exit code $exitCode)');
    if (stderrTail != null) buffer.write('\nstderr tail:\n$stderrTail');
    return buffer.toString();
  }
}
