import 'dart:io';

import 'package:flutter/widgets.dart' show Directionality, TextDirection;
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

  test('compositionFromSpec wraps the composition in an LTR Directionality', () {
    // The capture canvas has no ambient locale, so a spec-built Text (a bare
    // RichText) needs a Directionality ancestor the way the hand-written lessons
    // and renderTemplate supply one; without it the render throws at mount.
    final built = compositionFromSpec(VideoSpec.fromJson(_specJson())).build();

    expect(built, isA<Directionality>());
    expect((built as Directionality).textDirection, TextDirection.ltr);
  });

  test('compositionFromSpecFile reads and builds from disk', () {
    final dir = Directory.systemTemp.createTempSync('fluvie_spec_comp_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/v.fluvie.json';
    writeSpecToFile(VideoSpec.fromJson(_specJson()), path);

    expect(compositionFromSpecFile(path).frameCount, 60);
  });

  test('videoSpecFromFile surfaces an unknown property through onWarn', () {
    final dir = Directory.systemTemp.createTempSync('fluvie_spec_warn_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/v.fluvie.json';
    File(path).writeAsStringSync(
      '{"fluvieSpec":1,"size":"square","fps":30,"scenes":[{"duration":"2s",'
      '"children":[{"type":"Box","fill":1}]}]}',
    );
    final warnings = <FluvieSpecWarning>[];

    videoSpecFromFile(path, onWarn: warnings.add);

    expect(warnings, isNotEmpty);
    expect(warnings.first.message, contains('"fill"'));
  });

  test('videoSpecFromFile rejects a non-object document', () {
    final dir = Directory.systemTemp.createTempSync('fluvie_spec_bad_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/bad.json';
    File(path).writeAsStringSync('[]');

    expect(() => videoSpecFromFile(path), throwsA(isA<FormatException>()));
  });
}
