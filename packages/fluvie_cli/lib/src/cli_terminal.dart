import 'dart:convert';

import 'package:fluvie_cli/src/cli_failure.dart';

/// Final machine-readable status for failed commands, including failures
/// handled inside individual command boundaries. Human diagnostics still reach
/// stderr; stdout stays parseable JSON lines.
final class CliTerminal {
  /// Creates a terminal recorder for one command.
  CliTerminal({
    required this.out,
    required StringSink err,
    required this.machine,
    required this.stage,
  }) : _err = _RecordingSink(err);

  final StringSink out;
  final _RecordingSink _err;
  StringSink get err => _err;
  final bool machine;
  final String stage;

  /// Returns [code] after emitting one terminal error for machine consumers.
  int finish(int code, {CliFailure? failure}) {
    if (machine && code != 0) {
      final message = (failure?.message ?? _err.recorded.toString()).trim();
      final firstLine = message.isEmpty ? 'The $stage command failed.' : message.split('\n').first;
      final summary = firstLine.length > 1024 ? '${firstLine.substring(0, 1024)}…' : firstLine;
      out.writeln(
        jsonEncode({
          'schemaVersion': 1,
          'event': 'error',
          'terminal': true,
          'code': failure?.code ?? (code == 64 ? 'usage_error' : 'command_failed'),
          'stage': stage,
          'exitCode': code,
          'message': summary,
          if (failure?.details.isNotEmpty ?? false)
            'details': failure!.details
          else if (message.length > 4096)
            'details': '${message.substring(0, 4096)}\n[truncated]'
          else if (message.contains('\n'))
            'details': message,
          'remedy': code == 64
              ? 'Run fluvie $stage --help.'
              : 'Read the command diagnostics and retry after correcting the reported input or dependency.',
        }),
      );
    }
    return code;
  }
}

final class _RecordingSink implements StringSink {
  _RecordingSink(this.delegate);
  final StringSink delegate;
  final StringBuffer recorded = StringBuffer();
  @override
  void write(Object? object) {
    delegate.write(object);
    final text = '$object';
    final remaining = 8192 - recorded.length;
    if (remaining > 0) {
      recorded.write(text.length <= remaining ? text : text.substring(0, remaining));
    }
  }

  @override
  void writeln([Object? object = '']) => write('$object\n');
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));
}
