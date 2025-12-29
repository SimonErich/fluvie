import '../utils/logger.dart';

/// Global configuration for Fluvie.
///
/// Use this to configure FFmpeg paths, logging, and other global settings.
///
/// Example:
/// ```dart
/// void main() {
///   // Configure custom FFmpeg path and enable debug logging
///   FluvieConfig.configure(
///     ffmpegPath: '/opt/ffmpeg/bin/ffmpeg',
///     ffprobePath: '/opt/ffmpeg/bin/ffprobe',
///     verbose: true,
///     logLevel: FluvieLogLevel.debug,
///   );
///
///   runApp(MyApp());
/// }
/// ```
class FluvieConfig {
  static FluvieConfig? _instance;

  /// Custom path to the FFmpeg executable.
  ///
  /// If null, uses the system PATH to find FFmpeg.
  final String? ffmpegPath;

  /// Custom path to the FFprobe executable.
  ///
  /// If null, uses the system PATH to find FFprobe.
  final String? ffprobePath;

  /// Whether to enable verbose logging.
  ///
  /// When true, Fluvie will output detailed logs about its operations.
  /// Use [logLevel] to control the verbosity of the output.
  final bool verbose;

  /// The minimum log level to output.
  ///
  /// Only log messages at or above this level will be shown.
  /// Defaults to [FluvieLogLevel.warning].
  final FluvieLogLevel logLevel;

  /// Optional set of modules to enable logging for.
  ///
  /// If null, all modules are logged. If provided, only messages from
  /// the specified modules will be output.
  ///
  /// Available modules:
  /// - `render` - RenderService operations
  /// - `encoder` - Video encoding operations
  /// - `filter` - FFmpeg filter graph building
  /// - `capture` - Frame capture operations
  /// - `embedded` - Embedded video operations
  /// - `video` - Video composition operations
  /// - `resolver` - Path resolution operations
  /// - `cache` - Frame caching operations
  /// - `probe` - Video probing operations
  /// - `preview` - Audio preview operations
  final Set<String>? logModules;

  /// Creates a new FluvieConfig.
  const FluvieConfig._({
    this.ffmpegPath,
    this.ffprobePath,
    this.verbose = false,
    this.logLevel = FluvieLogLevel.warning,
    this.logModules,
  });

  /// Configures Fluvie with custom settings.
  ///
  /// Call this in your `main()` function before using Fluvie.
  ///
  /// ## Basic Usage
  ///
  /// ```dart
  /// void main() {
  ///   FluvieConfig.configure(
  ///     ffmpegPath: '/path/to/ffmpeg',
  ///   );
  ///   runApp(MyApp());
  /// }
  /// ```
  ///
  /// ## With Logging
  ///
  /// ```dart
  /// void main() {
  ///   FluvieConfig.configure(
  ///     verbose: true,
  ///     logLevel: FluvieLogLevel.debug,
  ///     // Only log encoder and render modules
  ///     logModules: {'encoder', 'render'},
  ///   );
  ///   runApp(MyApp());
  /// }
  /// ```
  static void configure({
    String? ffmpegPath,
    String? ffprobePath,
    bool verbose = false,
    FluvieLogLevel logLevel = FluvieLogLevel.warning,
    Set<String>? logModules,
  }) {
    _instance = FluvieConfig._(
      ffmpegPath: ffmpegPath,
      ffprobePath: ffprobePath,
      verbose: verbose,
      logLevel: logLevel,
      logModules: logModules,
    );

    // Configure the logger based on settings
    FluvieLogger.configure(
      enabled: verbose,
      minLevel: logLevel,
      modules: logModules,
    );
  }

  /// Gets the current configuration.
  ///
  /// Returns a default configuration if [configure] hasn't been called.
  static FluvieConfig get current => _instance ?? const FluvieConfig._();

  /// Resets the configuration to defaults.
  static void reset() {
    _instance = null;
    FluvieLogger.reset();
  }

  /// Whether a custom FFmpeg path is configured.
  bool get hasCustomFFmpegPath => ffmpegPath != null;

  /// Whether a custom FFprobe path is configured.
  bool get hasCustomFFprobePath => ffprobePath != null;
}
