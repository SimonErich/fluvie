import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/render/composition_entry.dart';

/// Scene 1's solid backdrop — asserted byte-exact at the pixel level by the
/// determinism test, so keep it an opaque integer color.
const Color multiSceneScene1Color = Color(0xFFB03A2E);

/// Scene 3's solid backdrop, asserted like [multiSceneScene1Color].
const Color multiSceneScene3Color = Color(0xFF101020);

const Color _blue = Color(0xFF2E5CB0);
const Color _green = Color(0xFF2ECC71);
const Color _amber = Color(0xFFF0B429);
const Color _white = Color(0xFFFFFFFF);

/// A multi-scene composition: 320x240 @ 30 fps, three scenes and
/// 84 frames (24 + 36 + 24), exercising the whole composition pipeline —
/// scene gating, the build-time registrar, a cross-element trigger, and a
/// staggered multi-child container.
final multiSceneComposition = CompositionEntry(
  key: 'multi_scene',
  width: 320,
  height: 240,
  fps: 30,
  frameCount: 84,
  // The harness mounts no WidgetsApp, so the composition carries its own
  // text direction for the scene 2 Text.
  build: () => Directionality(textDirection: TextDirection.ltr, child: multiSceneVideo()),
);

/// The `multi_scene` [Video]: a solid color card, then a gradient that
/// shifts under an [Anchor] with an `after`-gated title, then three boxes
/// sliding in on a stagger.
Video multiSceneVideo() {
  final bg = Anchor('bg');
  return Video(
    width: 320,
    height: 240,
    scenes: [
      // Scene 1, frames 0..24: nothing but the solid backdrop — the pixel
      // anchor for the gating proof.
      Scene(duration: 24.frames, background: Background.color(multiSceneScene1Color)),
      // Scene 2, frames 24..60: the gradient shifts 6 frames in (30..42) and
      // the title slide-fades only after the shift settles (42..54).
      Scene(
        duration: 36.frames,
        children: [
          Background.gradient(const [_blue, _green]).animate([
            Animation.gradientShift(
              to: const [_amber, _green],
              delay: const Time.frames(6),
              duration: const Time.frames(12),
              ease: Ease.linear,
            ),
          ], anchor: bg),
          const Text(
            'multi-scene',
            style: TextStyle(color: _white, fontSize: 24),
          ).animate([
            Animation.slideFadeIn(at: Trigger.whenEnds(bg), duration: const Time.frames(12)),
          ]),
        ],
      ),
      // Scene 3, frames 60..84: three boxes stagger in over the ink backdrop
      // (spans 60..68 / 64..72 / 68..76, all settled before the end).
      Scene(
        duration: 24.frames,
        background: Background.color(multiSceneScene3Color),
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              for (final color in const [_blue, _green, _amber])
                SizedBox(width: 48, height: 48, child: Box(color: color)),
            ],
          ).animate([
            Animation.slideFadeIn(
              duration: const Time.frames(8),
              ease: Ease.linear,
              stagger: const Stagger.each(Time.frames(4)),
            ),
          ]),
        ],
      ),
    ],
  );
}
