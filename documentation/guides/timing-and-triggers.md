# Timing and triggers

This guide is a draft; it grows with each phase.

Nobody computes a frame number. You name moments and react to them. Lesson
03 shows the whole vocabulary in one scene. First, name a timeline by giving
an animation an `Anchor`:

<!-- code-excerpt "example/lib/lessons/03_timing_and_triggers.dart (gradient-anchor)" -->
```dart
Background.gradient(const [Color(0xFFE74C3C), Color(0xFF27AE60)]).animate([
  Animation.gradientShift(
    to: const [Color(0xFF2980B9), Color(0xFF27AE60)],
    duration: 0.3.relative, // 30% of the 10 s scene
    delay: 0.1.relative, // begins 1 s in
  ),
], anchor: bg),
```

`bg` is an `Anchor('bg')` declared a few lines up. The shift starts 1 s into
the 10 s scene and runs for 3 s, because relative times resolve against the
scene.

## React with Trigger.after

Another element waits for the anchored animation to finish:

<!-- code-excerpt "example/lib/lessons/03_timing_and_triggers.dart (after-trigger)" -->
```dart
const Text('Hello, Fluvie', style: _title).animate([
  Animation.slideFade(at: Trigger.after(bg)),
]),
```

The title slides in at exactly 4 s, the moment the gradient settles. Move
the gradient's timing and the title follows. That is the point: timing is a
relationship, not a constant.

## Bound an element with .show

`.show` gives an element a window; it exists only inside it:

<!-- code-excerpt "example/lib/lessons/03_timing_and_triggers.dart (show-window)" -->
```dart
Positioned(
  bottom: 200,
  child: const Text('Here from 5 s to 9 s', style: _caption)
      .show(from: 0.5.relative, to: 0.9.relative)
      .animate([Animation.fadeIn(), Animation.fadeOut()]),
),
```

Inside the window, relative times resolve against the window. The `fadeIn`
plays at its start, the `fadeOut` at its end.

## The trigger vocabulary

| Trigger | When the animation plays |
| --- | --- |
| `Trigger.auto` | the phase default: enter at the window start, exit at its end |
| `Trigger.at(time)` | at an explicit time inside the window |
| `Trigger.after(anchor)` | when the anchored animations have finished |
| `Trigger.whenStarts(anchor)` | when the anchored animations begin |
| `Trigger.previous` | right after the previous animation in the same list |
| `Trigger.sceneStart`, `Trigger.sceneEnd` | pinned to the scene boundaries |
| `Trigger.beat(every:)` | on the audio beat grid (needs a beat-tagged `Audio` track) |

Keep element sets stable: gate visibility with `.show`, not with `if`. The
resolver needs to see the same elements on every frame.

## Debugging time

Mount a `TimelineProbe` above your `Video` (the inspector does this for you)
and print `debugTimeline(timeline)`: every animation, its owner, and its
absolute frame span in one table.

## Where to next

- [Timeline orchestration](../advanced/timeline-orchestration.md): a deeper
  page on the resolver and how spans combine across scenes.
- [Backgrounds and gradients](backgrounds-and-gradients.md): the anchored
  gradient from this page.
- [Cheatsheet](../reference/cheatsheet.md): the whole shipped surface on one
  page.
