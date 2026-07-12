# Animating elements

Motion is one list. Attach `.animate([...])` to any widget and put each motion
in the list. Fluvie works out when each one plays:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (animate-basics)" -->
```dart
const Text('Hello', style: _title).animate([
  Animation.fadeIn(),
  Animation.pop(),
]);
```

The fade and the pop both start when the element's window opens. You never type
a frame number. This page covers the presets, how to compose them, how to time
them, and how triggers and stagger work.

## The preset menu

Reach for a preset first. Each is one entry in the list:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (preset-menu)" -->
```dart
Animation.fadeIn(), // opacity 0 to natural
Animation.slideFadeIn(from: Edge.left), // rise in while fading
Animation.pop(overshoot: 1.2), // springy scale, peaks at 120%
Animation.scaleIn(from: 0.7), // settle up from 70%
Animation.blurIn(sigma: 16), // sharpen from a 16 px blur
Animation.float(amplitude: 0.05), // bob forever, ambient
```

The presets fall into three groups:

- **Enter** plays at the start of the window: `fadeIn`, `slideIn`, `slideFadeIn`,
  `pop`, `scaleIn`, `blurIn`, `maskWipeIn`.
- **Exit** plays at the end of the window: `fadeOut`, `slideOut`, `slideFadeOut`,
  `scaleOut`, `blurOut`, `maskWipeOut`, `color`.
- **Ambient** plays the whole window, on a loop: `float`, `pulse`, `drift`,
  `spin`, `kenBurns`.

There are pixel post-effects too (`grain`, `vignette`, `particles`, and more).
They sit in the same list. See [Shaders and effects](../advanced/shaders-and-effects.md).

## Compose enter and exit

Put an enter and an exit on the same element. Each preset knows its phase, so
you do not say when:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (compose-enter-exit)" -->
```dart
const Text('In and out', style: _line).animate([
  Animation.slideFadeIn(),
  Animation.fadeOut(),
]);
```

The slide-fade plays at the start of the window. The fade-out plays at its end.
List order does not set timing here; the phase does.

## Shape the timing

Every preset takes the same tail of timing arguments. Set a `duration`, an
`ease`, and a `delay`:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (shape-timing)" -->
```dart
const Text('Late and slow', style: _line).animate([
  Animation.fadeIn(
    duration: const Time.seconds(0.6), // run for 600 ms
    ease: Ease.out, // decelerate into place
    delay: const Time.seconds(0.2), // start 200 ms after the trigger
  ),
]);
```

Leave them unset and the animation inherits the `Defaults` cascade. See
[Defaults below](#defaults-set-the-feel-once).

Pass a `spring` instead of a `duration` and `ease`, and the spring wins. Its
settle time becomes the animation's span:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (spring-timing)" -->
```dart
const Text('Bouncy', style: _line).animate([
  Animation.scaleIn(spring: Spring.bouncy),
]);
```

The springs are `Spring.gentle`, `Spring.snappy`, `Spring.bouncy`, and
`Spring.stiff`, or build your own with `Spring(stiffness:, damping:)`.

## Trigger one animation off another

By default an animation plays at its phase. A `Trigger` changes the start. Use
`Trigger.whenEnds` to wait for an anchored element to finish:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (trigger-after)" -->
```dart
const Text('Then me', style: _line).animate([
  Animation.slideFadeIn(at: Trigger.whenEnds(intro)),
]);
```

`intro` is an `Anchor` you put on another element with `.animate(..., anchor:)`.
Move the anchored timing and this one follows. The full trigger vocabulary,
including `whenStarts`, `previous`, `sceneStart`, and `beat`, lives in
[Timing and triggers](timing-and-triggers.md).

## Stagger a group

One animation can play across a group of children, offset child by child. Put
the `stagger` on the container's animation:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (stagger)" -->
```dart
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
```

`Stagger.each(gap)` offsets each child by a fixed gap. `Stagger.evenly(over:)`
spreads the children across one span whatever their count. `Stagger.from(origin)`
starts the wave from the center or an edge.

## Repeat a loop

Loop an animation inside its span with `repeat`:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (repeat)" -->
```dart
Animation.pulse(repeat: const Repeat.forever(yoyo: true)), // breathe back and forth
Animation.spin(repeat: const Repeat.times(2)), // two turns, then hold
```

`Repeat.forever()` loops until the window ends. `Repeat.times(n)` plays `n`
cycles, then holds. `yoyo: true` plays every other cycle in reverse.

## Defaults set the feel once

Set the duration and ease once on a `Scene`. Every animation inside inherits
them unless it overrides:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (scene-defaults)" -->
```dart
Scene(
  duration: const Time.seconds(5),
  motionDefaults: const Defaults(duration: Time.frames(18), ease: Ease.smooth),
  children: [
    const Text('Inherits 18 frames', style: _line).animate([Animation.fadeIn()]),
  ],
);
```

Defaults cascade: animation over `Scene` over `Video` over the package. Each
field falls through on its own, so a scene can pin the ease while the duration
comes from the video.

## Build your own

When no preset fits, animate from a `Keyframe`. `Animation.from` enters from
it; `Animation.to` exits to it. Offsets are fractions of the element's own size:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (custom-keyframe)" -->
```dart
const Text('From the side', style: _line).animate([
  Animation.from(const Keyframe(opacity: 0, x: -0.5, scale: 0.9)),
]);
```

For multi-stop motion use `Animation.keyframes([...])`, for a path use
`Animation.along(path)`, and for a fully custom effect use `Animation.custom`.
When no animation form fits at all, drive the pixels per frame with the
[FrameBuilder escape hatch](../advanced/frame-builder.md).

## Keep the list stable

The resolver must see the same animations on every frame. Inside a per-frame
`Builder`, hoist the list to a field rather than writing a fresh literal each
build. See [Performance](../advanced/performance.md#keep-animation-lists-stable).

## Where to next

- [Timing and triggers](timing-and-triggers.md): the full trigger vocabulary
  and `.show` windows.
- [Shaders and effects](../advanced/shaders-and-effects.md): grain, particles,
  parallax, and fragment shaders in the same animate list.
- [Cheatsheet](../reference/cheatsheet.md): every preset on one page.
