// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'ffmpeg_provider.dart';

/// JS interop bindings for ffmpeg.wasm
@JS('FFmpeg')
extension type FFmpegJS._(JSObject _) implements JSObject {
  external factory FFmpegJS();

  @JS('load')
  external JSPromise<JSAny?> load();

  @JS('writeFile')
  external JSPromise<JSAny?> writeFile(JSString name, JSUint8Array data);

  @JS('readFile')
  external JSPromise<JSUint8Array> readFile(JSString name);

  @JS('exec')
  external JSPromise<JSNumber> exec(JSArray<JSString> args);

  @JS('on')
  external void on(JSString event, JSFunction callback);

  @JS('terminate')
  external JSPromise<JSAny?> terminate();
}

/// Checks if ffmpeg.wasm is available.
@JS('FFmpeg')
external JSObject? get _ffmpegConstructor;

bool _isLoaded = false;
FFmpegJS? _ffmpegInstance;

Future<bool> isAvailable() async {
  if (_ffmpegConstructor == null) {
    return false;
  }

  // Check if SharedArrayBuffer is available (required by ffmpeg.wasm)
  try {
    // Try to create a SharedArrayBuffer - will throw if not available
    web.window.crossOriginIsolated;
    return true;
  } catch (_) {
    return false;
  }
}

Future<FFmpegSession> startSession(FFmpegSessionConfig config) async {
  final available = await isAvailable();
  if (!available) {
    throw FFmpegNotAvailableException(
      'ffmpeg.wasm is not available',
      installationInstructions: '''
To use FFmpeg on the web:

1. Add the following scripts to your web/index.html:
   <script src="https://unpkg.com/@ffmpeg/ffmpeg@0.12.6/dist/umd/ffmpeg.js"></script>
   <script src="https://unpkg.com/@ffmpeg/util@0.12.1/dist/umd/util.js"></script>

2. Configure your server with these headers:
   Cross-Origin-Embedder-Policy: require-corp
   Cross-Origin-Opener-Policy: same-origin

For local development with Flutter, you may need to use a custom server
that sets these headers.
''',
    );
  }

  // Create or reuse FFmpeg instance
  if (_ffmpegInstance == null || !_isLoaded) {
    _ffmpegInstance = FFmpegJS();
    await _ffmpegInstance!.load().toDart;
    _isLoaded = true;
  }

  return _WasmFFmpegSession(ffmpeg: _ffmpegInstance!, config: config);
}

Future<void> dispose() async {
  if (_ffmpegInstance != null) {
    await _ffmpegInstance!.terminate().toDart;
    _ffmpegInstance = null;
    _isLoaded = false;
  }
}

class _WasmFFmpegSession implements FFmpegSession {
  final FFmpegJS ffmpeg;
  final FFmpegSessionConfig config;

  final _progressController = StreamController<double>.broadcast();
  final _completedCompleter = Completer<String>();

  final List<Uint8List> _frameBuffer = [];
  int _framesWritten = 0;
  bool _finalized = false;

  _WasmFFmpegSession({required this.ffmpeg, required this.config}) {
    _setupProgressListener();
  }

  void _setupProgressListener() {
    ffmpeg.on(
      'progress'.toJS,
      ((JSObject event) {
        final progress = (event as JSAny).dartify();
        if (progress is Map && progress.containsKey('ratio')) {
          final ratio = progress['ratio'] as num;
          _progressController.add(ratio.toDouble().clamp(0.0, 1.0));
        }
      }).toJS,
    );
  }

  @override
  Stream<double> get progress => _progressController.stream;

  @override
  Future<String> get completed => _completedCompleter.future;

  @override
  Future<void> addFrame(Uint8List rgbaBytes) async {
    if (_finalized) {
      throw StateError('Cannot add frames after finalize() was called');
    }

    _frameBuffer.add(rgbaBytes);
    _framesWritten++;

    // Update progress
    if (config.totalFrames > 0) {
      final progress = (_framesWritten / config.totalFrames).clamp(0.0, 0.5);
      _progressController.add(progress);
    }
  }

  @override
  Future<void> finalize() async {
    if (_finalized) return;
    _finalized = true;

    try {
      // Concatenate all frames into a single buffer
      final totalSize = _frameBuffer.fold<int>(
        0,
        (sum, frame) => sum + frame.length,
      );
      final rawVideo = Uint8List(totalSize);
      var offset = 0;
      for (final frame in _frameBuffer) {
        rawVideo.setRange(offset, offset + frame.length, frame);
        offset += frame.length;
      }
      _frameBuffer.clear();

      // Write raw video to virtual filesystem
      await ffmpeg.writeFile('input.raw'.toJS, rawVideo.toJS).toDart;

      // Build FFmpeg arguments
      final args = _buildFFmpegArgs();

      // Run FFmpeg
      final result = await ffmpeg
          .exec(args.map((a) => a.toJS).toList().toJS)
          .toDart;
      final exitCode = result.toDartInt;

      if (exitCode != 0) {
        throw FFmpegEncodingException(
          'FFmpeg encoding failed',
          exitCode: exitCode,
        );
      }

      // Read output file
      final outputData = await ffmpeg
          .readFile(config.outputFileName.toJS)
          .toDart;

      // Create blob URL for the output
      final blob = web.Blob(
        [outputData].toJS,
        web.BlobPropertyBag(type: 'video/mp4'),
      );
      final blobUrl = web.URL.createObjectURL(blob);

      _progressController.add(1.0);
      _completedCompleter.complete(blobUrl);
    } catch (e) {
      if (!_completedCompleter.isCompleted) {
        _completedCompleter.completeError(
          e is FFmpegEncodingException
              ? e
              : FFmpegEncodingException('Encoding failed: $e'),
        );
      }
    } finally {
      _progressController.close();
    }
  }

  List<String> _buildFFmpegArgs() {
    final args = <String>[
      '-f',
      'rawvideo',
      '-pixel_format',
      'rgba',
      '-video_size',
      '${config.width}x${config.height}',
      '-framerate',
      '${config.fps}',
      '-i',
      'input.raw',
    ];

    // Note: Audio mixing in WASM is more limited
    // For now, we just encode the video

    if (config.filterGraph != null && config.filterGraph!.isNotEmpty) {
      args.addAll(['-filter_complex', config.filterGraph!]);
      if (config.videoOutputLabel != null) {
        args.addAll(['-map', config.videoOutputLabel!]);
      }
    } else {
      args.addAll(['-vf', 'fps=${config.fps},format=${config.pixelFormat}']);
    }

    args.addAll([
      '-c:v',
      config.videoCodec,
      '-preset',
      config.preset,
      '-crf',
      '${config.crf}',
      '-pix_fmt',
      config.pixelFormat,
      config.outputFileName,
    ]);

    return args;
  }

  @override
  Future<void> cancel() async {
    _finalized = true;
    _frameBuffer.clear();

    if (!_completedCompleter.isCompleted) {
      _completedCompleter.completeError(
        FFmpegEncodingException('Encoding cancelled by user'),
      );
    }
    _progressController.close();
  }
}
