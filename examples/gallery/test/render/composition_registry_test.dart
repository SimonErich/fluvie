// rendering runtime widgets are not exported from package:fluvie/fluvie.dart
// yet, and only the orchestrator edits the barrel.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/lessons/lessons.dart';
import 'package:fluvie_example/render/composition_registry.dart';

Future<Uint8List> _pixelsAtFrame(
  WidgetTester tester,
  RenderController controller,
  GlobalKey boundaryKey,
  int frame,
) async {
  controller.seek(frame);
  await tester.pump();
  late final Uint8List pixels;
  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final data = (await image.toByteData())!;
      pixels = Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } finally {
      image.dispose();
    }
  });
  return pixels;
}

void main() {
  group('composition registry', () {
    test('the demo key resolves to the 320x240@30, 48-frame entry', () {
      final entry = compositionForKey('demo');

      expect(entry, isNotNull);
      expect(entry!.key, 'demo');
      expect(entry.width, 320);
      expect(entry.height, 240);
      expect(entry.fps, 30);
      expect(entry.frameCount, 48);
    });

    test('an unknown key resolves to null', () {
      expect(compositionForKey('does_not_exist'), isNull);
    });

    test('the known keys are exactly demo, multi_scene, starter, and the lessons (WI-35)', () {
      expect(knownCompositionKeys, [
        'demo',
        'multi_scene',
        'starter',
        '01_hello_video',
        '02_text_and_motion',
        '03_timing_and_triggers',
        '04_scenes_and_transitions',
        '05_images_and_clips',
        '06_collage',
        '07_charts',
        '08_code_doc_intro',
        '09_diagrams_and_webviews',
        '10_audio_and_captions',
        '11_templates_and_aspects',
        '12_the_kitchen_sink',
        '13_generative_content',
      ]);
    });

    test('every lesson key resolves to an entry matching its Video geometry (WI-35)', () {
      for (final lesson in lessons) {
        final entry = compositionForKey(lesson.id);
        final video = lesson.video();

        expect(entry, isNotNull, reason: lesson.id);
        expect(entry!.key, lesson.id);
        expect(entry.width, video.width, reason: lesson.id);
        expect(entry.height, video.height, reason: lesson.id);
        expect(entry.fps, video.fps, reason: lesson.id);
        expect(entry.frameCount, video.totalFrames, reason: lesson.id);
      }
    });

    testWidgets('demo pixels differ between frame 0 and 24 and repeat at 24', (tester) async {
      tester.view.physicalSize = const ui.Size(320, 240);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final entry = compositionForKey('demo')!;
      final controller = RenderController();
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RenderControllerScope(
          controller: controller,
          child: RepaintBoundary(key: boundaryKey, child: entry.build()),
        ),
      );

      final atFrame0 = await _pixelsAtFrame(tester, controller, boundaryKey, 0);
      final atFrame24 = await _pixelsAtFrame(tester, controller, boundaryKey, 24);
      final atFrame24Again = await _pixelsAtFrame(tester, controller, boundaryKey, 24);

      expect(atFrame0, isNot(equals(atFrame24)));
      expect(atFrame24, atFrame24Again);
    });
  });
}
