import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/templates/workspace_page.dart';
import 'package:fluvie_cli/src/workspace_session.dart';
import 'package:path/path.dart' as p;

/// Authenticated loopback workspace shared by a human and an assistant.
final class WorkspaceServer {
  WorkspaceServer._(this._server, this.session, this.token);

  /// Starts a random local port. The token is generated per owned session.
  static Future<WorkspaceServer> start(WorkspaceSession session) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random.secure();
    final token = base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
    final workspace = WorkspaceServer._(server, session, token);
    server.listen((request) {
      final future = workspace._handle(request);
      workspace._requests.add(future);
      unawaited(future.whenComplete(() => workspace._requests.remove(future)));
    });
    return workspace;
  }

  final HttpServer _server;

  /// The source-aware rendering session.
  final WorkspaceSession session;

  /// Local bearer token. Keep the descriptor private to the project user.
  final String token;
  final _requests = <Future<void>>{};
  Future<void> _tail = Future.value();
  int _queued = 0;
  bool _closed = false;

  /// Base address for authenticated HTTP tools.
  String get endpoint => 'http://127.0.0.1:${_server.port}';

  /// Browser URL with the token in a fragment, absent from server request logs.
  String get url => '$endpoint/#$token';

  /// Serializable connection information for `fluvie session` or other tools.
  Map<String, Object?> get descriptor => {
    'schemaVersion': 1,
    'endpoint': endpoint,
    'token': token,
    'url': url,
    ...session.status,
  };

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      response.headers.set('Cache-Control', 'no-store');
      final host = request.headers.value('host')?.split(':').first;
      final origin = request.headers.value('origin');
      if (!{'127.0.0.1', 'localhost'}.contains(host) || (origin != null && origin != endpoint)) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/') {
        response.headers.contentType = ContentType.html;
        response.headers.set(
          'Content-Security-Policy',
          "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; "
              "connect-src 'self'; img-src 'self'; media-src 'self'; base-uri 'none'; frame-ancestors 'none'",
        );
        response.write(workspacePage);
        return;
      }
      if ((request.headers.value('X-Fluvie-Token') ?? request.uri.queryParameters['token']) !=
          token) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/status') {
        _json(response, session.status);
      } else if (request.method == 'GET' && request.uri.path == '/source') {
        final source = File(session.target.path);
        if (await source.length() > 262144) {
          throw const CliFailure('Source exceeds the 256 KiB view limit.');
        }
        _json(response, {'source': await source.readAsString()});
      } else if (request.method == 'GET' && request.uri.path == '/artifact') {
        final path = request.uri.queryParameters['path'];
        final root = session.directory.resolveSymbolicLinksSync();
        if (path == null ||
            !File(path).existsSync() ||
            !p.isWithin(root, File(path).resolveSymbolicLinksSync())) {
          response.statusCode = HttpStatus.notFound;
          return;
        }
        response.headers.contentType = switch (p.extension(path)) {
          '.png' => ContentType('image', 'png'),
          '.mp4' => ContentType('video', 'mp4'),
          '.webm' => ContentType('video', 'webm'),
          '.gif' => ContentType('image', 'gif'),
          '.json' => ContentType.json,
          _ => ContentType.binary,
        };
        await response.addStream(File(path).openRead());
      } else if (request.method == 'POST' && request.uri.path == '/jobs') {
        if (_rejectFullQueue(response)) return;
        final bytes = BytesBuilder();
        await for (final chunk in request) {
          if (bytes.length + chunk.length > 65536) throw ArgumentError('Job exceeds 64 KiB.');
          bytes.add(chunk);
        }
        final input = jsonDecode(utf8.decode(bytes.takeBytes()));
        if (input is! Map<String, Object?>) throw ArgumentError('A job must be a JSON object.');
        // Other bodies can complete while this request is being read.
        if (_rejectFullQueue(response)) return;
        _queued++;
        final job = _tail.then((_) => session.execute(input));
        _tail = job.then<void>((_) {}, onError: (Object _) {});
        try {
          _json(response, await job);
        } finally {
          _queued--;
        }
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } on Object catch (error) {
      response.statusCode = error is ArgumentError || error is FormatException
          ? HttpStatus.badRequest
          : HttpStatus.conflict;
      _json(response, {'ok': false, 'error': '$error'});
    } finally {
      try {
        await response.close();
      } on IOException {
        // A disconnected client does not own the session's rendering lifetime.
      }
    }
  }

  bool _rejectFullQueue(HttpResponse response) {
    if (!_closed && _queued < 4) return false;
    response.statusCode = HttpStatus.serviceUnavailable;
    _json(response, {'error': 'Workspace queue is full or closed. Retry later.'});
    return true;
  }

  static void _json(HttpResponse response, Map<String, Object?> value) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(value));
  }

  /// Closes connections, stops the worker and joins all owned requests.
  Future<void> close() async {
    _closed = true;
    await _server.close(force: true);
    await session.close();
    await _tail;
    await Future.wait(_requests.toList());
  }
}
