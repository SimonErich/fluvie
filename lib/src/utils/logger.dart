import 'dart:developer' as developer;

/// Log levels for Fluvie logging system.
///
/// Levels are ordered from most verbose to least verbose:
/// - [debug]: Detailed debugging information
/// - [info]: General operational information
/// - [warning]: Warning conditions that should be addressed
/// - [error]: Error conditions that need attention
enum FluvieLogLevel {
  /// Detailed debugging information.
  debug,

  /// General operational information.
  info,

  /// Warning conditions that should be addressed.
  warning,

  /// Error conditions that need attention.
  error,
}

/// A centralized logging system for Fluvie.
///
/// FluvieLogger provides a consistent, configurable logging interface
/// throughout the Fluvie package. Logging is disabled by default and
/// can be enabled via [FluvieConfig.configure].
///
/// ## Usage
///
/// ```dart
/// // Enable logging with configuration
/// FluvieConfig.configure(
///   verbose: true,
///   logLevel: FluvieLogLevel.debug,
/// );
///
/// // Log messages at different levels
/// FluvieLogger.debug('Processing frame 42', module: 'render');
/// FluvieLogger.info('Encoding started', module: 'encoder');
/// FluvieLogger.warning('Low memory', module: 'cache');
/// FluvieLogger.error('FFmpeg failed', module: 'encoder', error: e);
/// ```
///
/// ## Module Tags
///
/// Use module tags to identify the source of log messages:
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
class FluvieLogger {
  FluvieLogger._();

  static FluvieLogLevel _minLevel = FluvieLogLevel.warning;
  static bool _enabled = false;
  static final Set<String> _enabledModules = {};
  static bool _allModulesEnabled = true;

  /// Configures the logger.
  ///
  /// - [enabled]: Whether logging is enabled at all
  /// - [minLevel]: Minimum log level to output
  /// - [modules]: If provided, only these modules will log (null = all modules)
  static void configure({
    bool enabled = false,
    FluvieLogLevel minLevel = FluvieLogLevel.warning,
    Set<String>? modules,
  }) {
    _enabled = enabled;
    _minLevel = minLevel;
    if (modules != null) {
      _enabledModules
        ..clear()
        ..addAll(modules);
      _allModulesEnabled = false;
    } else {
      _enabledModules.clear();
      _allModulesEnabled = true;
    }
  }

  /// Resets the logger to default state (disabled).
  static void reset() {
    _enabled = false;
    _minLevel = FluvieLogLevel.warning;
    _enabledModules.clear();
    _allModulesEnabled = true;
  }

  /// Whether logging is currently enabled.
  static bool get isEnabled => _enabled;

  /// The current minimum log level.
  static FluvieLogLevel get minLevel => _minLevel;

  /// Logs a debug message.
  ///
  /// Debug messages are for detailed debugging information and are
  /// typically only enabled during development.
  static void debug(String message, {String? module}) {
    _log(FluvieLogLevel.debug, message, module: module);
  }

  /// Logs an info message.
  ///
  /// Info messages are for general operational information.
  static void info(String message, {String? module}) {
    _log(FluvieLogLevel.info, message, module: module);
  }

  /// Logs a warning message.
  ///
  /// Warning messages indicate conditions that should be addressed
  /// but don't prevent the operation from completing.
  static void warning(String message, {String? module}) {
    _log(FluvieLogLevel.warning, message, module: module);
  }

  /// Logs an error message.
  ///
  /// Error messages indicate conditions that need attention and
  /// typically represent failures.
  static void error(
    String message, {
    String? module,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      FluvieLogLevel.error,
      message,
      module: module,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs a formatted box with a title and lines of content.
  ///
  /// Useful for displaying structured information like command summaries.
  static void box(
    String title,
    List<String> lines, {
    String? module,
    FluvieLogLevel level = FluvieLogLevel.debug,
  }) {
    if (!_shouldLog(level, module)) return;

    const width = 65;
    final border = '\u2550' * width;
    final divider = '\u2500' * width;

    _output('\u2554$border\u2557', level, module);
    _output('\u2551 ${title.padRight(width - 1)}\u2551', level, module);
    _output('\u255f$divider\u2562', level, module);

    for (final line in lines) {
      // Handle multi-line content
      final wrappedLines = _wrapText(line, width - 2);
      for (final wrappedLine in wrappedLines) {
        _output(
          '\u2551 ${wrappedLine.padRight(width - 1)}\u2551',
          level,
          module,
        );
      }
    }

    _output('\u255a$border\u255d', level, module);
  }

  /// Logs a simple bordered section.
  static void section(
    String title,
    List<String> lines, {
    String? module,
    FluvieLogLevel level = FluvieLogLevel.debug,
  }) {
    if (!_shouldLog(level, module)) return;

    const width = 63;
    final border = '\u2500' * width;

    _output('\u250c$border\u2510', level, module);
    _output('\u2502 ${title.padRight(width - 1)}\u2502', level, module);
    _output('\u251c$border\u2524', level, module);

    for (final line in lines) {
      _output('\u2502 ${line.padRight(width - 1)}\u2502', level, module);
    }

    _output('\u2514$border\u2518', level, module);
  }

  static bool _shouldLog(FluvieLogLevel level, String? module) {
    if (!_enabled) return false;
    if (level.index < _minLevel.index) return false;
    if (!_allModulesEnabled && module != null) {
      if (!_enabledModules.contains(module)) return false;
    }
    return true;
  }

  static void _log(
    FluvieLogLevel level,
    String message, {
    String? module,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_shouldLog(level, module)) return;

    _output(message, level, module);

    if (error != null) {
      _output('  Error: $error', level, module);
    }
    if (stackTrace != null) {
      _output('  Stack trace:\n$stackTrace', level, module);
    }
  }

  static void _output(String message, FluvieLogLevel level, String? module) {
    final prefix = _levelPrefix(level);
    final moduleTag = module != null ? '[$module] ' : '';
    final fullMessage = '$prefix$moduleTag$message';

    // Use developer.log for better integration with Flutter DevTools
    developer.log(fullMessage, name: 'Fluvie', level: _levelToInt(level));
  }

  static String _levelPrefix(FluvieLogLevel level) {
    switch (level) {
      case FluvieLogLevel.debug:
        return '\u{1F41B} '; // bug emoji for debug
      case FluvieLogLevel.info:
        return '\u2139\uFE0F '; // info emoji
      case FluvieLogLevel.warning:
        return '\u26A0\uFE0F '; // warning emoji
      case FluvieLogLevel.error:
        return '\u274C '; // error emoji
    }
  }

  static int _levelToInt(FluvieLogLevel level) {
    switch (level) {
      case FluvieLogLevel.debug:
        return 500;
      case FluvieLogLevel.info:
        return 800;
      case FluvieLogLevel.warning:
        return 900;
      case FluvieLogLevel.error:
        return 1000;
    }
  }

  static List<String> _wrapText(String text, int maxWidth) {
    if (text.length <= maxWidth) return [text];

    final lines = <String>[];
    var remaining = text;

    while (remaining.length > maxWidth) {
      var breakPoint = remaining.lastIndexOf(' ', maxWidth);
      if (breakPoint == -1) breakPoint = maxWidth;

      lines.add(remaining.substring(0, breakPoint));
      remaining = remaining.substring(breakPoint).trimLeft();
    }

    if (remaining.isNotEmpty) {
      lines.add(remaining);
    }

    return lines;
  }
}
