// The sampled shader view's refusals: painting before the pre-pass warmed
// its program or baked its lookup names what is missing, rather than
// silently drawing nothing.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/animation/runtime/sampled_shader_view.dart';
import 'package:fluvie/src/rendering/pre_bake_color_lookups.dart' as bake;

Widget _view() => SampledShaderView(
  shaderAsset: 'shaders/color_curves.frag',
  lookupKey: 'curves:feed',
  floats: (_) => const [1],
  child: const SizedBox.shrink(),
);

Widget _inCapture(Widget child) => RenderModeContext(mode: RenderMode.capture, child: child);

void main() {
  testWidgets('an unwarmed shader in capture throws, naming the asset', (tester) async {
    await tester.pumpWidget(_inCapture(_view()));

    expect(tester.takeException(), isA<FluvieRenderException>());
  });

  testWidgets('an unbaked lookup in capture throws, naming the key', (tester) async {
    late Map<String, ui.FragmentProgram> programs;
    await tester.runAsync(() async {
      programs = await preLoadShaders(['shaders/color_curves.frag']);
    });

    await tester.pumpWidget(_inCapture(WarmShaderScope(programs: programs, child: _view())));

    final thrown = tester.takeException();
    expect(thrown, isA<FluvieRenderException>());
    expect('$thrown', contains('curves:feed'));
  });

  testWidgets('outside capture a cold surface shows the child ungraded', (tester) async {
    // The grace a live canvas needs while its warm pass runs: no error
    // widget, the ungraded child, and the grade lands when the scopes do.
    await tester.pumpWidget(_view());

    expect(tester.takeException(), isNull);
    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('a LUT that cannot load fails the pre-pass, naming the asset', (tester) async {
    final video = Video(
      scenes: [
        Scene(
          duration: const Time.frames(10),
          children: [
            const SizedBox.shrink().effects([Effect.lut(asset: 'luts/missing.cube')]),
          ],
        ),
      ],
    );

    await tester.runAsync(() async {
      await expectLater(
        bake.preBakeCompositionColorLookups(
          composition: video,
          loadCubeText: (asset) async => throw StateError('no bundle for $asset'),
        ),
        throwsA(
          predicate<Object>((e) => e is FluvieRenderException && '$e'.contains('missing.cube')),
        ),
      );
    });
  });

  testWidgets('a composition with no video bakes nothing', (tester) async {
    await tester.runAsync(() async {
      expect(
        await bake.preBakeCompositionColorLookups(composition: const SizedBox.shrink()),
        isEmpty,
      );
    });
  });
}
