import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie/src/encoding/ffmpeg_provider/ffmpeg_provider.dart';

// =============================================================================
// FakeProcess - Mock Process for FFmpeg testing
// =============================================================================

/// A fake [Process] implementation for testing FFmpeg encoding.
///
/// Allows simulating FFmpeg behavior without actually running the process.
///
/// Example:
/// ```dart
/// late FakeProcess fakeProcess;
///
/// Future<Process> fakeFactory(String executable, List<String> args) async {
///   expect(executable, equals('ffmpeg'));
///   fakeProcess = FakeProcess();
///   return fakeProcess;
/// }
///
/// final service = VideoEncoderService(processFactory: fakeFactory);
/// // ... start encoding ...
/// fakeProcess.complete(0); // Simulate success
/// ```
class FakeProcess implements Process {
  final _stdinController = StreamController<List<int>>();
  final _stdoutController = StreamController<List<int>>.broadcast();
  final _stderrController = StreamController<List<int>>.broadcast();
  final _exitCodeCompleter = Completer<int>();

  bool _killed = false;
  IOSink? _stdin;

  /// Bytes written to stdin by the encoder.
  final List<List<int>> stdinData = [];

  /// Whether the process has been killed.
  bool get killed => _killed;

  FakeProcess() {
    _stdin = IOSink(_stdinController.sink);

    // Capture stdin data
    _stdinController.stream.listen((data) {
      stdinData.add(data);
    });
  }

  /// Emits a message to stderr (simulating FFmpeg output).
  void emitStderr(String message) {
    _stderrController.add(utf8.encode(message));
  }

  /// Emits a message to stdout.
  void emitStdout(String message) {
    _stdoutController.add(utf8.encode(message));
  }

  /// Simulates FFmpeg progress output.
  ///
  /// FFmpeg reports progress via stderr in format like:
  /// `frame=  100 fps=30 q=28.0 size=    1234kB time=00:00:03.33`
  void emitProgress({
    required int frame,
    int fps = 30,
    double q = 28.0,
    int sizeKb = 1024,
  }) {
    final timeSeconds = frame / fps;
    final hours = (timeSeconds / 3600).floor();
    final minutes = ((timeSeconds % 3600) / 60).floor();
    final seconds = timeSeconds % 60;
    final timeStr = '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toStringAsFixed(2).padLeft(5, '0')}';

    emitStderr(
        'frame=$frame fps=$fps q=$q size=${sizeKb}kB time=$timeStr speed=1x\n');
  }

  /// Completes the process with the given exit code.
  void complete(int exitCode) {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(exitCode);
    }
    _stdinController.close();
    _stdoutController.close();
    _stderrController.close();
  }

  /// Completes the process after a delay.
  Future<void> completeAfter(Duration delay, int exitCode) async {
    await Future.delayed(delay);
    complete(exitCode);
  }

  @override
  IOSink get stdin => _stdin!;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _killed = true;
    complete(-signal.hashCode);
    return true;
  }

  @override
  int get pid => 12345;
}

// =============================================================================
// MockFFmpegProvider - Mock FFmpeg provider for testing
// =============================================================================

/// A mock [FFmpegProvider] for testing without actual FFmpeg execution.
class MockFFmpegProvider implements FFmpegProvider {
  /// Whether FFmpeg should be reported as available.
  final bool isAvailable;

  /// The version string to return.
  final String version;

  /// Process factory to use for creating processes.
  final Future<Process> Function(List<String> args)? processFactory;

  /// All commands that have been executed.
  final List<List<String>> executedCommands = [];

  /// Whether to fail the next command.
  bool failNextCommand = false;

  /// Error message for failed commands.
  String failureMessage = 'Mock failure';

  MockFFmpegProvider({
    this.isAvailable = true,
    this.version = 'ffmpeg version 5.0.0-mock',
    this.processFactory,
  });

  @override
  Future<bool> checkAvailability() async => isAvailable;

  @override
  Future<String> getVersion() async => version;

  @override
  Future<Process> startProcess(List<String> args) async {
    executedCommands.add(args);

    if (failNextCommand) {
      failNextCommand = false;
      final process = FakeProcess();
      process.emitStderr(failureMessage);
      process.complete(1);
      return process;
    }

    if (processFactory != null) {
      return processFactory!(args);
    }

    // Return a successful mock process by default
    final process = FakeProcess();
    Future.delayed(const Duration(milliseconds: 10), () {
      process.complete(0);
    });
    return process;
  }

  @override
  String get name => 'mock';

  @override
  int get priority => 0;

  /// Clears the list of executed commands.
  void clearCommands() {
    executedCommands.clear();
  }

  /// Sets up the provider to fail the next command.
  void setNextCommandToFail([String message = 'Mock failure']) {
    failNextCommand = true;
    failureMessage = message;
  }
}

// =============================================================================
// MockDirectory - Mock temporary directory for testing
// =============================================================================

/// A mock temporary directory that tracks created files.
class MockTempDirectory {
  final String path;
  final List<String> createdFiles = [];
  bool _deleted = false;

  MockTempDirectory(this.path);

  bool get deleted => _deleted;

  void addFile(String fileName) {
    createdFiles.add('$path/$fileName');
  }

  void delete() {
    _deleted = true;
  }
}

/// Factory for creating mock temp directories in tests.
class MockTempDirectoryFactory {
  final List<MockTempDirectory> createdDirs = [];
  int _counter = 0;

