import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie/src/rendering/encoding/frame_extraction_cache_identity.dart';
import 'package:fluvie/src/rendering/encoding/frame_extraction_service.dart';
import 'package:fluvie/src/rendering/encoding/frame_extraction_session.dart';
import 'package:fluvie/src/rendering/platform/process_runner.dart';
import 'package:fluvie/src/rendering/render_cancellation.dart';
import 'package:fluvie_media/native.dart';
import 'package:riverpod/riverpod.dart';

part 'ffmpeg_frame_extraction_session.dart';
part 'ffmpeg_frame_extraction_io.dart';
part 'ffmpeg_frame_extraction_identity.dart';

/// The real [FrameExtractionService]: spawns FFmpeg through a [ProcessRunner]
/// with a typed **argument array** (never a shell string) and reads back one
/// decoded frame as a [RawFrame].
///
/// The frame is selected with `select=eq(n\,k)` and scaled to the requested
/// size, then written as raw RGBA8888 to a sandbox-relative file FFmpeg writes
/// in its working directory. The bytes are read straight back from that file —
/// never piped through stdout — because a [ProcessRunner] decodes stdout as
/// *text*, which would corrupt binary pixels. A non-zero exit is a
/// [FluvieEncodeException] carrying the stderr tail; a payload of the wrong
/// length is a [FluvieRenderException]. Every path argument is validated so it
/// can never be parsed as a flag.
///
/// Inputs must already be materialized as local files. Native input protocols
/// are restricted to `file`; the media loader stages allowlisted network clips
/// before they reach this service.
final class FfmpegFrameExtractionService
    implements FrameExtractionService, FrameExtractionSessionService, FrameExtractionCacheIdentity {
  /// Creates a service using `binaryPath` (default `ffmpeg`).
  /// Batched native extraction owns and terminates the default decoder process
  /// on timeout. An injected runner owns its own process cancellation.
  const FfmpegFrameExtractionService({
    this._runner = const IoProcessRunner(),
    this._binaryPath,
    this.timeout = const Duration(minutes: 3),
    this._cacheIdentity,
  });

  /// How much trailing stderr is retained for diagnostics (4 KiB).
  static const int stderrTailLength = 4096;

  final ProcessRunner _runner;
  final String? _cacheIdentity;

  /// Explicit identity for custom runners, or the native executable/build digest.
  ///
  /// Native metadata is memoized by canonical executable path, size and times;
  /// replacing the executable invalidates that entry. Unidentified injected
  /// runners and unavailable build metadata disable persistent frame reuse.
  @override
  Future<String?> get cacheIdentity => _frameExtractionCacheIdentity(this);

  /// Maximum lifetime of one batched decoder process.
  final Duration timeout;

  /// The FFmpeg binary this service spawns (default `ffmpeg` on `PATH`).
  final String? _binaryPath;

  /// Effective explicit, managed, or PATH executable.
  String get binaryPath => resolveMediaExecutable('ffmpeg', explicit: _binaryPath);

  @override
  Future<FrameExtractionSession> openSession(
    Uri source, {
    required int width,
    required int height,
    String? decoder,
    Future<void>? whenCancelled,
  }) => _openExtractionSession(
    this,
    source,
    width: width,
    height: height,
    decoder: decoder,
    whenCancelled: whenCancelled,
  );

  @override
  Future<RawFrame> extractFrame(
    Uri source,
    int frameIndex, {
    required int width,
    required int height,
    String? decoder,
  }) async {
    if (frameIndex < 0) {
      throw ArgumentError.value(frameIndex, 'frameIndex', 'must not be negative');
    }
    final path = _validatedPath(source);
    final validatedDecoder = _validatedDecoder(decoder);
    final sandbox = await Directory.systemTemp.createTemp('fluvie_clip_frame_');
    try {
      const outputName = 'frame.rgba';
      final result = await _runner.run(
        binaryPath,
        _args(
          path: path,
          frameIndex: frameIndex,
          width: width,
          height: height,
          output: outputName,
          decoder: validatedDecoder,
        ),
        workingDirectory: sandbox.path,
      );
      if (result.exitCode != 0) {
        throw FluvieEncodeException(
          'FFmpeg ("$binaryPath") exited non-zero extracting frame $frameIndex of "$source".',
          exitCode: result.exitCode,
          stderrTail: _tail(result.stderr),
        );
      }
      final bytes = await _readOutput(File('${sandbox.path}/$outputName'), source, frameIndex);
      final expected = width * height * 4;
      if (bytes.length != expected) {
        throw FluvieRenderException(
          'FFmpeg produced ${bytes.length} bytes for frame $frameIndex of "$source", '
          'expected $expected (${width}x$height RGBA).',
        );
      }
      return RawFrame(frameIndex: frameIndex, width: width, height: height, rgba: bytes);
    } finally {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    }
  }

  @override
  Future<Map<int, RawFrame>> extractFrames(
    Uri source,
    Iterable<int> frameIndices, {
    required int width,
    required int height,
    String? decoder,
  }) async {
    final tools = FfmpegMediaTools(
      ffmpegPath: binaryPath,
      timeout: timeout,
      // Process.run exposes no child handle: wrapping the default IO runner
      // would bypass the tools' timeout termination and leave FFmpeg alive.
      runner: _runner is IoProcessRunner
          ? null
          : (executable, args, {workingDirectory}) async {
              final result = await _runner.run(
                executable,
                args,
                workingDirectory: workingDirectory,
              );
              return (exitCode: result.exitCode, stdout: result.stdout, stderr: result.stderr);
            },
    );
    try {
      final decoded = await tools.extractFrames(
        source,
        frameIndices,
        width: width,
        height: height,
        decoder: decoder,
      );
      return {
        for (final entry in decoded.entries)
          entry.key: RawFrame(
            frameIndex: entry.key,
            width: width,
            height: height,
            rgba: entry.value.rgba,
          ),
      };
    } on MediaProcessException catch (error) {
      if (error.exitCode != null) {
        throw FluvieEncodeException(
          error.message,
          exitCode: error.exitCode,
          stderrTail: error.stderr,
        );
      }
      throw FluvieRenderException(error.toString());
    } finally {
      tools.close();
    }
  }
}

/// The frame extractor used by the clip render path; defaults to
/// [FfmpegFrameExtractionService] over [processRunnerProvider] and is
/// overridable with a fake in tests.
final frameExtractionServiceProvider = Provider<FrameExtractionService>(
  (ref) => FfmpegFrameExtractionService(runner: ref.watch(processRunnerProvider)),
);
