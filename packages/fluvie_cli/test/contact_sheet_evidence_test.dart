import 'dart:io';

import 'package:fluvie_cli/src/contact_sheet_evidence.dart';
import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

void main() {
  test('contact sheet cache binds source, toolchain and actual picture identity', () async {
    final directory = Directory.systemTemp.createTempSync('fluvie_sheet_cache_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/cat.mp4')..writeAsBytesSync([1]);
    var captures = 0;
    Future<MediaContactSheet> capture(Uri source, {required String outputPath}) async {
      captures++;
      final file = File(outputPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync([captures]);
      return MediaContactSheet(filePath: file.path, width: 960, height: 360, cells: const []);
    }

    Future<Map<String, Object?>> load(String version) => cachedContactSheet(
      source,
      sourceHash: 'source',
      outputDirectory: '${directory.path}/evidence',
      toolchain: {'version': version},
      capture: capture,
    );
    final first = await load('1');
    expect((await load('1'))['sha256'], first['sha256']);
    expect(captures, 1);
    final second = await load('2');
    expect(captures, 2);
    expect(second['filePath'], isNot(first['filePath']));
    File(second['filePath']! as String).writeAsBytesSync([99]);
    expect((await load('2'))['sha256'], isNot(second['sha256']));
    expect(captures, 3);
    File('${first['filePath']}.json').writeAsStringSync('broken cache metadata');
    await load('1');
    expect(captures, 4);
  });
}
