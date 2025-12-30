import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../config/fluvie_config.dart';
import 'ffmpeg_provider.dart';

/// FFmpeg provider that uses native process execution.
///
/// This provider works on desktop platforms (Linux, macOS, Windows) where
/// FFmpeg is installed as a system command.
///
/// ## Installation
///
/// FFmpeg must be installed and available in the system PATH:
///
/// - **Linux**: `sudo apt install ffmpeg` or `sudo dnf install ffmpeg`
/// - **macOS**: `brew install ffmpeg`
/// - **Windows**: Download from [ffmpeg.org](https://ffmpeg.org/download.html) and add to PATH
///
/// ## Custom FFmpeg Path
///
/// You can configure a custom FFmpeg path using [FluvieConfig]:
///
/// ```dart
/// FluvieConfig.configure(ffmpegPath: '/opt/ffmpeg/bin/ffmpeg');
/// ```
///
/// Or pass it directly to the constructor:
///
/// ```dart
/// final provider = ProcessFFmpegProvider(ffmpegPath: '/opt/ffmpeg/bin/ffmpeg');
/// FFmpegProviderRegistry.setProvider(provider);
/// ```
class ProcessFFmpegProvider implements FFmpegProvider {
  /// Custom path to the FFmpeg executable.
  ///
  /// If null, uses the configured ffmpeg path or falls back to 'ffmpeg'.
  final String? ffmpegPath;

  /// Factory function for creating processes, used for testing.
  final Future<Process> Function(String executable, List<String> arguments)?
  processFactory;

  /// Factory function for creating temporary directories, used for testing.
  final Future<Directory> Function()? tempDirProvider;

  /// Creates a new ProcessFFmpegProvider.
  ///
  /// [ffmpegPath] - Custom path to FFmpeg executable. If null, uses
  /// the configured path or 'ffmpeg' from PATH.
  ///
  /// For testing, you can provide custom [processFactory] and [tempDirProvider].
  ProcessFFmpegProvider({
    this.ffmpegPath,
    this.processFactory,
    this.tempDirProvider,
  });

  /// Gets the effective FFmpeg executable path.
  String get _ffmpegExecutable =>
      ffmpegPath ?? FluvieConfig.current.ffmpegPath ?? 'ffmpeg';

  @override
  String get name => 'Process (Native)';

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await Process.run(_ffmpegExecutable, ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<FFmpegSession> startSession(FFmpegSessionConfig config) async {
    final available = await isAvailable();
    if (!available) {
      throw FFmpegNotAvailableException(
        'FFmpeg executable not found in PATH',
        installationInstructions: '''
FFmpeg must be installed and available in your system PATH.

Installation instructions:
  Linux:   sudo apt install ffmpeg
  macOS:   brew install ffmpeg
  Windows: Download from https://ffmpeg.org/download.html and add to PATH
''',
      );
    }

    // Create temp directory for output
    final tempDir = tempDirProvider != null
        ? await tempDirProvider!()
        : await Directory.systemTemp.createTemp('fluvie_');
    final outputPath = '${tempDir.path}/${config.outputFileName}';

    // Build FFmpeg arguments
    final args = _buildFFmpegArgs(config, outputPath);

    // Start FFmpeg process
    final process = processFactory != null
        ? await processFactory!(_ffmpegExecutable, args)
        : await Process.start(_ffmpegExecutable, args);

    return _ProcessFFmpegSession(
      process: process,
      config: config,
      outputPath: outputPath,
      tempDir: tempDir,
    );
  }

  List<String> _buildFFmpegArgs(FFmpegSessionConfig config, String outputPath) {
    final args = <String>[
      '-y', // Overwrite output file
      '-f', 'rawvideo',
      '-pixel_format', 'rgba',
      '-video_size', '${config.width}x${config.height}',
      '-framerate', '${config.fps}',
      '-i', '-', // Read from stdin
    ];

    // Add audio inputs
    for (final audio in config.audioInputs) {
      args.addAll(['-i', audio.uri]);
    }

    // Add filter graph if provided
    if (config.filterGraph != null && config.filterGraph!.isNotEmpty) {
      args.addAll(['-filter_complex', config.filterGraph!]);
      if (config.videoOutputLabel != null) {
        args.addAll(['-map', config.videoOutputLabel!]);
      }
      if (config.audioOutputLabel != null) {
        args.addAll(['-map', config.audioOutputLabel!]);
      }
    } else {
      // Default video processing
      args.addAll(['-vf', 'fps=${config.fps},format=${config.pixelFormat}']);
    }

    // Video codec settings
    args.addAll([
      '-c:v',
      config.videoCodec,
      '-preset',
      config.preset,
      '-crf',
      '${config.crf}',
      '-pix_fmt',
      config.pixelFormat,
    ]);

    // Audio codec (if audio present)
    if (config.audioInputs.isNotEmpty) {
      args.addAll(['-c:a', 'aac', '-b:a', '192k']);
    }

    args.add(outputPath);

    return args;
  }

  @override
  Future<void> dispose() async {
    // No global resources to clean up
  }
}

class _ProcessFFmpegSession implements FFmpegSession {
  final Process process;
  final FFmpegSessionConfig config;
  final String outputPath;
  final Directory tempDir;

