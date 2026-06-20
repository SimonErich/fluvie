# Layouts

Layout in Fluvie is plain Flutter. `Center`, `Column`, `Row`, `Stack`,
`Padding`, `SizedBox`, and `Positioned` all work inside a `Scene`, and any
widget you lay out can carry `.animate(...)`. Lesson 02 lays out three lines
with a `Column` and staggers them in:

<!-- code-excerpt "example/lib/lessons/02_text_and_motion.dart (column-stagger)" -->
```dart
const Column(
  mainAxisSize: MainAxisSize.min,
  spacing: 32,
  children: [
    Text('Layout is plain Flutter', style: _line),
    Text('Motion is one list', style: _line),
    Text('Timing happens for you', style: _line),
  ],
).animate([
  Animation.slideFade(stagger: const Stagger.each(Time.frames(8))),
]),
```

One `slideFade` with `Stagger.each(Time.frames(8))` animates each child 8
frames after the one before it. The layout knows nothing about the motion.

## Positioned works too

A `Positioned` child animates without any ceremony. Lesson 02 pins a badge
and chains an ambient float off its pop:

<!-- code-excerpt "example/lib/lessons/02_text_and_motion.dart (previous-chain)" -->
```dart
Positioned(
  top: 360,
  child: const Text('02', style: _badge).animate([
    Animation.pop(),
    Animation.float(at: Trigger.previous, amplitude: 0.1),
  ]),
),
```

## Scene children are centered

A scene stacks its children on a centered, canvas-filling stack. A bare
`Text` lands in the middle of the frame; wrap it in your own layout when you
want something else. `Scene.centered` is a one-child convenience for the
same thing.

## Box

`Box` is a rectangle whose `size` is always a fraction of its parent:
`Box(color: brand, size: Size(0.5, 0.01))` is half the parent's width and
one percent of its height. Leave `size` null to fill the parent. For
absolute pixels, use `SizedBox`; Fluvie adds no second sizing system.

## Frame

`Frame` wraps a child in a small styled shell:

| Constructor | What you get |
| --- | --- |
| `Frame.none` | passthrough, no decoration |
| `Frame.rounded(radius: 24)` | rounded corner clip |
| `Frame.card` | rounded white surface, padding, one soft shadow |
| `Frame.polaroid` | white border, wide at the bottom, one shadow |

## Where to next

- [Backgrounds and gradients](backgrounds-and-gradients.md): what sits
  behind your layout.
- [Timing and triggers](timing-and-triggers.md): sequence the elements you
  just laid out.
