import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/review_quality.dart';
import 'package:http/http.dart' as http;

/// Inspects or renders through an already running authoring workspace.
final class SessionCommand {
  /// Creates an HTTP tool that never starts another Flutter process.
  const SessionCommand();

  /// Assistant-facing requests use the same frame/review/export paths as the UI.
  static ArgParser buildParser() => ArgParser()
    ..addFlag('strict-quality', negatable: false)
    ..addMultiOption('allow-quality', allowed: reviewQualityCodes.toList())
    ..addOption('frame', defaultsTo: '0')
    ..addOption('frames', help: 'Draft prefix frame count.')
    ..addOption('aspect')
    ..addOption('format', defaultsTo: 'mp4')
    ..addOption('timeout', defaultsTo: '900', help: 'Whole HTTP request timeout in seconds.')
    ..addOption('revision', help: 'Require this source revision; reject stale requests.');

  /// Executes a request using a private local descriptor. Emits structured JSON.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    if (args.rest.length != 2 ||
        !{'status', 'source', 'frame', 'review', 'render', 'inspect'}.contains(args.rest.last)) {
      err.writeln('Use fluvie session <session.json> <status|source|frame|review|render|inspect>.');
      return 64;
    }
    final timeoutSeconds = int.tryParse(args.option('timeout')!);
    if (timeoutSeconds == null || timeoutSeconds < 1) {
      throw const CliFailure('Use positive whole seconds for --timeout.');
    }
    final file = File(args.rest.first);
    if (await file.length() > 65536) throw const CliFailure('Session descriptor exceeds 64 KiB.');
    final descriptor = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    final endpoint = Uri.tryParse('${descriptor['endpoint']}');
    final token = descriptor['token'];
    if (descriptor['schemaVersion'] != 1 ||
        endpoint == null ||
        endpoint.scheme != 'http' ||
        !{'127.0.0.1', 'localhost'}.contains(endpoint.host) ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.path.isNotEmpty ||
        endpoint.query.isNotEmpty ||
        endpoint.fragment.isNotEmpty ||
        token is! String ||
        token.length < 32 ||
        token.length > 128) {
      throw const CliFailure('Expected a local Fluvie workspace descriptor.');
    }
    final operation = args.rest.last;
    final isRead = operation == 'status' || operation == 'source';
    final client = http.Client();
    try {
      final request =
          http.Request(isRead ? 'GET' : 'POST', endpoint.resolve(isRead ? '/$operation' : '/jobs'))
            ..followRedirects = false
            ..headers.addAll({'X-Fluvie-Token': token, 'Content-Type': 'application/json'});
      if (!isRead) {
        final frame = int.tryParse(args.option('frame')!);
        final frames = args.option('frames') == null ? null : int.tryParse(args.option('frames')!);
        if (frame == null ||
            frame < 0 ||
            (args.option('frames') != null && (frames == null || frames < 1))) {
          err.writeln('Use non-negative --frame and positive --frames indexes.');
          return 64;
        }
        request.body = jsonEncode({
          'operation': operation,
          'strictQuality': args.flag('strict-quality'),
          'allowQuality': args.multiOption('allow-quality'),
          if (operation == 'frame') 'frameIndex': frame,
          if (operation == 'review') 'reviewDeterminism': true,
          if (operation == 'render') 'format': args.option('format'),
          'frameCount': ?frames,
          if (args.option('aspect') != null) 'aspect': args.option('aspect'),
          if (args.option('revision') != null) 'sourceRevision': args.option('revision'),
        });
      }
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(Duration(seconds: timeoutSeconds));
      out.writeln(response.body);
      return response.statusCode == 200 &&
              (jsonDecode(response.body) as Map<String, Object?>)['ok'] != false
          ? 0
          : 1;
    } finally {
      client.close();
    }
  }
}
