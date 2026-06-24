# Timeline orchestration

Most of the time, `.animate()` on each element is all you need. When you want
to place many animations on one shared clock, reach for `Timeline`. It is an
opt-in, GSAP-style builder that records steps against a running playhead:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_08_snippets.dart (timeline)" -->
```dart
Timeline introTimeline(Anchor title, Anchor subtitle, List<Anchor> bullets, Anchor cta) =>
    Timeline(defaults: const Defaults(duration: Time.seconds(0.5)))
      ..play(title, Animation.slideFade())
      ..play(subtitle, Animation.fadeIn(), at: Trigger.after(title))
      ..wait(0.3.seconds)
      ..playAll(bullets, Animation.slideFade(), stagger: 0.08.seconds)
      ..label('reveal')
      ..play(cta, Animation.pop(), at: 'reveal'.label - 0.2.seconds);
```

`Timeline` is experimental. Its surface may change before 1.0.

## How the playhead moves

Each call advances a playhead, the running position the next step starts from:

- `play(target, animation)` places one animation and moves the playhead to its
  end.
- `playAll(targets, animation, stagger:)` places one animation on many targets,
  staggered, and moves the playhead to the last one's end.
- `wait(time)` advances the playhead with no step.
- `label(name)` records the playhead under a name.

`duration` is the end of the latest step, derived for you.

## Placing a step with `at:`

`at:` overrides where a step starts. It accepts three things:

- a `Trigger`, for example `Trigger.after(title)` to start when `title` ends;
- a `String` label, for example `at: 'reveal'`;
- a `LabelRef` with offset arithmetic, for example `'reveal'.label - 0.2.seconds`.

Label arithmetic stays symbolic until the timeline resolves it at `play()` time,
so it never reaches the per-frame path.

## Driving a scene

Hand a `Timeline` to `Scene.sequence` and the scene adopts the timeline's
derived length. You declare the structure once and the scene runs on it:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_08_snippets.dart (scene-sequence)" -->
```dart
Scene sequencedScene(Timeline timeline) => Scene.sequence(
  timeline: timeline,
  background: Background.color(const Color(0xFF101820)),
  children: const [Text('Built on one clock')],
);
```

Build the timeline at the same fps as its `Video`, because every `Time` in it
resolves against that frame rate.

## Where to next

- [Timing and triggers](../guides/timing-and-triggers.md): the triggers and
  anchors the timeline resolves against.
- [Cheatsheet](../reference/cheatsheet.md): the whole shipped surface on one
  page.
