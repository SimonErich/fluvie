# Core concepts

Five ideas carry every Fluvie video: `Video`, `Scene`, `Time`, `.animate`,
and `Defaults`. Lesson 01 shows four of them in eighteen lines:

<!-- code-excerpt "examples/gallery/lib/lessons/01_hello_video.dart (video)" -->
```dart
Video lesson01Video() {
  return Video(
    size: VideoSize.square,
    poster: 1.seconds,
    scenes: [
      Scene(
        duration: 4.seconds,
        background: Background.gradient(const [Color(0xFF1A2980), Color(0xFF26D0CE)]),
        children: [
          const Text(
            'Hello, Fluvie',
            style: TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold),
          ).animate([Animation.fadeIn(), Animation.pop()]),
        ],
      ),
    ],
  );
}
```

## Video and Scene

A `Video` is a list of `Scene`s played back to back. The video owns the
canvas size and the frame rate; each scene owns its duration and its
children. Scene children sit on a centered, canvas-filling stack, so a bare
`Text` reads well without any layout code.

Size presets cover the common formats: `VideoSize.square`, `VideoSize.reels`
(and its alias `VideoSize.story`), `VideoSize.hd`, `VideoSize.fourK`.

## Time

You write times symbolically and Fluvie resolves them to frames:

- `4.seconds`, `300.ms`, `18.frames` are absolute.
- `0.3.relative` means 30 percent of the enclosing window (a scene, or an
  element's `.show` window).

The frame is the only clock. There is no wall time anywhere, which is why
renders are reproducible and cacheable.

## .animate

`.animate([...])` works on any widget and takes a list of presets such as
`Animation.fadeIn()`, `Animation.pop()`, `Animation.slideFade()`. Each preset
accepts `duration`, `delay`, `ease` or `spring`, a `Trigger`, and a
`Stagger` for multi-child targets. You declare the motion; placement happens
during resolution.

## Defaults

`Defaults` set shared timing once. The cascade is element over scene over
video over package, per field. Lesson 02 pins one duration for everything in
the scene:

<!-- code-excerpt "examples/gallery/lib/lessons/02_text_and_motion.dart (defaults)" -->
```dart
Scene(
  duration: 5.seconds,
  motionDefaults: const Defaults(duration: Time.frames(18)),
  background: Background.color(_ink),
  children: [
```

Every animation inside that scene now runs 18 frames unless it says
otherwise.

## The frame is the only clock

Capture is headless: there is no wall-clock and no async work inside a frame, so
a render is reproducible enough for golden tests, frame caching, and batch
rendering. Effects pull randomness from a seed, so the same seed repeats.

## Where to next

- [Layouts](../guides/layouts.md): plain Flutter layout plus `Box` and
  `Frame`.
- [Backgrounds and gradients](../guides/backgrounds-and-gradients.md): fills,
  textures, and `gradientShift`.
- [Timing and triggers](../guides/timing-and-triggers.md): anchors,
  `Trigger.whenEnds`, and `.show` windows.
- [Scenes and transitions](../guides/scenes-and-transitions.md): crossFade,
  wipe, overlap, shared elements, and the `Camera`.
