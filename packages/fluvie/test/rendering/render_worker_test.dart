@Tags(['ffmpeg'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

Future<void> _publish(File file, Object value) async {
  final pending = File('${file.path}.pending');
  await pending.writeAsString(jsonEncode(value));
  await pending.rename(file.path);
}

Future<Map<String, Object?>> _read(File file) async {
  while (!file.existsSync()) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return jsonDecode(await file.readAsString()) as Map<String, Object?>;
}

void main() {
  test('a custom host that declines the mailbox callback fails explicitly', () async {
    final mailbox = await Directory.systemTemp.createTemp('fluvie_declined_worker_');
    addTearDown(() => mailbox.delete(recursive: true));
    final host = RenderHostContext(
      pumpWidget: (_) async {},
      pumpFrame: () async {},
      runAsync: <T>(Future<T> Function() callback) async => null,
      setViewSize: (_, _) {},
    );
    await expectLater(
      runFluvieWorker(
        mailbox: mailbox,
        hostFactory: () => host,
        videoFactory: () => throw StateError('must not build without a mailbox request'),
      ),
      throwsA(
        isA<StateError>().having((error) => error.message, 'message', contains('no request')),
      ),
    );
  });

  test('a custom host that declines the entry callback returns a useful failure', () async {
    final mailbox = await Directory.systemTemp.createTemp('fluvie_declined_entry_');
    addTearDown(() => mailbox.delete(recursive: true));
    await _publish(File('${mailbox.path}/request.json'), {
      'id': 'declined',
      'invocation': {'operation': 'frame', 'outputDir': '${mailbox.path}/frame'},
    });
    var hostCalls = 0;
    final worker = runFluvieWorker(
      mailbox: mailbox,
      hostFactory: () {
        final decline = hostCalls++ > 0;
        return RenderHostContext(
          pumpWidget: (_) async {},
          pumpFrame: () async {},
          runAsync: <T>(Future<T> Function() callback) async => decline ? null : await callback(),
          setViewSize: (_, _) {},
        );
      },
      videoFactory: () => throw StateError('must not invoke a declined callback'),
    );
    final response = await _read(File('${mailbox.path}/response.json'));
    await _publish(File('${mailbox.path}/request.json'), {'stop': true});
    await worker;
    expect(response['ok'], isFalse);
    expect(response['error'], contains('entry returned no Video'));
    expect(response['id'], 'declined');
  });

  testWidgets('warm worker rebuilds frames, reports errors and accepts the next request', (
    tester,
  ) async {
    final mailbox = Directory.systemTemp.createTempSync('fluvie_worker_protocol_');
    addTearDown(() => mailbox.deleteSync(recursive: true));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var builds = 0;
    var hosts = 0;
    RenderHostContext host() {
      hosts++;
      return RenderHostContext(
        pumpWidget: tester.pumpWidget,
        pumpFrame: () => tester.pump(),
        runAsync: tester.runAsync,
        setViewSize: (w, h) {
          tester.view.physicalSize = Size(w.toDouble(), h.toDouble());
          tester.view.devicePixelRatio = 1;
        },
      );
    }

    final responses = <Map<String, Object?>>[];
    final pixels = <List<int>>[];
    Map<String, Object?>? ready;
    // IO runs on the real clock while the worker's adapter owns Flutter pumps.
    Future<void> communicate() async {
      final request = File('${mailbox.path}/request.json');
      final response = File('${mailbox.path}/response.json');
      ready = await _read(File('${mailbox.path}/ready.json'));
      for (final id in ['bad id', 'invalid', 'first', 'broken', 'second']) {
        await _publish(request, {
          'id': id,
          'invocation': {
            'operation': 'frame',
            'outputDir': '${mailbox.path}/$id',
            if (id == 'invalid') 'unknown': true,
          },
        });
        final value = await _read(response);
        responses.add(value);
        await response.delete();
        if (value['ok'] == true) {
          pixels.add((await File('${mailbox.path}/$id/frames.rgba').readAsBytes()).sublist(0, 4));
        }
      }
      await _publish(request, {'stop': true});
    }

    late Future<void> transport;
    await tester.runAsync(() async {
      transport = communicate();
    });
    await runFluvieWorker(
      mailbox: mailbox,
      hostFactory: host,
      videoFactory: () {
        builds++;
        if (builds == 2) throw StateError('authored failure');
        return Video(
          width: 8,
          height: 8,
          scenes: [
            Scene(
              duration: 1.frames,
              children: [
                ColoredBox(
                  color: builds == 1 ? const Color(0xffff0000) : const Color(0xff00ff00),
                  child: const SizedBox.expand(),
                ),
              ],
            ),
          ],
        );
      },
    );
    await tester.runAsync(() => transport);
    expect(ready?['schemaVersion'], 1);
    expect(responses.map((response) => response['ok']), [false, false, true, false, true]);
    expect(responses[3]['error'], contains('authored failure'));
    expect(responses.every((response) => response['backend'] == 'flutter-test'), isTrue);
    expect(pixels, [
      [255, 0, 0, 255],
      [0, 255, 0, 255],
    ]);
    expect(builds, 3);
    expect(hosts, 4);
  });

  for (final payload in ['[]', '{', 'x' * 65537]) {
    test('malformed transport input retires the worker (${payload.length} bytes)', () async {
      final mailbox = await Directory.systemTemp.createTemp('fluvie_bad_worker_');
      addTearDown(() => mailbox.delete(recursive: true));
      await File('${mailbox.path}/request.json').writeAsString(payload);
      final host = RenderHostContext(
        pumpWidget: (_) async {},
        pumpFrame: () async {},
        runAsync: <T>(Future<T> Function() callback) async => callback(),
        setViewSize: (_, _) {},
      );
      await expectLater(
        runFluvieWorker(
          mailbox: mailbox,
          hostFactory: () => host,
          videoFactory: () => throw StateError('must not build malformed input'),
        ),
        throwsA(anyOf(isA<ArgumentError>(), isA<FormatException>())),
      );
    });
  }
}
