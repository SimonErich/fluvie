# Scenes and transitions

A video is a list of scenes. A transition is how one scene becomes the next.
You pick the blend and Fluvie computes every frame of it. Set a default blend
on the `Video` and it applies to every boundary:

<!-- code-excerpt "examples/gallery/lib/lessons/04_scenes_and_transitions.dart (video-default)" -->
```dart
transition: Transition.crossFade(0.5.seconds), // overlap is on by default
```

That one line dissolves every scene into the next over half a second. Lesson
04 builds three scenes on it: a gradient title, a stats scene, and an outro.
Override the default on any boundary with `Scene.enter` or `Scene.exit`.

## The five transition kinds

Every transition shares `Time` and `Ease`, and each names its own shape:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_06_snippets.dart (transitions)" -->
```dart
Transition.cut(),
Transition.crossFade(0.5.seconds),
Transition.wipe(0.4.seconds, direction: Edge.right),
Transition.zoom(0.6.seconds, into: Alignment.center),
Transition.slide(0.4.seconds, from: Edge.right),
```

| Kind | What you see |
| --- | --- |
| `cut` | a hard cut: the next scene starts, no blend |
| `crossFade` | a dissolve: the incoming scene fades in over the outgoing |
| `wipe` | a travelling reveal toward `direction` (`Edge.right` reveals left to right) |
| `zoom` | the outgoing scene scales up and fades while the incoming settles in |
| `slide` | a push: the incoming slides in from `from`, the outgoing slides off |

## Overlap and your video's length

`overlap` decides what a transition does to the total length. It is the one
choice that changes how long your video runs.

- `overlap: true` shares the window. The incoming scene starts early, so the
  two scenes play at the same time during the blend and the total shortens by
  the transition's duration. `crossFade` turns it on by default.
- `overlap: false` keeps every scene at its full length. Each scene plays all
  of its frames, then the incoming one blends in over the outgoing scene's
  final frame, and the total stays the same.

Lesson 04 uses both. The default crossFade overlaps, so its 15 frames come off
the total. The outro's wipe runs sequentially, so it leaves the length alone:

<!-- code-excerpt "examples/gallery/lib/lessons/04_scenes_and_transitions.dart (wipe-scene)" -->
```dart
Scene.centered(
  duration: 3.seconds,
  background: Background.color(_ink),
  enter: Transition.wipe(0.4.seconds, overlap: false),
  child: const Text('See you next year', style: _outro).animate([
    Animation.blurIn(),
    Animation.fadeOut(),
  ]),
),
```

Three 3 second scenes sum to 270 frames. The overlapping crossFade takes the
total to 255; the sequential wipe keeps it there. You never count the frames,
but `video.totalFrames` reports the result.

## Per-scene enter and exit

A boundary sits between two scenes, so two scenes can have an opinion about it.
Fluvie resolves the conflict by precedence:

1. the incoming scene's `enter`
2. the outgoing scene's `exit`
3. the video default `transition`
4. a hard cut, if nothing governs

The incoming scene wins. An explicit `Transition.cut()` on `enter` or `exit`
is a real choice that forces a hard cut over a non-cut video default; `null`
means "no opinion" and falls through to the next candidate.

## Shared elements: a logo that morphs

Give the same `Anchor` to an element in two adjacent scenes and Fluvie tweens
its position, size, and opacity across the boundary. Declare the anchor once:

<!-- code-excerpt "examples/gallery/lib/lessons/04_scenes_and_transitions.dart (shared-anchor)" -->
```dart
final logo = Anchor('logo');
```

Then wrap the element in a `SharedElement` with that anchor in each scene. The
title scene shows the brand block large and centred:

<!-- code-excerpt "examples/gallery/lib/lessons/04_scenes_and_transitions.dart (title-scene)" -->
```dart
Scene(
  duration: 3.seconds,
  background: Background.gradient(const [Color(0xFF1D2671), Color(0xFFC33764)]),
  children: [
    SharedElement(
      anchor: logo,
      child: const Box(color: _brand, size: Size(0.4, 0.4)),
    ),
    const Text('Year in review', style: _title).animate([
      Animation.slideFadeIn(at: Trigger.sceneEnd),
    ]),
  ],
),
```

The next scene shows the same block small in the corner. During the blend, an
overlay paints the element travelling from the first rect to the second.

