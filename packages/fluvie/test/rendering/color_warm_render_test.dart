// The V6.2 acceptance spine: curves and LUTs paint through the real capture
// shell because the pre-pass compiled their shaders and baked their lookups
// first — and at intensity zero (or all-identity curves) the child mounts
// unwrapped, an exact no-op pinned byte for byte.

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/animation/effects/curves_effect.dart';
import 'package:fluvie/src/animation/effects/lut_effect.dart';
import 'package:fluvie/src/composition/runtime/color_lookup_collector.dart';
import 'package:fluvie/src/composition/runtime/shader_collector.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/rendering/pre_bake_color_lookups.dart';
import 'package:fluvie/src/rendering/pre_load_shaders.dart';

/// A 2-point warming cube: everything shifts toward red.
const _warmCube = '''
LUT_3D_SIZE 2
0.3 0.0 0.0
1.0 0.0 0.0
0.3 0.7 0.0
1.0 0.7 0.0
0.3 0.0 0.6
1.0 0.0 0.6
0.3 0.7 0.6
1.0 0.7 0.6
''';

Video _video(List<EffectLayer> effects) => Video(
  width: 96,
  height: 96,
  scenes: [
    Scene(
      duration: const Time.frames(30),
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: const ColoredBox(color: Color(0xFF4C6EF5)).effects(effects),
        ),
      ],
    ),
  ],
);

ToneCurve _lift() => ToneCurve.fromPoints(const [(0, 0.2), (1, 1)]);

Future<List<int>> _capturedBytes(WidgetTester tester, GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(boundary.toImage))!;
  final data = (await tester.runAsync(image.toByteData))!;
  return data.buffer.asUint8List();
}

Future<List<int>> _paint(WidgetTester tester, List<EffectLayer> effects) async {
  final video = _video(effects);
  late Map<String, ui.FragmentProgram> programs;
  late Map<String, ui.Image> lookups;
  await tester.runAsync(() async {
    programs = await preLoadCompositionShaders(composition: video);
    lookups = await preBakeCompositionColorLookups(
      composition: video,
      loadCubeText: (_) async => _warmCube,
    );
  });
  final key = GlobalKey();
  final shell = buildCaptureShell(
    composition: video,
    boundaryKey: key,
    controller: RenderController(),
    shaderPrograms: programs,
    colorLookups: lookups,
  );
  await tester.pumpWidget(shell.tree);
  await tester.pump();
  return _capturedBytes(tester, key);
}

