import 'dart:io';

import 'package:flutter/widgets.dart' show Directionality, TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_example/render/spec_composition.dart';

import 'render_harness.dart';

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
    final video = entry.video();
    expect(video.width, 1080);
    expect(video.height, 1080);
    expect(video.fps, 30);
    expect(video.totalFrames, 60); // 2s at 30fps
    expect(collectMediaSources(video.scenes), isEmpty);
    expect(entry.video, returnsNormally);
  });

  testWidgets('the capture path gives a spec-built Text an LTR Directionality', (tester) async {
    // The capture canvas has no ambient locale, so a spec-built Text (a bare
    // RichText) needs a Directionality ancestor the way the hand-written lessons
    // and renderTemplate supply one; without it the render throws at mount.
    // `renderVideo` supplies it, so the entry carries no wrapper of its own and
    // the proof is that the spec renders at all.
    final outDir = Directory.systemTemp.createTempSync('fluvie_spec_ltr_');
    addTearDown(() => outDir.deleteSync(recursive: true));

    final manifest = await runCaptureHarness(
      tester: tester,
      entry: compositionFromSpec(VideoSpec.fromJson(_specJson())),
      outDir: outDir,
      frameCountOverride: 2,
      cacheEnabled: false,
    );

    expect(manifest.frameCount, 2);
    expect(tester.takeException(), isNull);
    final ltr = tester.widget<Directionality>(
      find.ancestor(of: find.byType(Video), matching: find.byType(Directionality)).first,
    );
    expect(ltr.textDirection, TextDirection.ltr);
  });

  test('compositionFromSpecFile reads and builds from disk', () {
    final dir = Directory.systemTemp.createTempSync('fluvie_spec_comp_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/v.fluvie.json';
    writeSpecToFile(VideoSpec.fromJson(_specJson()), path);

    expect(compositionFromSpecFile(path).video().totalFrames, 60);
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
