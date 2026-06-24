# Backgrounds and gradients

A `Background` fills the whole scene behind your content. Pass it to
`Scene(background: ...)` or mount it as a plain child; both paint the same
pixels. Lesson 03 animates one with `gradientShift`:

<!-- code-excerpt "examples/gallery/lib/lessons/03_timing_and_triggers.dart (gradient-anchor)" -->
```dart
Background.gradient(const [Color(0xFFE74C3C), Color(0xFF27AE60)]).animate([
  Animation.gradientShift(
    to: const [Color(0xFF2980B9), Color(0xFF27AE60)],
    duration: 0.3.relative, // 30% of the 10 s scene
    delay: 0.1.relative, // begins 1 s in
  ),
], anchor: bg),
```

## The factories

| Constructor | What it paints |
| --- | --- |
| `Background.color(color)` | one solid fill |
| `Background.gradient(colors, begin:, end:)` | linear gradient, top left to bottom right by default |
| `Background.radial(colors)` | radial gradient from the center |
| `Background.noise(scale: 1)` | deterministic seeded noise texture |
| `Background.vhs()` | scanline and band texture |
| `Background.image(source, fit:)` | an image fill |
| `Background.video(source)` | a video fill |

`image` and `video` resolve their source through the media pipeline before
capture, so a frame never blocks on IO. A source that cannot be resolved throws
a clear error naming it, so a typo never fails silently.

## gradientShift

`Animation.gradientShift(to: [...])` lerps each base color to its
counterpart in `to`, pairwise. The two lists must have the same length.
Before the animation starts you see the base colors; after it settles you
keep the shifted ones. Timing composes like any other preset: the lesson
above uses a relative delay and duration, so the shift spans 1 s to 4 s of
its 10 s scene.

## Animating a solid fill

`Animation.color(to: ...)` works on `Background.color` the same way: the
background paints the animated color for as long as the animation defines
one.

## Where to next

- [Timing and triggers](timing-and-triggers.md): the anchor on that gradient
  is the start of a chain.
- [Layouts](layouts.md): what sits in front of the background.