void main() {
  group('a keyframed intensity', () {
    testWidgets('starting at zero still warms, because later frames need it', (tester) async {
      // The corpus shape: intensity ramps 0 to 1 over the element. Resolved
      // at the start frame the effect looks like a no-op, but frame 30 is
      // not, and the pre-pass must warm for the whole life, not frame 0.
      final video = VideoSpec.fromJson({
        'fluvieSpec': 1,
        'size': {'width': 96, 'height': 96},
        'fps': 30,
        'scenes': [
          {
            'duration': '60f',
            'children': [
              {
                'id': 'el-ramped',
                'type': 'Box',
                'color': '#4C6EF5',
                'effects': [
                  {
                    'kind': 'lut',
                    'asset': 'luts/warm.cube',
                    'intensity': {
                      'values': [0, 1],
                      'positions': ['0f', '60f'],
                    },
                  },
                ],
              },
            ],
          },
        ],
      }).build();

      expect(collectShaderAssets(video.scenes), {LutEffect.shaderAsset});
      expect(collectColorLookups(video.scenes).lutAssets, {'luts/warm.cube'});

      late Map<String, ui.FragmentProgram> programs;
      late Map<String, ui.Image> lookups;
      await tester.runAsync(() async {
        programs = await preLoadCompositionShaders(composition: video);
        lookups = await preBakeCompositionColorLookups(
          composition: video,
          loadCubeText: (_) async => _warmCube,
        );
      });
      final key = GlobalKey();
      final shell = buildCaptureShell(
        composition: video,
        boundaryKey: key,
        controller: RenderController(initialFrame: 30),
        shaderPrograms: programs,
        colorLookups: lookups,
      );
      await tester.pumpWidget(shell.tree);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('an animating child', () {
    testWidgets('repaints through the grade as the frame moves', (tester) async {
      // The child is red for the first half and green after; the graded
      // frame must follow it, or every clip under a LUT freezes on its
      // first painted frame.
      final video = VideoSpec.fromJson({
        'fluvieSpec': 1,
        'size': {'width': 96, 'height': 96},
        'fps': 30,
        'scenes': [
          {
            'duration': '60f',
            'children': [
              {
                'id': 'el-a',
                'type': 'Box',
                'color': '#C0392B',
                'effects': [
                  // The vignette sits inside the LUT's raster, so its ramp
                  // is what the snapshot must keep re-capturing.
                  {
                    'kind': 'vignette',
                    'amount': {
                      'values': [0, 0.9],
                      'positions': ['0f', '60f'],
                    },
                  },
                  {'kind': 'lut', 'asset': 'luts/warm.cube'},
                ],
              },
            ],
          },
        ],
      }).build();

      late Map<String, ui.FragmentProgram> programs;
      late Map<String, ui.Image> lookups;
      await tester.runAsync(() async {
        programs = await preLoadCompositionShaders(composition: video);
        lookups = await preBakeCompositionColorLookups(
          composition: video,
          loadCubeText: (_) async => _warmCube,
        );
      });
      final key = GlobalKey();
      final controller = RenderController();
      final shell = buildCaptureShell(
        composition: video,
        boundaryKey: key,
        controller: controller,
        shaderPrograms: programs,
        colorLookups: lookups,
      );
      await tester.pumpWidget(shell.tree);
      await tester.pump();
      final early = await _capturedBytes(tester, key);

      controller.seek(45);
      await tester.pump();
      final late_ = await _capturedBytes(tester, key);

      expect(late_, isNot(early));
    });
  });

  group('the collectors', () {
    test('report the colour shaders and the lookups the stack needs', () {
      final video = _video([
        Effect.curves(master: _lift()),
        Effect.lut(asset: 'luts/warm.cube'),
      ]);

      expect(
        collectShaderAssets(video.scenes),
        {CurvesEffect.shaderAsset, LutEffect.shaderAsset},
      );
      final plan = collectColorLookups(video.scenes);
      expect(plan.lutAssets, {'luts/warm.cube'});
      expect(plan.baked.keys.single, startsWith('curves:'));
    });

    test('a no-op stack collects nothing at all', () {
      final video = _video([
        Effect.curves(),
        Effect.lut(asset: 'luts/warm.cube', intensity: 0),
      ]);

      expect(collectShaderAssets(video.scenes), isEmpty);
      final plan = collectColorLookups(video.scenes);
      expect(plan.lutAssets, isEmpty);
      expect(plan.baked, isEmpty);
    });
  });

  group('painting through the shell', () {
    testWidgets('a lifted master curve changes the pixels', (tester) async {
      final bare = await _paint(tester, const []);
      final curved = await _paint(tester, [Effect.curves(master: _lift())]);

      expect(curved, isNot(bare));
    });

    testWidgets('a warming LUT changes the pixels', (tester) async {
      final bare = await _paint(tester, const []);
      final graded = await _paint(tester, [Effect.lut(asset: 'luts/warm.cube')]);

      expect(graded, isNot(bare));
    });

    testWidgets('intensity zero and identity curves are byte-exact no-ops', (tester) async {
      final bare = await _paint(tester, const []);

      expect(await _paint(tester, [Effect.lut(asset: 'luts/warm.cube', intensity: 0)]), bare);
      expect(await _paint(tester, [Effect.curves()]), bare);
      expect(await _paint(tester, [Effect.curves(master: _lift(), intensity: 0)]), bare);
    });
  });
}
