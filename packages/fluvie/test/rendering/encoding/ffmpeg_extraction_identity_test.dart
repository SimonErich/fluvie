import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';
import 'package:fluvie/src/rendering/platform/process_runner.dart';

void main() {
  test('native build lookup is shared across concurrent calls and extractor instances', () async {
    final root = await Directory.systemTemp.createTemp('fluvie_extraction_identity_');
    addTearDown(() => root.delete(recursive: true));
    final tool = await _tool(root, 'fixture-a');
    final first = FfmpegFrameExtractionService(binaryPath: tool.path);
    final second = FfmpegFrameExtractionService(binaryPath: tool.path);
    final identities = await Future.wait([
      for (var call = 0; call < 4; call++) first.cacheIdentity,
      second.cacheIdentity,
    ]);
    expect(identities.first, isNotNull);
    expect(identities.toSet(), hasLength(1));
    expect(await File('${root.path}/versions').readAsLines(), hasLength(1));
  }, skip: Platform.isWindows);

  test(
    'replacing a decoder executable refreshes identity rather than reusing its build lookup',
    () async {
      final root = await Directory.systemTemp.createTemp('fluvie_extraction_identity_');
      addTearDown(() => root.delete(recursive: true));
      final tool = await _tool(root, 'fixture-a');
      final service = FfmpegFrameExtractionService(binaryPath: tool.path);
      final before = await service.cacheIdentity;
      await _tool(root, 'fixture-b-different-build');
      final after = await service.cacheIdentity;
      expect(before, isNotNull);
      expect(after, isNotNull);
      expect(after, isNot(before));
      expect(await File('${root.path}/versions').readAsLines(), hasLength(2));
    },
    skip: Platform.isWindows,
  );

  test(
    'unknown injected runners stay cold and explicit custom identities avoid native lookup',
    () async {
      final runner = _UnexpectedRunner();
      expect(await FfmpegFrameExtractionService(runner: runner).cacheIdentity, isNull);
      expect(
        await FfmpegFrameExtractionService(
          runner: runner,
          cacheIdentity: 'custom-rgba-v1',
        ).cacheIdentity,
        'custom-rgba-v1',
      );
      expect(
        await FfmpegFrameExtractionService(runner: runner, cacheIdentity: ' ').cacheIdentity,
        isNull,
      );
      expect(runner.calls, 0);
    },
  );

  test('unavailable or unrecognizable native build metadata cannot justify reuse', () async {
    expect(
      await const FfmpegFrameExtractionService(binaryPath: '/missing/ffmpeg').cacheIdentity,
      isNull,
    );
    final root = await Directory.systemTemp.createTemp('fluvie_extraction_identity_');
    addTearDown(() => root.delete(recursive: true));
    final tool = await _tool(root, 'fixture-a');
    await tool.writeAsString('#!/bin/sh\nprintf unrelated');
    expect(await FfmpegFrameExtractionService(binaryPath: tool.path).cacheIdentity, isNull);
  }, skip: Platform.isWindows);
}

Future<File> _tool(Directory root, String build) async {
  final tool = File('${root.path}/ffmpeg');
  await tool.writeAsString('''
#!/bin/sh
echo version >> '${root.path}/versions'
printf 'ffmpeg version $build\\nconfiguration: fixture-rgba\\n'
''');
  expect((await Process.run('chmod', ['+x', tool.path])).exitCode, 0);
  return tool;
}

class _UnexpectedRunner implements ProcessRunner {
  int calls = 0;
  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async {
    calls++;
    throw StateError('Identity lookup must not use an unknown custom runner');
  }
}
