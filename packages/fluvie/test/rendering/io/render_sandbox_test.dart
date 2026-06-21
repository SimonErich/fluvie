import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/io/file_render_sandbox.dart';
import 'package:fluvie/src/rendering/io/memory_render_sandbox.dart';
import 'package:fluvie/src/rendering/io/render_sandbox.dart';

void main() {
  group('MemoryRenderSandbox', () {
    test('frames append through the sink and read back as one buffer', () async {
      final sandbox = MemoryRenderSandbox();
      await sandbox.create();
      final sink = sandbox.openFrames('frames.rgba')
        ..add(Uint8List.fromList([1, 2]))
        ..add(Uint8List.fromList([3, 4]));
      await sink.close();

      expect(await sandbox.readBytes('frames.rgba'), [1, 2, 3, 4]);
      expect(sandbox.directoryPath, isNull);
      expect(sandbox.names, contains('frames.rgba'));
    });

    test('text and bytes round-trip', () async {
      final sandbox = MemoryRenderSandbox();
      await sandbox.writeText('manifest.json', '{"v":1}');
      await sandbox.writeBytes('in.bin', Uint8List.fromList([9, 9]));

      expect(utf8.decode(await sandbox.readBytes('manifest.json')), '{"v":1}');
      expect(await sandbox.readBytes('in.bin'), [9, 9]);
    });

    test('reading a missing entry throws', () async {
      final sandbox = MemoryRenderSandbox();
      expect(sandbox.readBytes('nope'), throwsStateError);
    });
  });

  group('FileRenderSandbox', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('fluvie_sandbox_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('writes through to disk byte-for-byte', () async {
      final sandbox = FileRenderSandbox(Directory('${dir.path}/render'));
      await sandbox.create();
      final sink = sandbox.openFrames('frames.rgba')..add(Uint8List.fromList([1, 2, 3]));
      await sink.close();
      await sandbox.writeText('manifest.json', 'hi');
      await sandbox.writeBytes('out.mp4', Uint8List.fromList([7]));

      expect(sandbox.directoryPath, '${dir.path}/render');
      expect(File('${dir.path}/render/frames.rgba').readAsBytesSync(), [1, 2, 3]);
      expect(File('${dir.path}/render/manifest.json').readAsStringSync(), 'hi');
      expect(await sandbox.readBytes('out.mp4'), [7]);
    });
  });

  test('both backends satisfy the RenderSandbox contract', () {
    expect(MemoryRenderSandbox(), isA<RenderSandbox>());
    expect(FileRenderSandbox(Directory.systemTemp), isA<RenderSandbox>());
  });
}
