// Epic 7.3 acceptance goldens (concept 7.3): a Box "logo" SharedElement
// morphs across a crossFade boundary — centred-large in scene 1, small
// top-left in scene 2. Captured mid-window (p = 0.5, the hero between both
// rects at full opacity while the scenes blend beneath) and at the last
// blend frame (≈ the target rect). Contrasting scene fills make the blend
// beneath the morph visible; everything stays font-free (D20).
//
// Two 2s scenes at 30 fps with a 15-frame overlapping crossFade: starts
// [0, 45], blend window [45, 60). Mid samples frame 52 (p = 0.5 exactly,
// (52 - 45 + 1) / 15 = 8/15 ≈ 0.53 eased linearly — the documented mid frame
// blendStart + (t - 1) ~/ 2 = 45 + 7); end samples frame 59 (p ≈ 1).
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/box.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';

const _logoColor = Color(0xFFF1C40F); // a bright logo against both scenes
const _scene1 = Color(0xFF2C3E50);
const _scene2 = Color(0xFF8E44AD);

/// The hero composition: a Box logo shared across the crossFade boundary,
/// large and centred in scene 1, small and top-left in scene 2.
Video _heroVideo() {
  final logo = Anchor('logo');
  return Video(
    width: 160,
    height: 284,
    transition: Transition.crossFade(15.frames),
    scenes: [
      Scene(
        duration: 2.seconds,
        background: Background.color(_scene1),
        children: [
          Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: SharedElement(
                anchor: logo,
                child: const Box(color: _logoColor),
              ),
            ),
          ),
        ],
      ),
      Scene(
        duration: 2.seconds,
        background: Background.color(_scene2),
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 32,
                height: 32,
                child: SharedElement(
                  anchor: logo,
                  child: const Box(color: _logoColor),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

GoldenTestGroup _group(String name, int frame) => GoldenTestGroup(
  children: [
    GoldenTestScenario(
      name: name,
      child: SizedBox(
        width: 160,
        height: 284,
        child: RenderControllerScope(
          controller: RenderController(initialFrame: frame),
          child: _heroVideo(),
        ),
      ),
    ),
  ],
);

Future<void> main() async {
  await goldenTest(
    'hero morph at the window midpoint: the logo between both rects, full opacity',
    fileName: 'hero_morph_mid',
    builder: () => _group('frame 52 (mid-window)', 52),
  );

  await goldenTest(
    'hero morph at the last blend frame: the logo near its target rect',
    fileName: 'hero_morph_end',
    builder: () => _group('frame 59 (last blend)', 59),
  );
}
