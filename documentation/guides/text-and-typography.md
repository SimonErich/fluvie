# Text and typography

Text in Fluvie is plain Flutter `Text`. You style it the Flutter way and add
motion with `.animate()`. There is no special text widget to learn:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_08_snippets.dart (text-animate)" -->
```dart
Widget animatedTitle() => const Text(
  'Made with Fluvie',
  style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
).animate([Animation.slideFade(), Animation.fadeIn()]);
```

That title slides up and fades in together. Everything you know about Flutter
text styling, `TextStyle`, `DefaultTextStyle`, rich text, applies unchanged.
The motion is one list, and Fluvie computes when each frame happens.

## Two text elements that animate themselves

Some text effects are about the content, not the box. Fluvie ships two
elements whose behaviour is driven by the frame, so you never write a tween.

### Typewriter

`Typewriter` reveals a string one glyph at a time. You set the speed in frames
per glyph and, if you want, a blinking caret:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_08_snippets.dart (typewriter)" -->
```dart
Widget typedHeadline() => const Typewriter(
  'Typed out one glyph at a time.',
  speed: Time.frames(3),
  caret: true,
).animate([Animation.fadeIn()]);
```

The visible glyph count is `floor(elapsed / speed)`, clamped to the string
length. A glyph appears only when its whole reveal time has passed, so the
reveal lands on the same frames every render. The caret blinks on a frame-pinned
period, so it lands on the same frames too. Layout and entry motion still come
through `.animate()`; the constructor only takes content.

### Counter

`Counter` tweens a number from one value to another and formats it with `intl`'s
`NumberFormat`. Use it for stats, prices, and percentages:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_08_snippets.dart (counter)" -->
```dart
Widget viewsCounter() =>
    Counter(to: 12500, duration: 2.seconds, format: NumberFormat.compact()); // "12.5K"
```

The displayed value is `lerp(from, to, ease(progress))` over the resolved
duration. The default ease is linear, the motion a counter wants. Two presets
cover the common formats:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_08_snippets.dart (counter-presets)" -->
```dart
Widget priceTag() => Counter.currency(to: 4999); // "$4,999"
Widget shareOfVoice() => Counter.percent(to: 0.87); // "87%"
```

Both presets pin a fixed locale, so the grouping and the symbol placement are
the same on every machine. The frame is the only clock, so two renders of the
same counter produce the same frames.

## Frame-driven by design

`Typewriter` and `Counter` read the current frame and their enclosing time
scope, and nothing else: no animation controller, no wall-clock. That is why
their output is reproducible: same input, same frames, every time.

## Where to next

- [Timing and triggers](timing-and-triggers.md): the `.animate()` list,
  triggers, and `.show` windows the text above uses.
- [Images and video clips](images-and-video-clips.md): the other media
  elements and how Fluvie pre-resolves them.
- [Cheatsheet](../reference/cheatsheet.md): the whole shipped surface on one
  page.
