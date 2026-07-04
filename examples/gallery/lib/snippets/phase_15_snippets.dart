// Compiled, tested snippets for the animating-elements and performance docs.
// They live here, not hand-typed in Markdown, so the
// documentation never drifts from a real API. Each `#docregion` flows into one
// fence via a `<!-- code-excerpt -->` marker.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

const _title = TextStyle(color: Color(0xFFE6EDF3), fontSize: 64, fontWeight: FontWeight.bold);
const _line = TextStyle(color: Color(0xFFE6EDF3), fontSize: 40);

/// One element, one `.animate([...])` list: a fade and a pop play together
/// when the element's window starts. You never type a frame number.
Widget animateBasics() =>
    // #docregion animate-basics
    const Text('Hello', style: _title).animate([
      Animation.fadeIn(),
      Animation.pop(),
    ]);
// #enddocregion animate-basics

/// The enter, exit, and ambient presets you reach for most. Each is one entry
/// in the list; compose as many as you like on one element.
List<Animation> presetMenu() => [
  // #docregion preset-menu
  Animation.fadeIn(), // opacity 0 to natural
  Animation.slideFadeIn(from: Edge.left), // rise in while fading
  Animation.pop(overshoot: 1.2), // springy scale, peaks at 120%
  Animation.scaleIn(from: 0.7), // settle up from 70%
  Animation.blurIn(sigma: 16), // sharpen from a 16 px blur
  Animation.float(amplitude: 0.05), // bob forever, ambient
  // #enddocregion preset-menu
];

/// Compose enter and exit on one element. The fade and slide play at the start
/// of the window, the fade out at its end. The phase is inferred per preset.
Widget composeEnterExit() =>
    // #docregion compose-enter-exit
    const Text('In and out', style: _line).animate([
      Animation.slideFadeIn(),
      Animation.fadeOut(),
    ]);
// #enddocregion compose-enter-exit

/// Shape an animation with the common tail: a `duration`, an `ease`, and a
/// `delay`. Leave them unset to inherit the `Defaults` cascade.
Widget shapeTiming() =>
    // #docregion shape-timing
    const Text('Late and slow', style: _line).animate([
      Animation.fadeIn(
        duration: const Time.seconds(0.6), // run for 600 ms
        ease: Ease.out, // decelerate into place
        delay: const Time.seconds(0.2), // start 200 ms after the trigger
      ),
    ]);
// #enddocregion shape-timing

/// A spring replaces `duration`/`ease`. Its settle time becomes the
/// animation's span, so chaining stays exact.
Widget springTiming() =>
    // #docregion spring-timing
    const Text('Bouncy', style: _line).animate([
      Animation.scaleIn(spring: Spring.bouncy),
    ]);
// #enddocregion spring-timing

/// Start an animation off a `Trigger`. `after` waits for an anchored
/// element to finish; `previous` chains off the entry just above it.
Widget triggerVocabulary(Anchor intro) =>
    // #docregion trigger-after
    const Text('Then me', style: _line).animate([
      Animation.slideFadeIn(at: Trigger.whenEnds(intro)),
    ]);
// #enddocregion trigger-after

/// Stagger one animation across a multi-child target. Each child plays the
/// same animation, offset by the gap.
Widget staggerChildren() =>
    // #docregion stagger
    const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('One', style: _line),
        Text('Two', style: _line),
        Text('Three', style: _line),
      ],
    ).animate([
      Animation.slideFadeIn(stagger: const Stagger.each(Time.frames(8))),
    ]);
// #enddocregion stagger

/// Loop an animation inside its span with `repeat`. `forever` runs until the
/// window ends; `times` plays a fixed count.
List<Animation> repeatMenu() => [
  // #docregion repeat
  Animation.pulse(repeat: const Repeat.forever(yoyo: true)), // breathe back and forth
  Animation.spin(repeat: const Repeat.times(2)), // two turns, then hold
  // #enddocregion repeat
];

/// Set the animation defaults once on a `Scene`. Every animation inside
/// inherits the duration and ease unless it overrides them.
Scene sceneDefaults() =>
    // #docregion scene-defaults
    Scene(
      duration: const Time.seconds(5),
      motionDefaults: const Defaults(duration: Time.frames(18), ease: Ease.smooth),
      children: [
        const Text('Inherits 18 frames', style: _line).animate([Animation.fadeIn()]),
      ],
    );
// #enddocregion scene-defaults

/// Build motion the presets do not cover with `Animation.from`/`to` and a
/// `Keyframe`. Offsets are fractions of the element's own size.
Widget customKeyframe() =>
    // #docregion custom-keyframe
    const Text('From the side', style: _line).animate([
      Animation.from(const Keyframe(opacity: 0, x: -0.5, scale: 0.9)),
    ]);
// #enddocregion custom-keyframe

/// Reuse one media declaration so it resolves and caches once. The same
/// `Image` on two scenes shares a single decode (performance page).
List<Widget> reuseMedia(String url) {
  final logo = Image.network(url, fit: BoxFit.contain);
  return [
    // #docregion reuse-media
    logo, // scene one: one decode
    logo, // scene two: a cache hit on the same bytes
    // #enddocregion reuse-media
  ];
}

/// Hoist the animation list to a stable instance when the element lives inside
/// a per-frame `Builder`. A fresh list literal each frame re-registers a new
/// token and throws (performance page, lesson 12).
final List<Animation> _stablePop = [Animation.pop()];

/// The element binds the same `List<Animation>` on every rebuild.
Widget stableAnimationList() =>
    // #docregion stable-list
    Builder(
      builder: (context) => const Text('Stable', style: _line).animate(_stablePop),
    );
// #enddocregion stable-list
