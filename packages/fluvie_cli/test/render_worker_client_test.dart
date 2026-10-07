@Tags(['ffmpeg'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/render_worker_client.dart';
import 'package:test/test.dart';

void main() {
  test('serial worker transport verifies response identity and survives request failure', () async {
    final directory = await Directory.systemTemp.createTemp('fluvie_worker_test_');
    addTearDown(() => directory.delete(recursive: true));
    final client = RenderWorkerClient(mailbox: directory);
    final request = File('${directory.path}/request.json');
    final response = File('${directory.path}/response.json');
    Future<void> respond({required bool ok, bool stale = false}) async {
      while (!request.existsSync()) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final value = jsonDecode(request.readAsStringSync()) as Map<String, Object?>;
      await request.delete();
      await response.writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'id': stale ? 'previous' : value['id'],
          'ok': ok,
          if (!ok) 'error': 'broken video',
        }),
      );
    }

    final first = client.execute({'outputDir': directory.path});
    await respond(ok: false);
    await expectLater(first, throwsA(predicate((e) => '$e'.contains('broken video'))));
    final second = client.execute({'outputDir': directory.path});
    await respond(ok: true);
    expect((await second)['ok'], isTrue);
    final third = client.execute({'outputDir': directory.path});
    await respond(ok: true, stale: true);
    await expectLater(third, throwsA(predicate((e) => '$e'.contains('identity'))));
  });
  test('a lost engine retires its transport and rejects subsequent requests', () async {
    final mailbox = await Directory.systemTemp.createTemp('fluvie_dead_worker_');
    addTearDown(() => mailbox.delete(recursive: true));
    final exited = Completer<int>();
    final client = RenderWorkerClient(mailbox: mailbox, processExit: exited.future);
    final request = client.execute({'operation': 'frame'});
    exited.complete(1);
    await expectLater(request, throwsA(predicate((error) => '$error'.contains('stopped'))));
    expect(client.retired, isTrue);
    await expectLater(
      client.execute({'operation': 'frame'}),
      throwsA(predicate((error) => '$error'.contains('retired'))),
    );
  });
}
