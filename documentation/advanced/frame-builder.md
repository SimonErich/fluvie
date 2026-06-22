# The FrameBuilder escape hatch

When no preset fits, drop to a builder with the raw frame clock and paint
anything. `FrameBuilder` hands you a `FrameContext` every frame, and your builder
returns the widget to render for that frame. Here a bar sweeps across its window:

<!-- code-excerpt "example/lib/snippets/phase_14_snippets.dart (frame-builder)" -->
```dart
Widget sweepingBar() => FrameBuilder((ctx) {
  final reach = ctx.progress; // 0..1 across this element's window
  return Align(
    alignment: Alignment(-1 + reach * 2, 0),
    child: const SizedBox(
      width: 24,
      height: 240,
      child: ColoredBox(color: Color(0xFF55EFC4)),
    ),
  );
});
```

`FrameBuilder` is `@experimental`: the escape-hatch surface may still change.
Reach for a preset or `.animate()` first. Drop to `FrameBuilder` when you need to
read the frame directly. The rest of this page covers the `FrameContext` and the
one rule that keeps a builder deterministic.

## The FrameContext

The `ctx` your builder receives reads the render state from the same scopes the
rest of Fluvie reads. The values:

- `ctx.frame` is the absolute video frame this build is for.
- `ctx.progress` is `0..1` across this element's resolved window.
- `ctx.fps` is the frames per second of the enclosing scope.
- `ctx.scope` is the enclosing time scope, with its start frame and length.
- `ctx.noise(seed)` is a seeded noise scalar in `0..1` for the seed.
- `ctx.audio(track)` is the analysed bass energy of a track, `0..1`.
- `ctx.audioBand(track, band)` is the analysed energy of one band.

`progress` is the value most builders want. It runs from 0 at the start of the
element's window to 1 at the end, so a builder reads as an animation without a
curve or a tween.

## Reading noise and audio

`ctx.noise` and `ctx.audio` give you the same seeded randomness and the same
analysed audio that the effects read. Both are precomputed before the frame loop,
so a builder that reads them stays a pure function of the frame:

<!-- code-excerpt "example/lib/snippets/phase_14_snippets.dart (frame-builder-audio)" -->
```dart
Widget pulsingChip(Anchor music) => FrameBuilder((ctx) {
  final wobble = ctx.noise('chip-${ctx.frame ~/ 6}') * 0.1; // seeded, reproducible
  final beat = ctx.audio(music); // analysed bass energy, 0..1
  return Transform.scale(
    scale: 1 + beat * 0.4 + wobble,
    child: const SizedBox(
      width: 120,
      height: 120,
      child: ColoredBox(color: Color(0xFF7C5CFF)),
    ),
  );
});
```

`ctx.audio(track)` returns the bass band. For the mid or treble band, call
`ctx.audioBand(track, AudioBand.mid)` or `AudioBand.treble`. Pass `null` for the
track to read the master mix. The energy comes from the per-frame band table the
render shell analyses before frame 0, so it is a pure lookup at frame time.

In capture without a precomputed reactive scope, `ctx.audio` and `ctx.audioBand`
throw and name the band and the precompute pass, because reading live audio in a
frame would break determinism. In a live preview they return `0`, so a builder
still runs while you iterate.

## The one rule

A `FrameBuilder` must be a pure function of its `FrameContext`. Read the frame,
the progress, the seeded noise, and the analysed audio. Do not read the
wall-clock, do not call `Random()`, and do not start async work inside the
builder.

This is the same rule every effect follows, and it is what keeps a builder as
cacheable and golden-stable as a preset. The frame is the only clock. Noise and
audio are precomputed, never live. Given the same frame and the same scopes, your
builder returns the same widget and paints the same pixels every time. Break the
rule and the frame cache and the goldens stop agreeing.

## Where to next

- [Shaders and effects](shaders-and-effects.md): write a custom effect when you
  want a post-process over the rendered child rather than a new widget.
- [Audio and captions](../guides/audio-and-captions.md): the analysed band table
  `ctx.audio` reads, computed once before frame 0.
