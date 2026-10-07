import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/local_media_bridge.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  late Directory project;
  late LocalMediaBridge bridge;
  setUp(() async {
    project = await Directory.systemTemp.createTemp('fluvie_bridge_test_');
    await Directory('${project.path}/assets/nested').create(recursive: true);
    await File('${project.path}/assets/nested/story.txt').writeAsString('a cat story');
    bridge = await LocalMediaBridge.start(
      projectDir: project,
      toolchain: const FfmpegToolchain(
        ffmpegPath: 'ffmpeg',
        ffprobePath: 'ffprobe',
        build: 'fixture',
        ffmpegVersion: '8.0',
        ffprobeVersion: '8.0',
      ),
    );
  });
  tearDown(() async {
    await bridge.close();
    await project.delete(recursive: true);
  });

  test('requires session token and returns recursive dropped asset keys', () async {
    expect((await http.get(bridge.endpoint.resolve('/assets'))).statusCode, 403);
    final response = await http.get(
      bridge.endpoint.resolve('/assets'),
      headers: {'X-Fluvie-Token': bridge.sessionToken},
    );
    expect(jsonDecode(response.body), {
      'assets': ['assets/nested/story.txt'],
    });
    final asset = await http.get(
      bridge.endpoint
          .resolve('/assets')
          .replace(
            queryParameters: {'path': 'assets/nested/story.txt', 'token': bridge.sessionToken},
          ),
    );
    expect(asset.body, 'a cat story');
  });

  test('denies remote browser origins and paths outside project', () async {
    final headers = {'X-Fluvie-Token': bridge.sessionToken};
    expect(
      (await http.get(
        bridge.endpoint.resolve('/status'),
        headers: {...headers, 'Origin': 'https://example.com'},
      )).statusCode,
      403,
    );
    expect(
      (await http.get(
        bridge.endpoint.resolve('/assets').replace(queryParameters: {'path': '../outside.txt'}),
        headers: headers,
      )).statusCode,
      404,
    );
  });

  test('audio provider is cached and invalidated on reload', () async {
    var calls = 0;
    bridge.setAudioProvider(() async {
      calls++;
      return File('${project.path}/assets/nested/story.txt');
    });
    final url = bridge.endpoint
        .resolve('/audio')
        .replace(queryParameters: {'token': bridge.sessionToken});
    expect((await http.get(url)).body, 'a cat story');
    expect((await http.get(url)).body, 'a cat story');
    expect(calls, 1);
    bridge.notifyReload();
    await http.get(url);
    expect(calls, 2);
  });

  test('a failed audio preparation can be retried without restarting preview', () async {
    var calls = 0;
    bridge.setAudioProvider(() async {
      if (++calls == 1) throw StateError('temporary preparation failure');
      return File('${project.path}/assets/nested/story.txt');
    });
    final url = bridge.endpoint
        .resolve('/audio')
        .replace(queryParameters: {'token': bridge.sessionToken});
    expect((await http.get(url)).statusCode, 500);
    expect((await http.get(url)).body, 'a cat story');
    expect(calls, 2);
  });

  test('reload events arrive live and session cleanup closes the stream', () async {
    final client = http.Client();
    addTearDown(client.close);
    final response = await client.send(
      http.Request(
        'GET',
        bridge.endpoint.resolve('/events').replace(queryParameters: {'token': bridge.sessionToken}),
      ),
    );
    final lines = StreamIterator(
      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((line) => line.startsWith('data: ')),
    );
    addTearDown(lines.cancel);
    expect(await lines.moveNext(), isTrue);
    expect(lines.current, contains('ready'));
    bridge.notifyReload();
    expect(await lines.moveNext(), isTrue);
    expect(lines.current, contains('reload'));
    await bridge.close().timeout(const Duration(seconds: 3));
  });
}