  Future<Directory> create(String prefix) async {
    final mockDir = MockTempDirectory('/tmp/${prefix}_${_counter++}');
    createdDirs.add(mockDir);
    return _FakeDirectory(mockDir.path);
  }

  void clear() {
    createdDirs.clear();
    _counter = 0;
  }
}

class _FakeDirectory implements Directory {
  @override
  final String path;

  _FakeDirectory(this.path);

  @override
  Future<Directory> createTemp([String? prefix]) async {
    return _FakeDirectory(
        '$path/${prefix ?? 'temp'}_${DateTime.now().millisecondsSinceEpoch}');
  }

  @override
  Future<Directory> create({bool recursive = false}) async => this;

  @override
  Future<bool> exists() async => true;

  @override
  Future<Directory> delete({bool recursive = false}) async => this;

  // Stub remaining Directory methods
  @override
  Directory get absolute => this;

  @override
  Stream<FileSystemEntity> list(
      {bool recursive = false, bool followLinks = true}) {
    return const Stream.empty();
  }

  @override
  List<FileSystemEntity> listSync(
          {bool recursive = false, bool followLinks = true}) =>
      [];

  @override
  Directory get parent =>
      _FakeDirectory(path.substring(0, path.lastIndexOf('/')));

  @override
  Uri get uri => Uri.file(path);

  @override
  void createSync({bool recursive = false}) {}

  @override
  bool existsSync() => true;

  @override
  void deleteSync({bool recursive = false}) {}

  @override
  String resolveSymbolicLinksSync() => path;

  @override
  Future<String> resolveSymbolicLinks() async => path;

  @override
  Future<FileStat> stat() async => throw UnimplementedError();

  @override
  FileStat statSync() => throw UnimplementedError();

  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<Directory> rename(String newPath) async => _FakeDirectory(newPath);

  @override
  Directory renameSync(String newPath) => _FakeDirectory(newPath);

  @override
  bool get isAbsolute => path.startsWith('/');
}

// =============================================================================
// Frame Data Generators for Testing
// =============================================================================

/// Generates RGBA frame data for testing frame capture.
class FrameDataGenerator {
  /// Generates a solid color frame as raw RGBA bytes.
  static Uint8List solidColorFrame({
    required int width,
    required int height,
    int r = 255,
    int g = 0,
    int b = 0,
    int a = 255,
  }) {
    final pixelCount = width * height;
    final data = Uint8List(pixelCount * 4);

    for (var i = 0; i < pixelCount; i++) {
      final offset = i * 4;
      data[offset] = r;
      data[offset + 1] = g;
      data[offset + 2] = b;
      data[offset + 3] = a;
    }

    return data;
  }

  /// Generates a gradient frame (left to right) as raw RGBA bytes.
  static Uint8List horizontalGradientFrame({
    required int width,
    required int height,
    int startR = 0,
    int startG = 0,
    int startB = 0,
    int endR = 255,
    int endG = 255,
    int endB = 255,
  }) {
    final data = Uint8List(width * height * 4);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final t = x / (width - 1);
        final offset = (y * width + x) * 4;
        data[offset] = (startR + (endR - startR) * t).round();
        data[offset + 1] = (startG + (endG - startG) * t).round();
        data[offset + 2] = (startB + (endB - startB) * t).round();
        data[offset + 3] = 255;
      }
    }

    return data;
  }

  /// Generates a checkerboard pattern frame as raw RGBA bytes.
  static Uint8List checkerboardFrame({
    required int width,
    required int height,
    int cellSize = 16,
    int color1R = 255,
    int color1G = 255,
    int color1B = 255,
    int color2R = 0,
    int color2G = 0,
    int color2B = 0,
  }) {
    final data = Uint8List(width * height * 4);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final cellX = x ~/ cellSize;
        final cellY = y ~/ cellSize;
        final isEven = (cellX + cellY) % 2 == 0;

        final offset = (y * width + x) * 4;
        if (isEven) {
          data[offset] = color1R;
          data[offset + 1] = color1G;
          data[offset + 2] = color1B;
        } else {
          data[offset] = color2R;
          data[offset + 1] = color2G;
          data[offset + 2] = color2B;
        }
        data[offset + 3] = 255;
      }
    }

    return data;
  }
}

// =============================================================================
// Video Probe Result Mock
// =============================================================================

/// Mock video probe result for testing video analysis.
class MockVideoProbeResult {
  final int width;
  final int height;
  final double fps;
  final double duration;
  final bool hasAudio;
  final String codec;

  const MockVideoProbeResult({
    this.width = 1920,
    this.height = 1080,
    this.fps = 30.0,
    this.duration = 10.0,
    this.hasAudio = true,
    this.codec = 'h264',
  });

  /// Generates a ffprobe-like JSON output.
  String toJson() {
    return '''
{
  "streams": [
    {
      "index": 0,
      "codec_type": "video",
      "codec_name": "$codec",
      "width": $width,
      "height": $height,
      "r_frame_rate": "${fps.toStringAsFixed(0)}/1",
      "duration": "${duration.toStringAsFixed(6)}"
    }${hasAudio ? ''',
    {
      "index": 1,
      "codec_type": "audio",
      "codec_name": "aac",
      "sample_rate": "44100",
      "channels": 2
    }''' : ''}
  ],
  "format": {
    "duration": "${duration.toStringAsFixed(6)}",
    "size": "${(duration * 1000000).toInt()}",
    "bit_rate": "1000000"
  }
}
''';
  }
}
