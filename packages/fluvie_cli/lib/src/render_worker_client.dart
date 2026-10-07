import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/authored_artifacts.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/stage_harness.dart';

/// Serial, bounded transport to one package-owned Flutter worker.
final class RenderWorkerClient {
  /// Binds an exclusively owned directory and an optional process-exit signal.
  RenderWorkerClient({
    required this.mailbox,
    this.processExit,
    this.timeout = const Duration(minutes: 5),
  }) {
    if (timeout <= Duration.zero) throw ArgumentError('Worker timeout must be positive.');
    if (processExit != null) unawaited(processExit!.then((code) => _exitCode = code));
  }

  /// Private directory shared only with this worker process.
  final Directory mailbox;

  /// Completion means the engine exited and no further response can arrive.
  final Future<int>? processExit;

  /// Maximum wait per request, after which the transport is retired.
  final Duration timeout;
  bool _busy = false;
  bool _retired = false;
  int? _exitCode;

  /// Whether a timeout, process exit or malformed response requires a new worker.
  bool get retired => _retired;

  /// Publishes one invocation and verifies its response id before returning.
  /// A render failure can be retried. A transport failure requires a new worker.
  Future<Map<String, Object?>> execute(Map<String, Object?> invocation) async {
    if (_retired) throw const CliFailure('The render worker transport is retired.');
    if (_busy) throw const CliFailure('The render worker accepts one request at a time.');
    _busy = true;
    final id = uniqueStageId();
    final response = File('${mailbox.path}/response.json');
    try {
      if (response.existsSync()) await response.delete();
      await atomicWrite(
        '${mailbox.path}/request.json',
        jsonEncode({
          'id': id,
          'invocation': invocation,
        }),
      );
      Future<Map<String, Object?>> read() async {
        while (!response.existsSync()) {
          if (_exitCode != null || _retired) {
            throw CliFailure('The Flutter render worker stopped (exit $_exitCode).');
          }
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        if (await response.length() > 65536) {
          throw const CliFailure('The worker response exceeds 64 KiB.');
        }
        final value = jsonDecode(await response.readAsString());
        if (value is! Map<String, Object?> || value['schemaVersion'] != 1 || value['id'] != id) {
          throw const CliFailure('Render worker response identity or schema does not match.');
        }
        return value;
      }

      final value = await read().timeout(timeout);
      if (value['ok'] != true) throw _RequestFailure('${value['error']}');
      return value;
    } on _RequestFailure catch (failure) {
      throw CliFailure(failure.message);
    } on Object {
      _retired = true;
      rethrow;
    } finally {
      _busy = false;
    }
  }

  /// Retires the transport and asks an idle worker to leave its test normally.
  Future<void> stop() async {
    _retired = true;
    if (!_busy) await atomicWrite('${mailbox.path}/request.json', '{"stop":true}');
  }
}

final class _RequestFailure implements Exception {
  const _RequestFailure(this.message);
  final String message;
}
