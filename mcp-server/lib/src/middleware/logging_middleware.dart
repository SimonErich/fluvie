import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

final _logger = Logger('FluvieMCP');

/// Creates logging middleware for request/response logging
Middleware loggingMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final stopwatch = Stopwatch()..start();

      _logger.info('${request.method} ${request.requestedUri.path}');

      try {
        final response = await innerHandler(request);
        stopwatch.stop();

        _logger.info(
          '${request.method} ${request.requestedUri.path} '
          '${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)',
        );

        return response;
      } catch (e, stack) {
        stopwatch.stop();
        _logger.severe(
          '${request.method} ${request.requestedUri.path} ERROR: $e',
          e,
          stack,
        );
        rethrow;
      }
    };
  };
}

/// Configure the logger
void configureLogging(String level) {
  Logger.root.level = _parseLogLevel(level);
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print(
      '${record.time} [${record.level.name}] ${record.loggerName}: ${record.message}',
    );
    if (record.error != null) {
      // ignore: avoid_print
      print('  Error: ${record.error}');
    }
  });
}

Level _parseLogLevel(String level) {
  switch (level.toLowerCase()) {
    case 'all':
      return Level.ALL;
    case 'fine':
    case 'debug':
      return Level.FINE;
    case 'info':
      return Level.INFO;
    case 'warning':
    case 'warn':
      return Level.WARNING;
    case 'severe':
    case 'error':
      return Level.SEVERE;
    case 'off':
      return Level.OFF;
    default:
      return Level.INFO;
  }
}
