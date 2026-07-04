// Epic 9.4 acceptance golden (WI-21): the bundled ripple fragment shader
// painted over a font-free ColoredBox at a fixed frame. The WI-18 spike proved
// FragmentProgram renders headless under FlutterTester, so this runs in the
// normal `golden` suite (decision D11, path a) — no `shader` tag needed.
@Tags(['golden'])
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effects/shader_effect.dart';
import 'package:fluvie/src/animation/runtime/shader_loader.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/repeat.dart';

import 'helpers/golden_frame.dart';

const _navy = Color(0xFF12243A);

/// The bundled ripple painted at full strength across the window, held so the
/// overlay reads the same every frame (a `during` custom animation never
/// fades). The warm [shader] is the pre-loaded program the render shell would
/// hand in before frame 0.
Widget _rippleSubject(ui.FragmentShader shader) {
  final effect = ShaderEffect(shaderName: 'shaders/ripple.frag', shader: shader);
  return Center(
    child: const SizedBox(width: 96, height: 96, child: ColoredBox(color: _navy)).animate([
      Animation.custom(effect, phase: AnimationPhase.during, repeat: const Repeat.forever()),
    ]),
  );
}

Future<void> main() async {
  late ui.FragmentShader shader;
  setUpAll(() async {
    await TestWidgetsFlutterBinding.ensureInitialized().runAsync(() async {
      shader = await const FragmentProgramShaderLoader().load('shaders/ripple.frag');
    });
  });

  await goldenMotionFrames(
    description: 'shader: the bundled ripple painted over a navy square, mid-window',
    fileName: 'shader_ripple_mid',
    frames: const [30],
    subject: () => _rippleSubject(shader),
  );
}
