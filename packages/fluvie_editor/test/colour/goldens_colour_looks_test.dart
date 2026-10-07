@Tags(['golden'])
library;

import 'dart:ui' as ui;
import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_editor/src/colour/colour_looks.dart';

final ValueNotifier<bool> ready = ValueNotifier(false);
final programs = <String, ui.FragmentProgram>{};
final lookups = <String, ui.Image>{};
Widget subject(List<Map<String, Object?>> effects) => Video(
  width: 120,
  height: 100,
  scenes: [
    Scene(
      duration: const Time.frames(30),
      children: [
        const Center(
          child: SizedBox(
            width: 100,
            height: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4666CC), Color(0xFFB98763), Color(0xFF54AE65)],
                ),
              ),
            ),
          ),
        ).effects([for (final effect in effects) Effect.spec(EffectSpec.fromJson(effect))]),
      ],
    ),
  ],
);

Future<void> main() async {
  await goldenTest(
    'each shipped look at full and 60 percent intensity',
    fileName: 'colour_looks',
    pumpBeforeTest: (tester) async {
      await tester.runAsync(() async {
        final composition = subject(colourLooks.last.at(1));
        programs.addAll(await preLoadCompositionShaders(composition: composition));
        lookups.addAll(await preBakeCompositionColorLookups(composition: composition));
      });
      ready.value = true;
      await tester.pump();
    },
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        for (final look in colourLooks)
          for (final intensity in [1.0, 0.6])
            GoldenTestScenario(
              name: '${look.name} $intensity',
              child: SizedBox(
                width: 120,
                height: 100,
                child: ValueListenableBuilder<bool>(
                  valueListenable: ready,
                  builder: (context, value, _) => value
                      ? WarmShaderScope(
                          programs: programs,
                          child: ColorLookupScope(
                            lookups: lookups,
                            child: RenderControllerScope(
                              controller: RenderController(initialFrame: 15),
                              child: subject(look.at(intensity)),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
      ],
    ),
  );
}