  final _progressController = StreamController<double>.broadcast();
  final _completedCompleter = Completer<String>();

  int _framesWritten = 0;
  bool _finalized = false;
  final StringBuffer _stderrBuffer = StringBuffer();

  _ProcessFFmpegSession({
    required this.process,
    required this.config,
    required this.outputPath,
    required this.tempDir,
  }) {
    _setupListeners();
  }

  void _setupListeners() {
    // Listen to stderr for progress and errors
    process.stderr
        .transform(utf8.decoder)
        .listen(
          (data) {
            _stderrBuffer.write(data);
            _parseProgress(data);
          },
          onError: (error) {
            // Handle stderr errors
          },
        );

    // Handle process exit
    process.exitCode.then((exitCode) {
      if (!_completedCompleter.isCompleted) {
        if (exitCode == 0) {
          _progressController.add(1.0);
          _completedCompleter.complete(outputPath);
        } else {
          _completedCompleter.completeError(
            FFmpegEncodingException(
              'FFmpeg encoding failed',
              exitCode: exitCode,
              stderrOutput: _stderrBuffer.toString(),
            ),
          );
        }
      }
      _progressController.close();
    });
  }

  void _parseProgress(String data) {
    // FFmpeg outputs progress like: frame=  123 fps=30 ...
    final frameMatch = RegExp(r'frame=\s*(\d+)').firstMatch(data);
    if (frameMatch != null) {
      final frame = int.tryParse(frameMatch.group(1)!) ?? 0;
      final progress = config.totalFrames > 0
          ? (frame / config.totalFrames).clamp(0.0, 1.0)
          : 0.0;
      _progressController.add(progress);
    }
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

    process.stdin.add(rgbaBytes);
    _framesWritten++;

    // Update progress
    if (config.totalFrames > 0) {
      final progress = (_framesWritten / config.totalFrames).clamp(0.0, 0.99);
      _progressController.add(progress);
    }
  }

  @override
  Future<void> finalize() async {
    if (_finalized) return;
    _finalized = true;

    await process.stdin.close();
    // Wait for process to complete (handled by exitCode listener)
  }

  @override
  Future<void> cancel() async {
    _finalized = true;
    process.kill(ProcessSignal.sigterm);

    if (!_completedCompleter.isCompleted) {
      _completedCompleter.completeError(
        FFmpegEncodingException('Encoding cancelled by user'),
      );
    }
    _progressController.close();

    // Clean up temp files
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // Ignore cleanup errors
    }
  }
}
