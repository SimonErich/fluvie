// The V1.3 acceptance: a composition authored with `Animation.shader` paints
// through the real capture shell, because the render pre-pass compiled its
// program first. Before the warm pass existed, every such composition threw
// "was not warmed before paint" at its first paint — no test caught it, because
// the only shader tests either injected a warm shader by hand or asserted the
// throw.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' show Color, ColoredBox, GlobalKey, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/runtime/warm_shader_scope.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/rendering/pre_load_shaders.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';

const _box = ColoredBox(color: Color(0xFF12243A));

Video _shaderVideo() => Video(
  scenes: [
    Scene(
      duration: const Time.frames(30),
      children: [
        const SizedBox(width: 96, height: 96, child: _box).animate(
          [
            Animation.shader(
              'shaders/ripple.frag',
              duration: const Time.frames(30),
              repeat: const Repeat.forever(),
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('a shader composition paints once the pre-pass warmed it', (tester) async {
    final video = _shaderVideo();
    late Map<String, ui.FragmentProgram> programs;
    await tester.runAsync(() async {
      programs = await preLoadCompositionShaders(composition: video);
    });
    expect(programs.keys, {'shaders/ripple.frag'});

    final shell = buildCaptureShell(
      composition: video,
      boundaryKey: GlobalKey(),
      controller: RenderController(),
      shaderPrograms: programs,
    );

    await tester.pumpWidget(shell.tree);
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason: 'the warm program reaches the painter, so nothing throws at paint',
    );
  });

  testWidgets('without the warm pass the painter still names the cold asset', (tester) async {
    // The guard is satisfied, never removed: a shader the pre-pass missed has
    // to fail loudly and by name rather than draw nothing.
    final shell = buildCaptureShell(
      composition: _shaderVideo(),
      boundaryKey: GlobalKey(),
      controller: RenderController(),
    );

    await tester.pumpWidget(shell.tree);
    await tester.pump();

    final error = tester.takeException();
    expect(error, isNotNull);
    expect('$error', contains('shaders/ripple.frag'));
  });

  testWidgets('two elements on one asset never share a shader instance', (tester) async {
    // A FragmentShader owns mutable uniform slots that paint rewrites every
    // frame, so one instance across two elements would let the second's
    // uniforms reach the first's draw.
    late ui.FragmentProgram program;
    await tester.runAsync(() async {
      program = await ui.FragmentProgram.fromAsset('shaders/ripple.frag');
    });

    expect(program.fragmentShader(), isNot(same(program.fragmentShader())));
  });

  test('the scope carries programs, so one asset serves many elements', () async {
    late ui.FragmentProgram program;
    await TestWidgetsFlutterBinding.ensureInitialized().runAsync(() async {
      program = await ui.FragmentProgram.fromAsset('shaders/ripple.frag');
    });

    final scope = WarmShaderScope(
      programs: {'shaders/ripple.frag': program},
      child: const SizedBox.shrink(),
    );

    expect(scope.programFor('shaders/ripple.frag'), same(program));
  });
}