The rule is the same `Anchor` instance in a **contiguous run** of scenes.
Equality is identity, so two `Anchor('logo')` never pair. A pair is the
shortest chain there is; a longer one morphs through every cut it crosses, and
each boundary blends its own two ends. One scene alone is a hero with nothing
to morph to, and a run with a gap in it is two morphs pretending to be one —
both raise a typed error that names the anchor and its scenes. Most elements
take a `shared:` parameter that wraps them in a `SharedElement` for you; for a
plain widget, wrap it yourself.

A morph is two elements made to look like one across a cut. When you want one
element that genuinely *is* one for the whole video — a logo that never
blinks — reach for an [overlay](authoring-with-specs.md) instead: it mounts
once, outside every scene, and holds through every boundary.

## Camera basics

A `Camera` is a scene-wide zoom or pan. It is a property of the scene, not a
wrapper widget, and it applies outside every element's own animation. The stats
scene pushes its camera in while a shared logo sits in the corner:

<!-- code-excerpt "examples/gallery/lib/lessons/04_scenes_and_transitions.dart (camera-scene)" -->
```dart
Scene(
  duration: 3.seconds,
  background: Background.color(_ink),
  camera: const Camera.push(zoom: 1.25),
  children: [
    Align(
      alignment: Alignment.topLeft,
      child: SharedElement(
        anchor: logo,
        child: const Box(color: _brand, size: Size(0.12, 0.12)),
      ),
    ),
    const Center(child: Text('48,230', style: _stat)),
    Positioned(
      bottom: 220,
      child: const Text('minutes listened', style: _caption).animate([
        Animation.fadeIn(delay: 1.seconds),
      ]),
    ),
  ],
),
```

The four moves are `Camera.still()`, `Camera.push(...)`, `Camera.pull(...)`,
and `Camera.pan(from:, to:)`. Each eases over its `over` window (the whole
scene by default) and then holds. Because the shared element reads its rect off
the live scene, the morph follows the camera automatically.

## Transitions between clips inside one scene

Use `ClipTransitionGroup` when two clips share a scene rather than representing
whole scene boundaries. Give each clip an `ElementId`, put its `.show` window
directly inside that marker, and name the two IDs in a `ClipTransition`:

<!-- code-excerpt "examples/gallery/lib/snippets/authoring_snippets.dart (clip-transition)" -->
```dart
/// Blend two adjacent clips without serializing the composition.
Scene twoClips(String outgoingAsset, String incomingAsset) => Scene(
  duration: 4.seconds,
  children: [
    ClipTransitionGroup(
      transitions: [
        ClipTransition(
          outgoing: 'playing',
          incoming: 'resting',
          transition: Transition.crossFade(10.frames),
        ),
      ],
      children: [
        ElementId(
          id: 'playing',
          lane: 'cat',
          child: Clip.asset(outgoingAsset).show(from: 0.frames, to: 60.frames),
        ),
        ElementId(
          id: 'resting',
          lane: 'cat',
          child: Clip.asset(incomingAsset).show(from: 60.frames, to: 120.frames),
        ),
      ],
    ),
  ],
);
```

This example assumes the video's default 30 FPS. Both clips occupy the same
`lane`; IDs must be unique, and each edge joins consecutive clips on that lane.
The planner derives the blend window from the authored clip windows, including
abutting clips. It also applies matching equal-power envelopes to their embedded
audio. Native Flutter composition and `VideoSpec` use the same transition planner,
so readable generated Dart keeps the spec's visual and audio timing.

Preparation checks the actual mounted target, including clips created by normal
`Builder`, `LayoutBuilder` or reusable Flutter widgets. Every referenced ID must
contain a real `Clip`; a text or empty placeholder is not a clip transition
target. Keep the clip mounted and gate its visibility with `.show()`.
Targets must use independent clip windows. `Clip.shared` and `SharedElement`
anchors inside a clip transition are refused with the target ID and remedy;
use shared-element transitions across scenes when that is the desired motion.


## Where to next

- [Timing and triggers](timing-and-triggers.md): anchors, `Trigger.whenEnds`, and
  `.show` windows, the vocabulary the scenes above use.
- [Backgrounds and gradients](backgrounds-and-gradients.md): the gradient and
  solid fills behind each scene.
- [Cheatsheet](../reference/cheatsheet.md): the whole shipped surface on one
  page.
