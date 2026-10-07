import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie/src/audio/runtime/audio_decode_args.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie_media/native.dart' show MediaCancelledException, resolveMediaExecutable;

/// Decodes local audio to mono, little-endian float32 PCM at 44.1 kHz.
///
/// Stdout is bounded by [maxSamples], stderr by 16 KiB, and the owned process
/// is killed and reaped on cancellation, timeout or oversized output. Normal
/// playback does not require this buffer; it is used for reactive analysis.
final class FfmpegAudioDecoder {
  /// Creates a decoder using an explicit, managed or PATH FFmpeg executable.
  /// The default sample limit accepts about six minutes of audio.
  const FfmpegAudioDecoder({
    this._binaryPath,
    this.maxSamples = 16000000,
    this.timeout = const Duration(minutes: 2),
  });

  final String? _binaryPath;

  /// Maximum samples buffered before allocating an analysis buffer.
  final int maxSamples;

  /// Maximum duration of one FFmpeg decode operation.
  final Duration timeout;

  /// Effective explicit, managed, or PATH executable.
  String get binaryPath => resolveMediaExecutable('ffmpeg', explicit: _binaryPath);

  /// Decodes sandbox-relative [name] against [workingDirectory].
  ///
  /// Throws [FluvieRenderException] with source context on decoder failure or
  /// exhausted limits, and [MediaCancelledException] when its owner cancels.
  /// PCM bytes can differ between FFmpeg builds; subsequent DSP is deterministic.
  Future<Float32List> decode(
    String name, {
    required String workingDirectory,
    Future<void>? whenCancelled,
    Duration? start,
    Duration? duration,
  }) async {
    if (maxSamples <= 0) throw ArgumentError.value(maxSamples, 'maxSamples', 'must be positive');
    if (timeout <= Duration.zero) throw ArgumentError.value(timeout, 'timeout', 'must be positive');
    final args = audioDecodeArgs(name, start: start, duration: duration);
    Process? process;
    Timer? timer;
    Exception? failure;
    var finished = false;
    void stop(Exception error) {
      if (finished || failure != null) return;
      failure = error;
      process?.kill(ProcessSignal.sigkill);
    }

    if (whenCancelled != null) {
      unawaited(whenCancelled.then((_) => stop(const MediaCancelledException())));
      await Future<void>.value();
      if (failure != null) throw failure!;
    }
    final executable = binaryPath;
    try {
      final child = await Process.start(executable, args, workingDirectory: workingDirectory);
      process = child;
      if (failure != null) child.kill(ProcessSignal.sigkill);
      timer = Timer(
        timeout,
        () => stop(
          FluvieRenderException(
            'FFmpeg ("$executable") timed out decoding audio "$name" after $timeout. '
            'Check the source or increase FfmpegAudioDecoder.timeout.',
          ),
        ),
      );
      final output = BytesBuilder(copy: false);
      final diagnostics = BytesBuilder(copy: false);
      final stdoutDone = child.stdout.forEach((chunk) {
        if (failure != null) return;
        if (output.length + chunk.length > maxSamples * 4) {
          stop(
            FluvieRenderException(
              'Audio "$name" exceeds $maxSamples PCM samples. Trim the analysis '
              'source, inject a PcmDecoder, or increase FfmpegAudioDecoder.maxSamples.',
            ),
          );
        } else {
          output.add(chunk);
        }
      });
      final stderrDone = child.stderr.forEach((chunk) {
        final remaining = 16384 - diagnostics.length;
        if (remaining > 0) diagnostics.add(chunk.take(remaining).toList());
      });
      final exitCode = await child.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      if (failure != null) throw failure!;
      if (exitCode != 0) {
        throw FluvieRenderException(
          'FFmpeg ("$executable") exited $exitCode decoding audio "$name": '
          '${utf8.decode(diagnostics.takeBytes(), allowMalformed: true)}',
        );
      }
      final bytes = output.takeBytes();
      if (bytes.length % 4 != 0) {
        throw FluvieRenderException(
          'FFmpeg returned an incomplete PCM sample decoding audio "$name".',
        );
      }
      return bytes.buffer.asFloat32List(bytes.offsetInBytes, bytes.length ~/ 4);
    } on ProcessException catch (error) {
      throw FluvieRenderException(
        'Could not start FFmpeg ("$executable") for audio "$name": $error',
      );
    } finally {
      finished = true;
      timer?.cancel();
      process?.kill(ProcessSignal.sigkill);
      await process?.exitCode;
    }
  }
}
