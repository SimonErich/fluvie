import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/rendering/platform/cancellable_process_runner.dart';

void main() {
  test('cancellation terminates and reaps a real child process', () async {
    final directory = Directory.systemTemp.createTempSync('fluvie_cancel_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final marker = File('${directory.path}/child.pid');
    final cancellation = RenderCancellation();
    final operation = CancellableProcessRunner(cancellation).run('sh', [
      '-c',
      r'echo $$ > "$1"; exec sleep 60',
      'fluvie-cancel-test',
      marker.path,
    ]);
    final result = expectLater(operation, throwsA(isA<RenderCancelledException>()));
    for (var i = 0; i < 100 && !marker.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(marker.existsSync(), isTrue);
    final pid = int.parse(marker.readAsStringSync().trim());
    cancellation.cancel();
    await result.timeout(const Duration(seconds: 3));
    final probe = await Process.run('kill', ['-0', '$pid']);
    expect(probe.exitCode, isNot(0), reason: 'Cancellation must finish after the child exits.');
  }, skip: Platform.isWindows);

  test('already cancelled token never spawns a command', () async {
    final token = RenderCancellation()..cancel();
    await expectLater(
      CancellableProcessRunner(token).run('definitely-not-a-binary', []),
      throwsA(isA<RenderCancelledException>()),
    );
  });
}
