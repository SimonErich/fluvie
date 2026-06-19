import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/render/spec_composition.dart';

Map<String, Object?> _specJson() => {
  'fluvieSpec': 1,
  'size': 'square',
  'fps': 30,
  'scenes': [
    {
      'duration': '2s',
      'children': [
        {
          'type': 'Text',
          'text': 'Hi',
          'animate': [
            {'preset': 'fadeIn'},
          ],
        },
      ],
    },
  ],
};

void main() {
  test('compositionFromSpec derives geometry, fps, and frame count', () {
    final entry = compositionFromSpec(VideoSpec.fromJson(_specJson()));
    expect(entry.width, 1080);
    expect(entry.height, 1080);
    expect(entry.fps, 30);
    expect(entry.frameCount, 60); // 2s at 30fps
    expect(entry.mediaSources, isEmpty);
    expect(entry.build, returnsNormally);
  });

  test('compositionFromSpecFile reads and builds from disk', () {
    final dir = Directory.systemTemp.createTempSync('fluvie_spec_comp_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/v.fluvie.json';
    writeSpecToFile(VideoSpec.fromJson(_specJson()), path);

    expect(compositionFromSpecFile(path).frameCount, 60);
  });

  test('videoSpecFromFile rejects a non-object document', () {
    final dir = Directory.systemTemp.createTempSync('fluvie_spec_bad_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/bad.json';
    File(path).writeAsStringSync('[]');

    expect(() => videoSpecFromFile(path), throwsA(isA<FormatException>()));
  });
}
