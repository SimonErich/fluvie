import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/preview_session.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _Process extends Mock implements Process {}

void main() {
  test('announces URL once and rebuilds changed authored files through the daemon', () async {
    final project = Directory.systemTemp.createTempSync('fluvie_preview_session_');
    addTearDown(() => project.deleteSync(recursive: true));
    final source = File(p.join(project.path, 'lib/cat.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('const cat = 1;');
    final output = StreamController<List<int>>();
    final input = StreamController<List<int>>();
    final exit = Completer<int>();
    final process = _Process();
    final stdinSink = IOSink(input.sink);
    when(() => process.stdout).thenAnswer((_) => output.stream);
    when(() => process.stderr).thenAnswer((_) => const Stream.empty());
    when(() => process.stdin).thenReturn(stdinSink);
    when(() => process.exitCode).thenAnswer((_) => exit.future);
    final out = StringBuffer();
    final err = StringBuffer();
    var reloaded = 0;
    final requests = <Map<String, dynamic>>[];
    final inputSubscription = input.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final request = (jsonDecode(line) as List).single as Map<String, dynamic>;
          requests.add(request);
          output.add(
            utf8.encode(
              '${jsonEncode([
                {
                  'id': request['id'],
                  'result': {'code': 0},
                },
              ])}\n',
            ),
          );
        });
    final running = PreviewSession(
      process: process,
      projectDir: project.path,
      device: 'web-server',
      out: out,
      err: err,
      json: true,
      onReload: () => reloaded++,
    ).run();
    output.add(
      utf8.encode(
        '${jsonEncode([
          {
            'event': 'app.start',
            'params': {'appId': 'cat-app'},
          },
          {
            'event': 'app.webLaunchUrl',
            'params': {'url': 'http://localhost:54321', 'secret': 'never-forward'},
          },
        ])}\n',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final ready = jsonDecode(out.toString().trim()) as Map<String, dynamic>;
    expect(ready['url'], 'http://localhost:54321');
    expect(out.toString(), isNot(contains('secret')));
    source.writeAsStringSync('const cat = 22;');
    await Future<void>.delayed(const Duration(milliseconds: 1900));
    expect(requests.single['method'], 'app.restart');
    expect(requests.single['params'], containsPair('appId', 'cat-app'));
    expect(reloaded, 1);
    expect(out.toString(), contains('reloaded'));
    exit.complete(0);
    expect(await running, 0);
    await stdinSink.close();
    await inputSubscription.cancel();
    await output.close();
    expect(err.toString(), isEmpty);
  });

  test('generated artifacts are excluded from source watching', () {
    final project = Directory.systemTemp.createTempSync('fluvie_preview_watch_');
    addTearDown(() => project.deleteSync(recursive: true));
    File(p.join(project.path, 'lib/cat.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('const cat = 1;');
    final first = sourceFingerprint(project.path);
    File(p.join(project.path, 'build/generated.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('const generated = 1;');
    expect(sourceFingerprint(project.path), first);
    File(p.join(project.path, 'assets/deep/cat.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('cat');
    expect(sourceFingerprint(project.path), isNot(first));
  });
}
