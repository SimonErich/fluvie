/// Custom exception types for Fluvie.
///
/// This module provides a hierarchy of exceptions for different error scenarios
/// in video composition, rendering, and encoding.
library;

/// Base exception for all Fluvie-specific errors.
///
/// All custom exceptions in Fluvie extend this base class, making it easy to
/// catch all Fluvie errors with a single catch block if needed.
///
/// Example:
/// ```dart
/// try {
///   await renderService.execute(...);
/// } on FluvieException catch (e) {
///   // Handle any Fluvie error
///   print('Fluvie error: ${e.message}');
///   if (e.cause != null) {
///     print('Caused by: ${e.cause}');
///   }
/// }
/// ```
class FluvieException implements Exception {
  /// Human-readable error message.
  final String message;

  /// Optional underlying cause of this exception.
  final dynamic cause;

  /// Optional stack trace from the original error.
  final StackTrace? stackTrace;

  /// Creates a Fluvie exception with an error message.
  ///
  /// - [message]: Description of what went wrong
  /// - [cause]: Optional underlying exception that triggered this error
  /// - [stackTrace]: Optional stack trace from the original error
  const FluvieException(this.message, [this.cause, this.stackTrace]);

  @override
  String toString() {
    final buffer = StringBuffer('FluvieException: $message');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    if (stackTrace != null) {
      buffer.write('\nStack trace:\n$stackTrace');
    }
    return buffer.toString();
  }
}

// =============================================================================
// FFmpeg-Related Exceptions
// =============================================================================

/// Thrown when FFmpeg executable is not found on the system.
///
/// This typically occurs when:
/// - FFmpeg is not installed
/// - FFmpeg is not in the system PATH
/// - The FFmpegProvider cannot locate the binary
///
/// Example:
/// ```dart
/// try {
///   await FFmpegChecker.ensureAvailable();
/// } on FFmpegNotFoundException catch (e) {
///   showDialog(
///     content: Text('Please install FFmpeg: ${e.message}'),
///   );
/// }
/// ```
class FFmpegNotFoundException extends FluvieException {
  /// Creates an exception for when FFmpeg cannot be found.
  ///
  /// - [message]: Details about where FFmpeg was searched for
  /// - [cause]: Optional underlying error
  FFmpegNotFoundException(String message, [dynamic cause, StackTrace? stackTrace])
      : super(message, cause, stackTrace);

  @override
  String toString() => 'FFmpegNotFoundException: $message';
}

/// Thrown when FFmpeg execution fails during video encoding.
///
/// This can happen due to:
/// - Invalid FFmpeg command arguments
/// - Corrupted input files
/// - Unsupported codecs
/// - Insufficient disk space
/// - FFmpeg process crashes
///
/// The exception includes the exit code and stderr output for debugging.
///
/// Example:
/// ```dart
/// try {
///   await videoEncoder.encode(...);
/// } on FFmpegExecutionException catch (e) {
///   print('FFmpeg failed with exit code ${e.exitCode}');
///   print('Error output: ${e.stderr}');
/// }
/// ```
class FFmpegExecutionException extends FluvieException {
  /// The FFmpeg process exit code (if available).
  final int? exitCode;

  /// The stderr output from FFmpeg (if available).
  final String? stderr;

  /// The FFmpeg command that was executed.
  final String? command;

