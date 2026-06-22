import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie/src/rendering/encoding/frame_extraction_service.dart';
import 'package:fluvie/src/rendering/platform/process_runner.dart';
import 'package:riverpod/riverpod.dart';

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
final class FfmpegFrameExtractionService implements FrameExtractionService {
  /// Creates a service running `binaryPath` (default `ffmpeg`) through `runner`.
  const FfmpegFrameExtractionService({
    this._runner = const IoProcessRunner(),
    this.binaryPath = 'ffmpeg',
  });

  /// How much trailing stderr is retained for diagnostics (4 KiB).
  static const int stderrTailLength = 4096;

  final ProcessRunner _runner;

  /// The FFmpeg binary this service spawns (default `ffmpeg` on `PATH`).
  final String binaryPath;

  @override
  Future<RawFrame> extractFrame(
    Uri source,
    int frameIndex, {
    required int width,
    required int height,
  }) async {
    if (frameIndex < 0) {
      throw ArgumentError.value(frameIndex, 'frameIndex', 'must not be negative');
    }
    final path = _validatedPath(source);
    final sandbox = await Directory.systemTemp.createTemp('fluvie_clip_frame_');
    try {
      const outputName = 'frame.rgba';
      final result = await _runner.run(
        binaryPath,
        _args(path: path, frameIndex: frameIndex, width: width, height: height, output: outputName),
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
  }) async {
    final frames = <int, RawFrame>{};
    for (final index in frameIndices) {
      frames[index] = await extractFrame(source, index, width: width, height: height);
    }
    return frames;
  }

  /// The typed extraction argument array — a frame select + scale filter, one
  /// rawvideo frame, written to the sandbox-relative [output] file.
  static List<String> _args({
    required String path,
    required int frameIndex,
    required int width,
    required int height,
    required String output,
  }) => [
    '-v',
    'error',
    '-nostdin',
    '-i',
    path,
    '-vf',
    'select=eq(n\\,$frameIndex),scale=$width:$height',
    '-frames:v',
    '1',
    '-f',
    'rawvideo',
    '-pix_fmt',
    'rgba',
    '-y',
    output,
  ];

  Future<Uint8List> _readOutput(File file, Uri source, int frameIndex) async {
    if (!file.existsSync()) {
      throw FluvieRenderException(
        'FFmpeg wrote no frame file for frame $frameIndex of "$source".',
      );
    }
    return file.readAsBytes();
  }

  /// Maps [source] to a local file path and rejects anything that could be
  /// parsed as a flag (a leading `-`) or is empty — flag-injection safety.
  static String _validatedPath(Uri source) {
    final path = source.isScheme('file') ? source.toFilePath() : source.toString();
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'source', 'must not be empty');
    }
    if (path.startsWith('-')) {
      throw ArgumentError.value(path, 'source', 'must not start with "-" (flag injection)');
    }
    return path;
  }

  static String _tail(String stderr) => stderr.length <= stderrTailLength
      ? stderr
      : stderr.substring(stderr.length - stderrTailLength);
}

/// The frame extractor used by the clip render path; defaults to
/// [FfmpegFrameExtractionService] over [processRunnerProvider] and is
/// overridable with a fake in tests.
final frameExtractionServiceProvider = Provider<FrameExtractionService>(
  (ref) => FfmpegFrameExtractionService(runner: ref.watch(processRunnerProvider)),
);
