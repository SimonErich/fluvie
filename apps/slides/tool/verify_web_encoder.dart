// Real browser acceptance for the shipped FFmpeg and WebCodecs bridges. No network or Dart
// packages are needed. Vendor assets with tool/fetch_ffmpeg.sh first, then run:
// dart tool/verify_web_encoder.dart (CHROME_EXECUTABLE may override Chrome).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final web = Directory.fromUri(Platform.script.resolve('../web/'));
  if (!File('${web.path}/ffmpeg/core/ffmpeg-core.wasm').existsSync()) {
    throw StateError('Run apps/slides/tool/fetch_ffmpeg.sh before this acceptance test.');
  }
  final temporary = Directory.systemTemp.createTempSync('fluvie_browser_acceptance_');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final client = HttpClient();
  Process? chrome;
  WebSocket? socket;
  try {
    unawaited(_serve(server, web));
    final endpoint = Completer<String>();
    chrome = await Process.start(Platform.environment['CHROME_EXECUTABLE'] ?? 'google-chrome', [
      '--headless=new',
      '--no-sandbox',
      '--disable-dev-shm-usage',
      '--no-first-run',
      '--remote-debugging-port=0',
      '--user-data-dir=${temporary.path}',
      'http://127.0.0.1:${server.port}/_fluvie_encoder_test.html',
    ]);
    unawaited(chrome.stdout.drain<void>());
    chrome.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      final match = RegExp('DevTools listening on (ws://[^ ]+)').firstMatch(line);
      if (match != null && !endpoint.isCompleted) endpoint.complete(match[1]!);
    });
    final browser = Uri.parse(await endpoint.future.timeout(const Duration(seconds: 15)));
    String? target;
    for (var i = 0; i < 100 && target == null; i++) {
      final request = await client.getUrl(
        Uri.parse('http://${browser.host}:${browser.port}/json/list'),
      );
      final response = await request.close();
      final pages = jsonDecode(await response.transform(utf8.decoder).join()) as List<dynamic>;
      for (final page in pages.cast<Map<String, dynamic>>()) {
        if (page['type'] == 'page') target = page['webSocketDebuggerUrl'] as String;
      }
      if (target == null) await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (target == null) throw StateError('Chrome did not create its acceptance page.');
    socket = await WebSocket.connect(target);
    final pending = <int, Completer<Map<String, dynamic>>>{};
    var serial = 0;
    socket.listen((event) {
      final result = jsonDecode(event as String) as Map<String, dynamic>;
      if (result['id'] case final int id) pending.remove(id)?.complete(result);
    });
    Future<Map<String, dynamic>> evaluate(String expression) async {
      final id = ++serial;
      final completer = Completer<Map<String, dynamic>>();
      pending[id] = completer;
      socket!.add(
        jsonEncode({
          'id': id,
          'method': 'Runtime.evaluate',
          'params': {
            'expression': expression,
            'awaitPromise': true,
            'returnByValue': true,
          },
        }),
      );
      final reply = await completer.future.timeout(const Duration(minutes: 2));
      if (reply.containsKey('error')) throw StateError('${reply['error']}');
      final result = reply['result'] as Map<String, dynamic>;
      if (result.containsKey('exceptionDetails')) throw StateError('${result['exceptionDetails']}');
      return result;
    }

    var ready = false;
    for (var attempt = 0; attempt < 300 && !ready; attempt++) {
      try {
        final state = await evaluate(
          "location.pathname === '/_fluvie_encoder_test.html' && document.readyState === 'complete'",
        );
        ready = (state['result'] as Map<String, dynamic>)['value'] == true;
      } on Object {
        // Chrome's initial about:blank context can disappear during navigation.
      }
      if (!ready) await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!ready) throw StateError('Browser acceptance page did not finish loading');
    final result = await evaluate(
      '${File.fromUri(Platform.script.resolve('browser_pixel_oracle.js')).readAsStringSync()}\n'
      '${File.fromUri(Platform.script.resolve('browser_encoder_assertions.js')).readAsStringSync()}',
    );
    stdout.writeln(jsonEncode((result['result'] as Map<String, dynamic>)['value']));
  } finally {
    await socket?.close();
    chrome?.kill();
    if (chrome != null) await chrome.exitCode;
    client.close(force: true);
    await server.close(force: true);
    for (var attempt = 0; temporary.existsSync(); attempt++) {
      try {
        temporary.deleteSync(recursive: true);
      } on FileSystemException {
        if (attempt >= 19) rethrow;
        // Chromium helpers finish their profile flush just after the parent.
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }
}

Future<void> _serve(HttpServer server, Directory web) async {
  await for (final request in server) {
    try {
      if (request.uri.path == '/_fluvie_encoder_test.html') {
        // Exercise the actual app module, omitting only the unrelated Flutter
        // bootstrap so the harness exercises both production media bridges.
        final page = File('${web.path}/index.html')
            .readAsStringSync()
            .replaceFirst(r'$FLUTTER_BASE_HREF', '/')
            .replaceAll(
              RegExp('<script[^>]*src="flutter_bootstrap.js"[^>]*></script>'),
              '',
            );
        request.response.headers.contentType = ContentType.html;
        request.response.write(page);
      } else if (request.uri.path == '/_fixture.mp4') {
        request.response.headers.contentType = ContentType('video', 'mp4');
        await request.response.addStream(
          File.fromUri(
            Platform.script.resolve('../../../examples/gallery/assets/fixtures/clip_1s.mp4'),
          ).openRead(),
        );
      } else if (request.uri.pathSegments.contains('..')) {
        request.response.statusCode = HttpStatus.forbidden;
      } else {
        final file = File('${web.path}${request.uri.path}');
        if (!file.existsSync()) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.headers.contentType = file.path.endsWith('.wasm')
              ? ContentType('application', 'wasm')
              : ContentType('text', 'javascript');
          await request.response.addStream(file.openRead());
        }
      }
      await request.response.close();
    } on Object {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }
}