  /// Creates an exception for FFmpeg execution failures.
  ///
  /// - [message]: High-level description of the failure
  /// - [exitCode]: FFmpeg exit code
  /// - [stderr]: FFmpeg stderr output
  /// - [command]: The FFmpeg command that failed
  /// - [cause]: Optional underlying error
  FFmpegExecutionException(
    String message, {
    this.exitCode,
    this.stderr,
    this.command,
    dynamic cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);

  @override
  String toString() {
    final buffer = StringBuffer('FFmpegExecutionException: $message');
    if (exitCode != null) {
      buffer.write('\nExit code: $exitCode');
    }
    if (command != null) {
      buffer.write('\nCommand: $command');
    }
    if (stderr != null) {
      buffer.write('\nStderr:\n$stderr');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

// =============================================================================
// Rendering Exceptions
// =============================================================================

/// Thrown when video rendering fails.
///
/// This is a general exception for rendering pipeline failures that occur
/// during the render process, such as:
/// - Widget build failures
/// - Frame capture errors
/// - Timeline configuration issues
/// - Resource exhaustion
///
/// Example:
/// ```dart
/// try {
///   await renderService.execute(config: config, ...);
/// } on RenderException catch (e) {
///   if (e.frameNumber != null) {
///     print('Failed at frame ${e.frameNumber}');
///   }
///   // Log error and notify user
/// }
/// ```
class RenderException extends FluvieException {
  /// The frame number where rendering failed (if known).
  final int? frameNumber;

  /// Creates an exception for rendering failures.
  ///
  /// - [message]: Description of the rendering failure
  /// - [frameNumber]: Optional frame number where the error occurred
  /// - [cause]: Optional underlying error
  RenderException(
    String message, {
    this.frameNumber,
    dynamic cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);

  @override
  String toString() {
    final buffer = StringBuffer('RenderException: $message');
    if (frameNumber != null) {
      buffer.write(' (at frame $frameNumber)');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Thrown when frame capture fails during rendering.
///
/// This occurs when the FrameSequencer cannot capture a widget as an image,
/// typically due to:
/// - Widget rendering errors
/// - RepaintBoundary issues
/// - Memory exhaustion during image capture
/// - Platform-specific rendering bugs
///
/// Example:
/// ```dart
/// try {
///   final image = await frameSequencer.captureFrame(key, 42);
/// } on FrameCaptureException catch (e) {
///   print('Could not capture frame: ${e.message}');
///   // Fall back to error frame or retry
/// }
/// ```
class FrameCaptureException extends FluvieException {
  /// The frame number that failed to capture.
  final int? frameNumber;

  /// The GlobalKey of the RepaintBoundary that failed.
  final String? boundaryKey;

  /// Creates an exception for frame capture failures.
  ///
  /// - [message]: Description of the capture failure
  /// - [frameNumber]: Optional frame number
  /// - [boundaryKey]: Optional RepaintBoundary key identifier
  /// - [cause]: Optional underlying error
  FrameCaptureException(
    String message, {
    this.frameNumber,
    this.boundaryKey,
    dynamic cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);

  @override
  String toString() {
    final buffer = StringBuffer('FrameCaptureException: $message');
    if (frameNumber != null) {
      buffer.write(' (frame $frameNumber)');
    }
    if (boundaryKey != null) {
      buffer.write(' [boundary: $boundaryKey]');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

// =============================================================================
// Configuration Exceptions
// =============================================================================

/// Thrown when a Fluvie configuration is invalid.
///
/// This occurs when:
/// - Required configuration parameters are missing
/// - Configuration values are out of valid ranges
/// - Conflicting configuration options are specified
/// - Invalid timeline or composition parameters
///
/// Example:
/// ```dart
/// try {
///   final config = RenderConfig(
///     width: -100,  // Invalid
///     height: 1080,
///     fps: 30,
///   );
/// } on InvalidConfigurationException catch (e) {
///   print('Invalid configuration: ${e.message}');
///   // Show validation error to user
/// }
/// ```
class InvalidConfigurationException extends FluvieException {
  /// The configuration field that is invalid (if applicable).
  final String? fieldName;

  /// The invalid value that was provided.
  final dynamic invalidValue;

  /// Creates an exception for invalid configurations.
  ///
  /// - [message]: Description of why the configuration is invalid
  /// - [fieldName]: Optional name of the invalid field
  /// - [invalidValue]: Optional value that was rejected
  /// - [cause]: Optional underlying error
  InvalidConfigurationException(
    String message, {
    this.fieldName,
    this.invalidValue,
    dynamic cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);

  @override
  String toString() {
    final buffer = StringBuffer('InvalidConfigurationException: $message');
    if (fieldName != null) {
      buffer.write(' (field: $fieldName)');
    }
    if (invalidValue != null) {
      buffer.write(' (value: $invalidValue)');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

// =============================================================================
// Audio Exceptions
// =============================================================================

/// Thrown when audio processing fails.
///
/// This can occur during:
/// - Audio file loading
/// - BPM detection
/// - Audio format conversion
/// - Audio track mixing
/// - Sync anchor calculations
///
/// Example:
/// ```dart
/// try {
///   final bpm = await audioProbeSer.detectBpm('song.mp3');
/// } on AudioProcessingException catch (e) {
///   print('Could not process audio: ${e.message}');
///   // Fall back to manual BPM or disable audio sync
/// }
/// ```
class AudioProcessingException extends FluvieException {
  /// The audio file path that failed to process (if applicable).
  final String? audioFilePath;

  /// The type of audio operation that failed.
  final String? operation;

  /// Creates an exception for audio processing failures.
  ///
  /// - [message]: Description of the audio processing failure
  /// - [audioFilePath]: Optional path to the audio file
  /// - [operation]: Optional description of the operation (e.g., 'BPM detection')
  /// - [cause]: Optional underlying error
  AudioProcessingException(
    String message, {
    this.audioFilePath,
    this.operation,
    dynamic cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);

  @override
  String toString() {
    final buffer = StringBuffer('AudioProcessingException: $message');
    if (operation != null) {
      buffer.write(' (operation: $operation)');
    }
    if (audioFilePath != null) {
      buffer.write('\nAudio file: $audioFilePath');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

// =============================================================================
// File I/O Exceptions
// =============================================================================

/// Thrown when a required file is not found.
///
/// This occurs when:
/// - Video source files don't exist
/// - Audio files are missing
/// - Asset files cannot be located
/// - Output directory is inaccessible
///
/// Example:
/// ```dart
/// try {
///   final video = VideoSequence(
///     source: VideoSource.file('/path/to/missing.mp4'),
///     ...
///   );
/// } on FileNotFoundException catch (e) {
///   print('File not found: ${e.filePath}');
///   // Prompt user to select a valid file
/// }
/// ```
class FileNotFoundException extends FluvieException {
  /// The path of the file that was not found.
  final String filePath;

  /// Creates an exception for missing files.
  ///
  /// - [filePath]: The path that was searched for
  /// - [cause]: Optional underlying error
  FileNotFoundException(
    this.filePath, [
    dynamic cause,
    StackTrace? stackTrace,
  ]) : super('File not found: $filePath', cause, stackTrace);

  @override
  String toString() {
    final buffer = StringBuffer('FileNotFoundException: $filePath');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Thrown when file I/O operations fail.
///
/// This can occur during:
/// - Reading video or audio files
/// - Writing output files
/// - Creating temporary directories
/// - Cleaning up temporary files
///
/// Example:
/// ```dart
/// try {
///   await File(outputPath).writeAsBytes(videoData);
/// } on FileIOException catch (e) {
///   print('Failed to write file: ${e.message}');
///   // Check disk space, permissions, etc.
/// }
/// ```
class FileIOException extends FluvieException {
  /// The file path involved in the I/O operation.
  final String? filePath;

  /// The type of I/O operation that failed.
  final String? operation;

  /// Creates an exception for file I/O failures.
  ///
  /// - [message]: Description of the I/O failure
  /// - [filePath]: Optional path to the file
  /// - [operation]: Optional operation type (e.g., 'read', 'write', 'delete')
  /// - [cause]: Optional underlying error
  FileIOException(
    String message, {
    this.filePath,
    this.operation,
    dynamic cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);

  @override
  String toString() {
    final buffer = StringBuffer('FileIOException: $message');
    if (operation != null) {
      buffer.write(' (operation: $operation)');
    }
    if (filePath != null) {
      buffer.write('\nFile: $filePath');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

// =============================================================================
// Video Analysis Exceptions
// =============================================================================

/// Thrown when video probing or analysis fails.
///
/// This occurs when FFprobe or other analysis tools cannot:
/// - Read video metadata
/// - Extract frame information
/// - Determine codec details
/// - Analyze video properties
///
/// Example:
/// ```dart
/// try {
///   final info = await videoProbeService.probe('video.mp4');
/// } on VideoProbeException catch (e) {
///   print('Could not analyze video: ${e.message}');
///   // Fall back to default settings or reject file
/// }
/// ```
class VideoProbeException extends FluvieException {
  /// The video file that failed to probe.
  final String? videoFilePath;

  /// Additional details about the error (backward compatibility).
  final String? details;

  /// Creates an exception for video probing failures.
  ///
  /// - [message]: Description of the probe failure
  /// - [videoFilePath]: Optional path to the video file
  /// - [details]: Optional additional details (backward compatibility)
  /// - [cause]: Optional underlying error
  VideoProbeException(
    String message, {
    this.videoFilePath,
    this.details,
    dynamic cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);

  @override
  String toString() {
    final buffer = StringBuffer('VideoProbeException: $message');
    if (details != null) {
      buffer.write('\nDetails: $details');
    }
    if (videoFilePath != null) {
      buffer.write('\nVideo file: $videoFilePath');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

// =============================================================================
// Timeline Exceptions
// =============================================================================

/// Thrown when timeline or sequence configuration is invalid.
///
/// This occurs when:
/// - Start/end frames are out of bounds
/// - Sequences overlap incorrectly
/// - Transitions have invalid durations
/// - Frame ranges are invalid
///
/// Example:
/// ```dart
/// try {
///   final sequence = Sequence(
///     startFrame: 100,
///     endFrame: 50,  // Invalid: end before start
///     child: MyWidget(),
///   );
/// } on TimelineException catch (e) {
///   print('Invalid timeline: ${e.message}');
/// }
/// ```
class TimelineException extends FluvieException {
  /// The start frame involved in the error (if applicable).
  final int? startFrame;

  /// The end frame involved in the error (if applicable).
  final int? endFrame;

  /// Creates an exception for timeline configuration errors.
  ///
  /// - [message]: Description of the timeline issue
  /// - [startFrame]: Optional start frame value
  /// - [endFrame]: Optional end frame value
  /// - [cause]: Optional underlying error
  TimelineException(
    String message, {
    this.startFrame,
    this.endFrame,
    dynamic cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);

  @override
  String toString() {
    final buffer = StringBuffer('TimelineException: $message');
    if (startFrame != null || endFrame != null) {
      buffer.write(' (frames: $startFrame-$endFrame)');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

// =============================================================================
// Platform Exceptions
// =============================================================================

/// Thrown when a platform-specific feature is unavailable.
///
/// This occurs when:
/// - A feature is not supported on the current platform (web, mobile, desktop)
/// - Required platform dependencies are missing
/// - Platform-specific capabilities are disabled
///
/// Example:
/// ```dart
/// try {
///   await renderService.execute(...);
/// } on UnsupportedPlatformException catch (e) {
///   showDialog(
///     content: Text('This feature requires ${e.requiredPlatform}'),
///   );
/// }
/// ```
class UnsupportedPlatformException extends FluvieException {
  /// The platform that is required for this feature.
  final String? requiredPlatform;

  /// The current platform where the error occurred.
  final String? currentPlatform;

  /// Creates an exception for unsupported platform errors.
  ///
  /// - [message]: Description of the platform limitation
  /// - [requiredPlatform]: Optional platform requirement
  /// - [currentPlatform]: Optional current platform identifier
  /// - [cause]: Optional underlying error
  UnsupportedPlatformException(
    String message, {
    this.requiredPlatform,
    this.currentPlatform,
    dynamic cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);

  @override
  String toString() {
    final buffer = StringBuffer('UnsupportedPlatformException: $message');
    if (requiredPlatform != null) {
      buffer.write('\nRequired platform: $requiredPlatform');
    }
    if (currentPlatform != null) {
      buffer.write('\nCurrent platform: $currentPlatform');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}
