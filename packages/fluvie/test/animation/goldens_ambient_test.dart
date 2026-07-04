// Epic 5.3 acceptance goldens: the ambient (`during`) presets at three
// phases of one cycle, pinning the D18 micro-defaults (cycle lengths derived
// from each preset's period at 30 fps; one-pass presets use the window as
// their cycle). Subjects stay font-free; spin and kenBurns carry a corner
// marker so direction is visible (D20).
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';

import 'helpers/golden_frame.dart';

const _purple = Color(0xFF6C5CE7);
const _teal = Color(0xFF00B894);

Widget _square() => const SizedBox(width: 48, height: 48, child: ColoredBox(color: _purple));

/// A square with a teal top-left corner so rotation and pan read clearly.
Widget _markedSquare() => const SizedBox(
  width: 48,
  height: 48,
  child: ColoredBox(
    color: _purple,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 16, height: 16, child: ColoredBox(color: _teal)),
    ),
  ),
);

Widget _animated(Widget subject, Animation animation) =>
    Center(child: subject.animate([animation]));

Future<void> main() async {
  // float: 1/0.4 s = 75 frames per cycle at 30 fps; the sine peaks up at
  // 25% (frame ~19) and down at 75% (frame ~56) of the cycle.
  await goldenMotionFrames(
    description: 'float: natural, up-peak, down-peak across one 75-frame cycle',
    fileName: 'animation_float',
    frames: const [0, 19, 56],
    sceneFrames: 80,
    subject: () => _animated(_square(), Animation.float()),
  );

  // float(seed:): the same 75-frame bob carrying a low-amplitude, reproducible
  // noise wobble (D9/§22). The three frames show the organic offset is not the
  // bare sine and renders deterministically for the fixed seed 'leaf-7'.
  await goldenMotionFrames(
    description: 'float seeded: organic deterministic wobble at frames 0, 19, 56',
    fileName: 'animation_float_seeded',
    frames: const [0, 19, 56],
    sceneFrames: 80,
    subject: () => _animated(_square(), Animation.float(seed: 'leaf-7')),
  );

  // pulse: 1.2 s period = 36 frames; the half-period tween is 18 frames, so
  // 0/9/18 run min → mid → max and 27 is the yoyo return passing mid again.
  await goldenMotionFrames(
    description: 'pulse: scale 0.97 → 1.0 → 1.03 → yoyo back through 1.0',
    fileName: 'animation_pulse',
    frames: const [0, 9, 18, 27],
    subject: () => _animated(_square(), Animation.pulse()),
  );

  // drift: one linear pass across the 60-frame window (no repeat, D18).
  await goldenMotionFrames(
    description: 'drift: slides 0.1 element-widths right across the window',
    fileName: 'animation_drift',
    frames: const [0, 30, 59],
    subject: () => _animated(_square(), Animation.drift()),
  );

  // spin: 4 s per turn = 120 frames; thirds of one revolution.
  await goldenMotionFrames(
    description: 'spin: 0, 1/3, and 2/3 of a turn across one 120-frame cycle',
    fileName: 'animation_spin',
    frames: const [0, 40, 80],
    sceneFrames: 120,
    subject: () => _animated(_markedSquare(), Animation.spin()),
  );

  // kenBurns: one linear pass to scale 1.15 panning toward the left edge.
  await goldenMotionFrames(
    description: 'kenBurns: zooms to 1.15 while panning toward the left edge',
    fileName: 'animation_ken_burns',
    frames: const [0, 30, 59],
    subject: () => _animated(_markedSquare(), Animation.kenBurns()),
  );
}
