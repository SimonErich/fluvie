@Tags(['ffmpeg'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/workspace_server.dart';
import 'package:fluvie_cli/src/workspace_session.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test('workspace authenticates tools and confines artifacts to its owned directory', () async {
    final root = await Directory.systemTemp.createTemp('fluvie_http_workspace_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/lib/video.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('Video build() => video;');
    File('${root.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    final directory = Directory('${root.path}/build/session')..createSync(recursive: true);
    final session = WorkspaceSession(
      target: FileTarget(projectDir: root.path, path: source.path, entry: 'build'),
      directory: directory,
      toolchain: const FfmpegToolchain(
        ffmpegPath: 'ffmpeg',
        ffprobePath: 'ffprobe',
        build: 'test',
        ffmpegVersion: 'test',
        ffprobeVersion: 'test',
      ),
      err: StringBuffer(),
      capture: (input) async {
        final output = input['outputDir']! as String;
        File('$output/frame.png').writeAsBytesSync([1, 2, 3]);
        File('$output/render-result.json').writeAsStringSync(
          jsonEncode({'schemaVersion': 1, 'kind': 'frame', 'filePath': '$output/frame.png'}),
        );
        return {'elapsedMilliseconds': 1};
      },
    );
    final server = await WorkspaceServer.start(session);
    addTearDown(server.close);
    final client = http.Client();
    addTearDown(client.close);
    final headers = {'X-Fluvie-Token': server.token};
    final status = Uri.parse('${server.endpoint}/status');
    expect((await client.get(status)).statusCode, 403);
    expect(
      (await client.get(
        status,
        headers: {...headers, 'Origin': 'https://external.test'},
      )).statusCode,
      403,
    );
    expect((await client.get(status, headers: headers)).statusCode, 200);
    final response = await client.post(
      Uri.parse('${server.endpoint}/jobs'),
      headers: headers,
      body: jsonEncode({'operation': 'frame', 'frameIndex': 0}),
    );
    expect(response.statusCode, 200);
    final result = jsonDecode(response.body) as Map<String, Object?>;
    Uri artifact(String path) =>
        Uri.parse('${server.endpoint}/artifact').replace(queryParameters: {'path': path});
    expect(
      (await client.get(artifact(result['filePath']! as String), headers: headers)).bodyBytes,
      [1, 2, 3],
    );
    expect((await client.get(artifact(source.path), headers: headers)).statusCode, 404);
    if (!Platform.isWindows) {
      final link = Link('${directory.path}/escape.dart')..createSync(source.path);
      expect((await client.get(artifact(link.path), headers: headers)).statusCode, 404);
    }
    expect(
      (await client.post(
        Uri.parse('${server.endpoint}/jobs'),
        headers: headers,
        body: jsonEncode({'operation': 'frame', 'sourceRevision': 'stale'}),
      )).statusCode,
      409,
    );
    expect(
      (await client.post(
        Uri.parse('${server.endpoint}/jobs'),
        headers: headers,
        body: jsonEncode({'operation': 'shell'}),
      )).statusCode,
      400,
    );
    expect(
      (await client.post(
        Uri.parse('${server.endpoint}/jobs'),
        headers: headers,
        body: 'x' * 65537,
      )).statusCode,
      400,
    );
  });

  test('concurrent request bodies cannot exceed the four-job serial queue', () async {
    final root = await Directory.systemTemp.createTemp('fluvie_workspace_queue_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/lib/video.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('Video build() => video;');
    File('${root.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    final release = Completer<void>();
    var active = 0;
    var maximum = 0;
    final session = WorkspaceSession(
      target: FileTarget(projectDir: root.path, path: source.path, entry: 'build'),
      directory: Directory('${root.path}/build/session'),
      toolchain: const FfmpegToolchain(
        ffmpegPath: 'ffmpeg',
        ffprobePath: 'ffprobe',
        build: 'test',
        ffmpegVersion: 'test',
        ffprobeVersion: 'test',
      ),
      err: StringBuffer(),
      capture: (input) async {
        active++;
        if (active > maximum) maximum = active;
        await release.future;
        final output = input['outputDir'];
        File('$output/frame.png').writeAsBytesSync([1]);
        File('$output/render-result.json').writeAsStringSync(
          jsonEncode({
            'schemaVersion': 1,
            'kind': 'frame',
            'filePath': '$output/frame.png',
          }),
        );
        active--;
        return {'elapsedMilliseconds': 1};
      },
    );
    final server = await WorkspaceServer.start(session);
    addTearDown(server.close);
    const body = '{"operation":"frame"}';
    final port = Uri.parse(server.endpoint).port;
    final pending = await Future.wait(
      List.generate(6, (_) async {
        final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
        addTearDown(socket.destroy);
        socket.write(
          'POST /jobs HTTP/1.1\r\nHost: 127.0.0.1:$port\r\n'
          'X-Fluvie-Token: ${server.token}\r\nContent-Length: ${body.length}\r\n'
          'Connection: close\r\n\r\n',
        );
        await socket.flush();
        return socket;
      }),
    );
    // Admit headers before completing any body to exercise the asynchronous
    // admission boundary rather than six already-buffered HTTP requests.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final requests = pending.map((socket) async {
      socket.write(body);
      await socket.flush();
      final response = await socket.cast<List<int>>().transform(utf8.decoder).join();
      return int.parse(response.split(' ')[1]);
    }).toList();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    release.complete();
    final responses = await Future.wait(requests);
    expect(maximum, 1);
    expect(responses.where((code) => code == 200), hasLength(4));
    expect(responses.where((code) => code == 503), hasLength(2));
  });
}
