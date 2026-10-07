import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:path/path.dart' as p;

/// A live Flutter daemon session: URL readiness and rebuilds are machine events.
final class PreviewSession {
  /// Binds one owned Flutter process and its original source project.
  PreviewSession({
    required this.process,
    required this.projectDir,
    required this.device,
    required this.out,
    required this.err,
    required this.json,
    required this.onReload,
  });
  final Process process;
  final String projectDir;
  final String device;
  final StringSink out;
  final StringSink err;
  final bool json;
  final void Function() onReload;
  final _requests = <int, Completer<Map<String, Object?>>>{};
  int _requestId = 0;
  String? _appId;
  bool _ready = false;
  bool _closing = false;
  bool _reloading = false;
  bool _dirty = false;
  String _fingerprint = '';

  /// Forwards diagnostic streams, watches authoring inputs, and owns shutdown.
  Future<int> run() async {
    _fingerprint = sourceFingerprint(projectDir);
    final stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_line);
    final stderrSubscription = process.stderr.transform(utf8.decoder).listen(err.write);
    final timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = sourceFingerprint(projectDir);
      if (next == _fingerprint) return;
      _fingerprint = next;
      _dirty = true;
      unawaited(_reload());
    });
    StreamSubscription<String>? input;
    if (stdin.hasTerminal) {
      input = stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (line.trim() == 'q') {
          process.kill();
        } else if (line.trim() == 'r') {
          _dirty = true;
          unawaited(_reload());
        }
      });
    }
    final signals = <StreamSubscription<ProcessSignal>>[];
    if (!Platform.isWindows) {
      for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
        signals.add(signal.watch().listen((_) => process.kill(signal)));
      }
    }
    try {
      return await process.exitCode;
    } finally {
      _closing = true;
      timer.cancel();
      await input?.cancel();
      for (final signal in signals) {
        await signal.cancel();
      }
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      for (final request in _requests.values) {
        if (!request.isCompleted) {
          request.completeError(const CliFailure('The Flutter preview process stopped.'));
        }
      }
    }
  }

  void _line(String line) {
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      err.writeln(line);
      return;
    }
    if (decoded is! List) {
      err.writeln(line);
      return;
    }
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'];
      if (id is int && _requests.containsKey(id)) {
        _requests.remove(id)!.complete(item.cast<String, Object?>());
        continue;
      }
      final event = item['event'];
      final params = item['params'];
      if (params is! Map<String, dynamic>) continue;
      if (event == 'app.start') _appId = params['appId'] as String?;
      if (event == 'app.webLaunchUrl' && params['url'] is String) {
        _emitReady(params['url'] as String);
      } else if (event == 'app.started' && device != 'chrome' && device != 'web-server') {
        _emitReady(null);
      } else if (event == 'app.log' && params['log'] is String) {
        err.writeln(params['log']);
      }
    }
  }

  void _emitReady(String? url) {
    if (_ready) return;
    _ready = true;
    if (json) {
      out.writeln(
        jsonEncode({
          'schemaVersion': 1,
          'event': 'ready',
          'device': device,
          'url': ?url,
          'projectDir': p.absolute(projectDir),
        }),
      );
    } else {
      out.writeln(url == null ? 'Preview ready on $device.' : 'Preview ready: $url');
      out.writeln('Changes reload automatically. Enter r to rebuild or q to quit.');
    }
    if (_dirty) unawaited(_reload());
  }

  Future<void> _reload() async {
    if (_closing || _reloading || !_ready || _appId == null) return;
    _reloading = true;
    var rebuilt = false;
    var lastSucceeded = false;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      while (_dirty && !_closing) {
        _dirty = false;
        final id = ++_requestId;
        final request = Completer<Map<String, Object?>>();
        _requests[id] = request;
        process.stdin.writeln(
          jsonEncode([
            {
              'id': id,
              'method': 'app.restart',
              'params': {
                'appId': _appId,
                'fullRestart': device == 'web-server' || device == 'chrome',
                'pause': false,
                'reason': 'Fluvie authoring change',
              },
            },
          ]),
        );
        try {
          final response = await request.future.timeout(const Duration(minutes: 2));
          final result = response['result'];
          if (response['error'] != null || result is Map && result['code'] != 0) {
            lastSucceeded = false;
            err.writeln('Preview rebuild failed: ${response['error'] ?? result}');
          } else {
            rebuilt = true;
            lastSucceeded = true;
          }
        } finally {
          _requests.remove(id);
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
        final latest = sourceFingerprint(projectDir);
        if (latest != _fingerprint) {
          _fingerprint = latest;
          _dirty = true;
        }
      }
      if (rebuilt && lastSucceeded && !_closing) {
        onReload();
        if (json) out.writeln(jsonEncode({'schemaVersion': 1, 'event': 'reloaded'}));
      }
    } on Object catch (error) {
      if (!_closing) err.writeln('Could not rebuild the preview: $error');
    } finally {
      _reloading = false;
    }
  }
}

/// Stable authoring-input metadata; generated build/cache trees are skipped.
String sourceFingerprint(String projectDir) {
  final records = <String>[];
  void walk(Directory dir) {
    try {
      for (final entity in dir.listSync(followLinks: false)) {
        final name = p.basename(entity.path);
        if (entity is Directory) {
          if (!{
            'build',
            '.dart_tool',
            '.git',
            '.fluvie',
            'node_modules',
            '.codegraph',
          }.contains(name)) {
            walk(entity);
          }
        } else if (entity is File) {
          final relative = p.relative(entity.path, from: projectDir);
          final stat = entity.statSync();
          records.add('$relative:${stat.size}:${stat.modified.microsecondsSinceEpoch}');
        }
      }
    } on FileSystemException {
      /* A concurrent save may rename a directory. */
    }
  }

  walk(Directory(projectDir));
  records.sort();
  return records.join('\n');
}
