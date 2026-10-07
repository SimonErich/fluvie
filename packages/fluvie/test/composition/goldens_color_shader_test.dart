// The two shader-path colour effects on the Linux baseline: a crushed
// curve and a warming LUT, each at full and at partial intensity beside the
// ungraded frame. GPU caveat (stated once in the phase and honoured here):
// software rasterizers vary, the bar is "it looks right" on this baseline,
// not byte identity across machines. Subjects stay font-free (D20).
@Tags(['golden'])
library;

import 'dart:ui' as ui;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

/// A 2-point warming cube: reds lifted, blues cut.
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

final ValueNotifier<bool> _ready = ValueNotifier(false);
final Map<String, ui.FragmentProgram> _programs = {};
final Map<String, ui.Image> _lookups = {};

ToneCurve _crush() => ToneCurve.fromPoints(const [(0, 0), (0.5, 0.2), (1, 1)]);

Widget _subject(List<EffectLayer> effects) => Video(
  width: 110,
  height: 110,
  scenes: [
    Scene(
      duration: const Time.frames(30),
      children: [
        Placed(
          placement: const Placement(x: 0.5, y: 0.5, width: 0.8, height: 0.8),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4C6EF5), Color(0xFFF59F00), Color(0xFF2F9E44)],
              ),
            ),
          ).effects(effects),
        ),
      ],
    ),
  ],
);

GoldenTestScenario _cell(String name, List<EffectLayer> effects) => GoldenTestScenario(
  name: name,
  child: SizedBox(
    width: 110,
    height: 110,
    child: ValueListenableBuilder<bool>(
      valueListenable: _ready,
      builder: (context, ready, _) {
        if (!ready) return const SizedBox.shrink();
        return WarmShaderScope(
          programs: _programs,
          child: ColorLookupScope(
            lookups: _lookups,
            child: RenderControllerScope(
              controller: RenderController(initialFrame: 15),
              child: _subject(effects),
            ),
          ),
        );
      },
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'curves and LUTs grade the frame on the shader path',
    fileName: 'color_shader',
    pumpBeforeTest: (tester) async {
      await tester.runAsync(() async {
        final warm = _subject([
          Effect.curves(master: _crush()),
          Effect.lut(asset: 'luts/warm.cube'),
        ]);
        _programs.addAll(await preLoadCompositionShaders(composition: warm));
        _lookups.addAll(
          await preBakeCompositionColorLookups(
            composition: warm,
            loadCubeText: (_) async => _warmCube,
          ),
        );
      });
      _ready.value = true;
      await tester.pump();
    },
    builder: () => GoldenTestGroup(
      columns: 3,
      children: [
        _cell('bare', const []),
        _cell('grade identity: bare', [Effect.grade()]),
        _cell('grade zero: bare', [Effect.grade(exposure: 2, intensity: 0)]),
        _cell('curves crushed', [Effect.curves(master: _crush())]),
        _cell('curves 60%', [Effect.curves(master: _crush(), intensity: 0.6)]),
        _cell('lut warm', [Effect.lut(asset: 'luts/warm.cube')]),
        _cell('lut 60%', [Effect.lut(asset: 'luts/warm.cube', intensity: 0.6)]),
        _cell('lut zero: bare', [Effect.lut(asset: 'luts/warm.cube', intensity: 0)]),
        _cell('curves zero: bare', [Effect.curves(master: _crush(), intensity: 0)]),
        _cell('curves identity: bare', [Effect.curves()]),
      ],
    ),
  );
}
