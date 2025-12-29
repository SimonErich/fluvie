import 'dart:typed_data';

/// Configuration for starting an FFmpeg encoding session.
class FFmpegSessionConfig {
  /// Output video width in pixels.
  final int width;

  /// Output video height in pixels.
  final int height;

  /// Frames per second.
  final int fps;

  /// Total number of frames to encode.
  final int totalFrames;

  /// Output file name (or identifier for web).
  final String outputFileName;

  /// Video codec to use (e.g., 'libx264').
  final String videoCodec;

  /// Encoding preset (e.g., 'medium', 'fast').
  final String preset;

  /// Pixel format (e.g., 'yuv420p').
  final String pixelFormat;

  /// Constant Rate Factor (0-51, lower is better quality).
  final int crf;

  /// Audio input files to mix into the video.
  final List<AudioInput> audioInputs;

  /// FFmpeg filter graph string.
  final String? filterGraph;

  /// Label for video output in filter graph.
  final String? videoOutputLabel;

  /// Label for audio output in filter graph.
  final String? audioOutputLabel;

  const FFmpegSessionConfig({
    required this.width,
    required this.height,
    required this.fps,
    required this.totalFrames,
    required this.outputFileName,
    this.videoCodec = 'libx264',
    this.preset = 'medium',
    this.pixelFormat = 'yuv420p',
    this.crf = 23,
    this.audioInputs = const [],
    this.filterGraph,
    this.videoOutputLabel,
    this.audioOutputLabel,
  });
}

/// Represents an audio input file for mixing.
class AudioInput {
  /// Path or URI to the audio file.
  final String uri;

  /// Type of audio source.
  final AudioInputType type;

  const AudioInput({required this.uri, required this.type});
}

/// Types of audio input sources.
enum AudioInputType {
  /// Local file path.
  file,

  /// Flutter asset path.
  asset,

  /// Remote URL.
  url,
}

/// Represents an active FFmpeg encoding session.
///
/// The session is used to feed frames to FFmpeg and monitor progress.
abstract class FFmpegSession {
  /// Stream of encoding progress (0.0 to 1.0).
  Stream<double> get progress;

  /// Future that completes with the output file path/URL when encoding is done.
  ///
  /// Throws an exception if encoding fails.
  Future<String> get completed;

  /// Adds a raw RGBA frame to the encoding pipeline.
  ///
  /// The [rgbaBytes] should be in RGBA format with dimensions matching
  /// the session's configured width and height.
  Future<void> addFrame(Uint8List rgbaBytes);

  /// Signals that all frames have been added and encoding should finalize.
  Future<void> finalize();

  /// Cancels the encoding session.
  Future<void> cancel();
}

/// Abstract interface for FFmpeg providers.
///
/// Implement this interface to add support for different FFmpeg backends
/// (e.g., native process, WASM, FFmpeg Kit for mobile).
///
/// Example custom provider:
/// ```dart
/// class FFmpegKitProvider implements FFmpegProvider {
///   @override
///   String get name => 'FFmpegKit';
///
///   @override
///   Future<bool> isAvailable() async {
///     // Check if FFmpegKit is available
///     return true;
///   }
///
///   @override
///   Future<FFmpegSession> startSession(FFmpegSessionConfig config) async {
///     // Create FFmpegKit-based session
///     return FFmpegKitSession(config);
///   }
///
///   @override
///   Future<void> dispose() async {
///     // Clean up resources
///   }
/// }
/// ```
abstract class FFmpegProvider {
  /// Human-readable name of this provider.
  String get name;

  /// Checks if this FFmpeg provider is available on the current platform.
  ///
  /// Returns `true` if FFmpeg can be used, `false` otherwise.
  Future<bool> isAvailable();

  /// Starts a new encoding session with the given configuration.
  ///
  /// Throws [FFmpegNotAvailableException] if FFmpeg is not available.
  Future<FFmpegSession> startSession(FFmpegSessionConfig config);

  /// Releases any resources held by this provider.
  Future<void> dispose();
}

/// Exception thrown when FFmpeg is not available.
class FFmpegNotAvailableException implements Exception {
  /// Detailed message explaining why FFmpeg is not available.
  final String message;

  /// Optional installation instructions.
  final String? installationInstructions;

  const FFmpegNotAvailableException(
    this.message, {
    this.installationInstructions,
  });

  @override
  String toString() {
    final buffer = StringBuffer('FFmpegNotAvailableException: $message');
    if (installationInstructions != null) {
      buffer.write('\n\n$installationInstructions');
    }
    return buffer.toString();
  }
}

/// Exception thrown when FFmpeg encoding fails.
class FFmpegEncodingException implements Exception {
  /// Error message from FFmpeg.
  final String message;

  /// FFmpeg's exit code, if available.
  final int? exitCode;

  /// stderr output from FFmpeg, if available.
  final String? stderrOutput;

  const FFmpegEncodingException(
    this.message, {
    this.exitCode,
    this.stderrOutput,
  });

  @override
  String toString() {
    final buffer = StringBuffer('FFmpegEncodingException: $message');
    if (exitCode != null) {
      buffer.write(' (exit code: $exitCode)');
    }
    if (stderrOutput != null && stderrOutput!.isNotEmpty) {
      buffer.write('\n\nFFmpeg output:\n$stderrOutput');
    }
    return buffer.toString();
  }
}
