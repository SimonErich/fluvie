import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie_media/src/frame_batch.dart';
import 'package:fluvie_media/src/media_cancelled_exception.dart';
import 'package:fluvie_media/src/media_contact_sheet.dart';
import 'package:fluvie_media/src/media_contact_sheet_cell.dart';
import 'package:fluvie_media/src/media_frame.dart';
import 'package:fluvie_media/src/media_process_exception.dart';
import 'package:fluvie_media/src/media_process_runner.dart';
import 'package:fluvie_media/src/media_process_starter.dart';
import 'package:fluvie_media/src/media_source_info.dart';
import 'package:fluvie_media/src/media_timeline.dart';
import 'package:fluvie_media/src/native_tool_paths.dart';

export 'package:fluvie_media/src/media_process_exception.dart';
export 'package:fluvie_media/src/media_process_runner.dart';
export 'package:fluvie_media/src/media_process_starter.dart';

part 'ffmpeg_contact_sheet.dart';
part 'ffmpeg_frame_session.dart';
part 'ffmpeg_frame_session_process.dart';
part 'ffmpeg_media_extraction.dart';
part 'ffmpeg_media_index.dart';
part 'ffmpeg_media_probe.dart';
part 'ffmpeg_media_process.dart';

/// Native probing and exact batched frame extraction, with no Flutter imports.
/// Sources must be local paths or file URIs. Download permitted network media
/// through the caller's allowlisted loader before passing its staged local path.
/// Managed probes and decoders restrict FFmpeg input protocols to local files.
final class FfmpegMediaTools {
  /// Creates tools with exact binaries and bounded process lifetime.
  /// [processStarter] supplies owned streaming processes; the text `runner`
  /// adapter, when supplied, handles collected-output operations instead.
  FfmpegMediaTools({
    String? ffmpegPath,
    String? ffprobePath,
    this._runner,
    MediaProcessStarter? processStarter,
    this.timeout = const Duration(minutes: 3),
  }) : _startProcess = processStarter ?? Process.start,
       ffmpegPath = resolveMediaExecutable('ffmpeg', explicit: ffmpegPath),
       ffprobePath = resolveMediaExecutable('ffprobe', explicit: ffprobePath);

  /// Encoder and decoder executable.
  final String ffmpegPath;

  /// Probe executable.
  final String ffprobePath;

  /// Maximum lifetime of one probe/decode operation.
  final Duration timeout;
  final MediaProcessRunner? _runner;
  final MediaProcessStarter _startProcess;
  final _processes = <Process>{};
  final _sessions = <FfmpegFrameSession>{};
  bool _closed = false;
  static const _localInputProtocols = ['-protocol_whitelist', 'file'];

  /// Original ffprobe report, including audio, alpha, display rotation and rates.
  Future<Map<String, Object?>> probeReport(String path, {Future<void>? whenCancelled}) async {
    final result = await run(ffprobePath, [
      '-v',
      'error',
      '-print_format',
      'json',
      '-show_streams',
      '-show_format',
      ..._localInputProtocols,
      _path(path),
    ], whenCancelled: whenCancelled);
    if (result.exitCode != 0) throw _failure('Probing "$path"', result);
    final Object? decoded;
    try {
      decoded = jsonDecode(result.stdout);
    } on FormatException catch (error) {
      throw MediaProcessException('Invalid ffprobe JSON for "$path": ${error.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw MediaProcessException('ffprobe returned no object for "$path".');
    }
    return decoded;
  }

  /// Probes a video and counts frames when the container has no count header.
  Future<MediaSourceInfo> probe(String path, {Future<void>? whenCancelled}) =>
      _probeSource(path, whenCancelled: whenCancelled);

  /// Extracts sorted, unique source frames in bounded forward-decoding batches.
  /// Missing indices fail explicitly; output frames are never duplicated.
  Future<Map<int, MediaFrame>> extractFrames(
    Uri source,
    Iterable<int> indices, {
    required int width,
    required int height,
    String? decoder,
    int maxBytes = defaultFrameBatchBytes,
  }) => _extractFrames(
    source,
    indices,
    width: width,
    height: height,
    decoder: decoder,
    maxBytes: maxBytes,
  );

  /// Runs an owned process. Disposal and timeouts terminate its children.
  /// This low-level operation uses caller-supplied arguments unchanged; callers
  /// must validate inputs and set protocol restrictions for their own commands.
  Future<MediaProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Future<void>? whenCancelled,
  }) => _runOwnedProcess(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    whenCancelled: whenCancelled,
  );

  /// Stops active children. Calling twice is harmless.
  void close() {
    _closed = true;
    for (final session in _sessions.toList()) {
      unawaited(session.close());
    }
    for (final process in _processes) {
      process.kill(ProcessSignal.sigkill);
    }
  }

  /// Closes owned sessions and waits until every active child has exited.
  Future<void> closeAsync() async {
    final sessions = _sessions.toList();
    final processes = _processes.toList();
    close();
    await Future.wait(sessions.map((session) => session.close()));
    await Future.wait(processes.map((process) => process.exitCode));
  }

  static String _path(String path) {
    if (path.isEmpty || path.startsWith('-')) {
      throw ArgumentError.value(path, 'source', 'must be a nonempty path, not a flag');
    }
    final drivePath = RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path);
    if (!drivePath && RegExp('^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(path)) {
      final uri = Uri.tryParse(path);
      if (uri == null || uri.scheme != 'file' || (uri.host.isNotEmpty && uri.host != 'localhost')) {
        throw ArgumentError.value(path, 'source', 'stage network media as a local file first');
      }
      return _path(uri.replace(host: '').toFilePath());
    }
    return path;
  }

  static String _tail(String text) =>
      text.length > 4096 ? text.substring(text.length - 4096) : text;
  static MediaProcessException _failure(String operation, MediaProcessResult result) =>
      MediaProcessException(
        '$operation failed (exit ${result.exitCode}).',
        exitCode: result.exitCode,
        stderr: _tail(result.stderr),
      );
}
