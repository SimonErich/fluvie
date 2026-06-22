# Fluvie — API Specification

> The design reference for Fluvie's public API. Goal: **describe *what* the video
> is — never compute *when* things happen.**

A [Decision log](#decision-log) at the end records the design choices behind the API.

---

## Contents

1. [Principles](#1-principles)
2. [One import](#2-one-import)
3. [Quickstart](#3-quickstart)
4. [`Time`](#4-time)
5. [`Keyframe`](#5-keyframe)
6. [`Animation` — the one unit](#6-animation--the-one-unit)
7. [`Trigger` & `Anchor`](#7-trigger--anchor)
8. [`Timeline`](#8-timeline)
9. [Easing & springs](#9-easing--springs)
10. [`Defaults`](#10-defaults)
11. [`Video`](#11-video)
12. [`Scene`](#12-scene)
13. [`Transition` (incl. shared elements)](#13-transition)
14. [Layout](#14-layout)
15. [Elements](#15-elements)
16. [Backgrounds](#16-backgrounds)
17. [Captions](#17-captions)
18. [Audio & audio-reactive](#18-audio--audio-reactive)
19. [Camera](#19-camera)
20. [`FrameBuilder` (escape hatch)](#20-framebuilder)
21. [Theme & design tokens](#21-theme--design-tokens)
22. [Reproducible randomness](#22-reproducible-randomness)
23. [Multi-aspect & templates](#23-multi-aspect--templates)
24. [Export](#24-export)
25. [The `.animate()` extension](#25-the-animate-extension)
26. [Worked examples](#26-worked-examples)
27. [Under the hood](#27-under-the-hood)
28. [Tooling: lints, inspector, tests](#28-tooling)
29. [Authoring as data: `VideoSpec` & AI](#29-authoring-as-data)
30. [Ecosystem & rendering backends](#30-ecosystem--rendering-backends)
31. [Consolidation map (old → new)](#31-consolidation-map)
32. [Decision log](#decision-log)

---

## 1. Principles

1. **One way to do a thing.** One animation type (`Animation`), one time type (`Time`), one attachment (`.animate()`).
2. **Time is a value, not an `int`:** `2.5.seconds`, `20.frames`, `0.3.relative`.
3. **Timing flows down.** A `Scene` declares duration; everything inside inherits and self-positions. You specify timing only to deviate from the obvious default.
4. **It reads like Flutter** — real `Row`/`Column`/`Stack`, and familiar names (`Image`, `Animation`) so the mental jump from a Flutter screen is tiny.
5. **Expose a setting only when it's a real choice.** Everything else is inferred, defaulted, or carried by context.
6. **Names come from film & motion.** `Clip`, `Scene`, `Transition`, `Keyframe`, `Trigger`, `Anchor`.
7. **The hard cases stay possible** via `Keyframe`, `Timeline`, and `FrameBuilder` — present but never in the beginner's way.

---

## 2. One import

A single barrel re-exports the Flutter widgets you need for a video plus Fluvie's own `Image` and `Animation`:

```dart
import 'package:fluvie/fluvie.dart';
```

Because Fluvie deliberately reuses the familiar names **`Image`** and **`Animation`**, the barrel hides
Flutter's versions and provides Fluvie's. You won't notice — video authors don't use Flutter's
`Animation<T>`/`AnimationController` (Fluvie abstracts those) or its async `Image` (see §15). If you ever
need a raw Flutter type, import it with a prefix:

```dart
import 'package:flutter/widgets.dart' as flutter; // only if you need flutter.Animation<T> etc.
```

---

## 3. Quickstart

The brief's example, in the final API:

```dart
import 'package:fluvie/fluvie.dart';

final bg = Anchor('bg');

final video = Video(
  size: VideoSize.square,
  fps: 30,
  scenes: [
    Scene(
      duration: 10.seconds,
      children: [
        // A gradient that shifts color, named so others can react to it.
        Background.gradient([Colors.red, Colors.green]).animate(
          [Animation.gradientShift(to: [Colors.blue, Colors.green],
              duration: 0.3.relative,   // 30% of the 10s scene
              delay: 0.1.relative)],    // begins 1s in
          anchor: bg,
        ),

        // Slides + fades in, but only once the gradient shift finishes.
        Text('Hello, Fluvie')
            .animate([Animation.slideFade(from: Edge.bottom, at: Trigger.after(bg))]),

        // Slides in from the left over 4 seconds, then a slow Ken Burns push.
        Image.network('https://example.com/photo.jpg').animate([
          Animation.slideFade(from: Edge.left, duration: 4.seconds),
          Animation.kenBurns(zoom: 1.2),
        ]),
      ],
    ),
  ],
);
```

No frame numbers. No start frames. No manual "the gradient ends at frame 120." One `.animate([...])` list everywhere.

---

## 4. `Time`

The single currency for every duration, delay, offset, and trim. A `sealed` value type with `num` extensions.

```dart
20.frames        // exact frame count (fps-independent)
2.5.seconds      // real time
500.ms           // milliseconds
0.3.relative     // fraction of the nearest enclosing window
```

```dart
sealed class Time {
  const Time();
  const factory Time.frames(int frames)        = FrameTime;
  const factory Time.seconds(double seconds)   = SecondTime;
  const factory Time.ms(int milliseconds)      = MsTime;
  const factory Time.relative(double fraction, {Time? max}) = RelativeTime; // optional cap

  int resolveFrames(TimeScope scope);          // resolved by Fluvie, not you

  Time operator +(Time other);
  Time operator -(Time other);
  Time operator *(num factor);
}
```

**`relative` resolves against the element's own window if it has one, otherwise the enclosing scene.**
So `0.5.relative` on a 4-second element is 2s; on a bare scene child it's half the scene. The optional
`max:` caps it (used by the default duration — see §10).

---

## 5. `Keyframe`

A snapshot of animatable property values. `null` means "leave at the natural/layout value." This is the
primitive that all presets are built on (§6).

```dart
class Keyframe {
  const Keyframe({
    this.opacity,                 // 0..1
    this.x, this.y,               // OFFSET AS A FRACTION OF THE ELEMENT'S OWN SIZE (x: 1 = one width right)
    this.scale, this.scaleX, this.scaleY,
    this.rotation,                // turns (1.0 = 360°) — or use Angle.deg(…)
    this.skewX, this.skewY,
    this.blur,                    // logical px sigma
    this.color,                   // for color-capable elements
    this.origin = Alignment.center,
  });

  Keyframe operator +(Keyframe other);   // merge (other wins on overlap)
  static Keyframe lerp(Keyframe a, Keyframe b, double t);  // interpolate (used internally for tweening)
}
```

Offsets are **element-relative**: `Keyframe(y: 1)` is one element-height down regardless of resolution,
so a slide-up reads the same on a phone story and a 4K landscape.

---

## 6. `Animation` — the one unit

Everything visual is an `Animation`: transforms, opacity, color **and** pixel post-effects (grain,
vignette, shader). They all go in the same `.animate([...])` list. There is no separate effects system.

### Foundation: from / to / keyframes

```dart
Animation.from(Keyframe from)             // animate FROM these values → natural state (an "enter")
Animation.to(Keyframe to)                 // natural state → these values (an "exit")
Animation.fromTo(Keyframe from, Keyframe to)
Animation.keyframes(List<Keyframe> stops, {List<Curve>? easings, List<Time>? at, Trigger trigger = Trigger.auto})
Animation.along(Path path, {bool orient = true})   // travel a path
Animation.custom(AnimationEffect effect)           // your own effect
```

`Animation.keyframes` takes its start trigger as **`trigger:`** (not `at:`, which already names the stop positions).

### Presets (thin sugar over the foundation)

Friendly, guessable names that expand to the above. Examples:

```dart
Animation.fadeIn()                 => Animation.from(const Keyframe(opacity: 0));
Animation.fadeOut()                => Animation.to(const Keyframe(opacity: 0));
Animation.slideFade({Edge from = Edge.bottom})
    => Animation.from(Keyframe(opacity: 0, x: from.dx, y: from.dy));   // one element-size away
Animation.slideIn({Edge from = Edge.bottom})  Animation.slideOut({Edge to = Edge.top})
Animation.pop({double overshoot = 1.1})
    => Animation.from(const Keyframe(scale: 0), spring: Spring.bouncy); // spring by default
Animation.scaleIn({double from = 0.85})    // spring by default
Animation.blurIn({double sigma = 12})      Animation.blurOut()
Animation.maskWipe({WipeShape shape = WipeShape.circle, Alignment origin = Alignment.center})
Animation.glitchIn({Edge from = Edge.left})
```

Continuous (`during`):

```dart
Animation.float({double amplitude = 0.04, double frequency = 0.4, String? seed})
Animation.pulse({double min = 0.97, double max = 1.03})   // sine breathe; reactive form below
Animation.drift({Edge to = Edge.right, double distance = 0.1})
Animation.kenBurns({double zoom = 1.15, Edge pan = Edge.left})
Animation.spin({Time per = const Time.seconds(4)})
Animation.parallax({double depth = 0.2})                  // offset driven by the scene clock, for layers
```

Audio-reactive (`during`) — driven by the analysed spectrum (see §18):

```dart
Animation.scaleY({required AudioBand on, double gain = 1.0, Anchor? track})  // scale Y by band energy
Animation.pulse({AudioBand? on, double gain = 1.0, Anchor? track})           // reactive form of pulse
```

Color & paint:

```dart
Animation.color(to: Colors.blue)
Animation.gradientShift(to: [Colors.blue, Colors.green])
```

Pixel post-effects (same list, applied after transforms — see §27):

```dart
Animation.grain(double amount)        Animation.vignette(double amount)
Animation.scanlines()                 Animation.chromatic(double px)
Animation.bloom(double amount)        Animation.particles(Particles spec)
Animation.shader(String asset, {Map<String, Object> uniforms = const {}})
```

### Anatomy & timing

```dart
final class Animation {
  // Every constructor/preset shares this timing tail (shown on Animation.from):
  Animation.from(Keyframe from, {
    Time? duration,              // null inherits the Defaults cascade (see §10)
    Curve? ease,                 // null inherits Defaults (else Ease.smooth)
    Spring? spring,              // physics-driven; when set, wins over duration/ease
    Time delay = Time.zero,      // offset applied after the trigger fires
    Trigger at = Trigger.auto,   // relative to what it starts (the element's own window edge)
    Stagger? stagger,            // distribute start offsets across a multi-child target
    Repeat? repeat,              // loops within the span; null plays a single pass
    String? label,               // name THIS animation so others can chain off it
  });

  final AnimationEffect effect;  // built-in or custom
  final AnimationPhase phase;    // enter | exit | during  (inferred: from→enter, to→exit, continuous→during)
  final Time? duration;          // null defers to Defaults
  final Curve? ease;             // null defers to Defaults
  final Spring? spring;          // when set, wins over duration/ease
  final Time delay;
  final Trigger at;
  final Stagger? stagger;
  final Repeat? repeat;
  final String? label;

  // Derived anatomy view of the three timing fields (no stored `timing` field):
  Timing? get timing =>          // spring wins; else duration→Tween; else null (defer to Defaults)
      spring ?? (duration == null ? null : Tween(duration!, ease: ease ?? Ease.smooth));
}

Repeat.times(int n, {bool yoyo = false, Time gap = Time.zero})
Repeat.forever({bool yoyo = false})
```

Most calls touch only `duration`, `delay`, `at`, and maybe `stagger`. The three timing
fields are separate; `Timing`/`Tween`/`Spring` (§9) are the **derived** view via `timing`.

### Writing a custom effect

`AnimationEffect` is a pure function of `progress` (0→1). Fluvie owns timing, curves, frames.

```dart
final class Shear implements AnimationEffect {
  const Shear({this.maxSkew = 0.3});
  final double maxSkew;
  @override
  Widget build(Widget child, double progress) =>
      Transform(transform: Matrix4.skewX((1 - progress) * maxSkew), child: child);
}

Text('Skewed in').animate([Animation.custom(const Shear())]);
```

---

## 7. `Trigger` & `Anchor`

A **`Trigger`** answers "relative to what does this start?" An **`Anchor`** is a typed handle you attach to
an element so triggers can reference it — no strings, so autocomplete, rename-refactor, and "find usages" all work.

```dart
final class Anchor {
  Anchor([String? debugName]);   // the name is only for diagnostics
}

sealed class Trigger {
  static const Trigger auto       = …;   // default: the element's own window edge
  static const Trigger sceneStart = …;
  static const Trigger sceneEnd   = …;
  static const Trigger previous   = …;   // after the previous animation on THIS element (chaining)

  const factory Trigger.at(Time t)                          = AbsoluteTrigger;
  const factory Trigger.beat({int every = 1, Anchor? track}) = BeatTrigger;

  static Trigger after(Anchor a)      => …;  // when a's timeline ends
  static Trigger whenStarts(Anchor a) => …;  // when a's timeline starts
}
```

```dart
final intro = Anchor('intro');

Text('Title').animate([Animation.pop()], anchor: intro);
Text('Subtitle').animate([Animation.fadeIn(at: Trigger.after(intro), delay: 0.2.seconds)]);

// chaining on one element:
Image.asset('logo.png').animate([
  Animation.fadeIn(),
  Animation.pop(at: Trigger.previous),
  Animation.float(at: Trigger.previous),
]);
```

### Stagger

A property of an animation, applied when its target has multiple children:

```dart
Column(children: [Text('A'), Text('B'), Text('C')])
    .animate([Animation.slideFade(from: Edge.bottom, stagger: Stagger.each(0.08.seconds))]);

Stagger.each(0.08.seconds)
Stagger.evenly(over: 0.5.relative)
Stagger.from(StaggerOrigin.center)   // center-out, edges-in, …
```

---

## 8. `Timeline`

For complex sequences, an opt-in GSAP-style timeline places animations on one shared clock with labels —
while elements stay declarative. Beginners never need it; the per-element API above covers the easy 90%.

```dart
final tl = Timeline(defaults: const Defaults(duration: Time.seconds(0.5)))
  ..play(title,    Animation.from(const Keyframe(y: 1)))
  ..play(subtitle, Animation.fadeIn(), at: Trigger.after(title))
  ..wait(0.3.seconds)
  ..playAll(bullets, Animation.from(const Keyframe(x: -0.3)), stagger: 0.08.seconds)
  ..label('reveal')
  ..play(cta, Animation.pop(), at: 'reveal'.label - 0.2.seconds);

Scene.sequence(timeline: tl, children: [...]);   // duration DERIVED from tl (see §12)
```

---

## 9. Easing & springs

Animations are timed **either** by `duration + ease` **or** by a `spring` (which derives its own duration).
Setting `spring:` ignores `duration`/`ease`; the resolver computes the settle time for windowing and `Trigger.previous`.

```dart
sealed class Timing { }
class Tween  extends Timing { final Time duration; final Curve ease; }
class Spring extends Timing { final double stiffness, damping, mass, initialVelocity; }

Spring.gentle   Spring.snappy   Spring.bouncy   Spring.stiff
Spring({stiffness = 180, damping = 12, mass = 1, initialVelocity = 0})
```

Curated, plainly-named curves (each is a Flutter `Curve`):

```dart
Ease.linear  Ease.smooth  Ease.snappy  Ease.gentle
Ease.in_     Ease.out     Ease.inOut   Ease.back  Ease.bounce  Ease.elastic
```

`Ease.smooth` (ease-in-out) is the **default** for non-spring animations. Bouncy presets (`pop`, `scaleIn`)
use a **spring by default**.

---

## 10. `Defaults`

Set once, inherited everywhere, overridable locally. **Precedence: animation-local > `Scene` > `Video` > package default.**

```dart
class Defaults {
  final Time duration;     // package default: Time.relative(0.2, max: Time.seconds(0.8))
  final Curve ease;        // package default: Ease.smooth
  final Stagger? stagger;
}
```

The default duration is **20% of the window, capped at 0.8s** — so animations scale with short scenes but
never crawl on long ones.

---

## 11. `Video`

Root. Computes total duration from its scenes (adjusted for transition overlaps); you never sum anything.

```dart
Video({
  VideoSize? size,                 // preset; OR width + height
  int width = 1080, int height = 1920,
  int fps = 30,
  required List<Scene> scenes,
  Transition? transition,          // default transition between scenes
  List<Audio> audio = const [],
  Captions? captions,
  Defaults? motionDefaults,
  Export? export,
  Time? poster,                    // which frame is the thumbnail
});

VideoSize.reels   // 1080×1920 (canonical vertical; `story` is an alias)
VideoSize.square  // 1080×1080
VideoSize.hd      // 1920×1080
VideoSize.fourK   // 3840×2160
```

---

## 12. `Scene`

A time-bounded section — the single source of truth for everything inside it. Two constructors so that
"must have a length" is enforced by the type system, not a runtime assert:

```dart
Scene({
  required Time duration,          // explicit length
  Background? background,
  List<Widget> children = const [],
  Transition? enter, Transition? exit,
  Defaults? motionDefaults,
  Camera? camera,
  List<Audio> audio = const [],
});

Scene.sequence({                   // length DERIVED from its timeline / sequenced contents
  required Timeline timeline,
  Background? background,
  List<Widget> children = const [],
  …
});

Scene.centered({ required Time duration, Background? background, required Widget child, … });
```

---

## 13. `Transition`

Scene-to-scene blends. They share `Time`/`Ease` but stay a distinct type because they involve *two* scenes.

```dart
Transition.cut()
Transition.crossFade(0.5.seconds, overlap: true)   // overlap: scenes share time (total shorter)
Transition.wipe(0.4.seconds, direction: Edge.right)
Transition.zoom(0.6.seconds, into: Alignment.center)
Transition.slide(0.4.seconds, from: Edge.right)
```

**`overlap`** controls timing: `true` means the outgoing and incoming scenes overlap (total video is
shorter); `false` means each scene plays its full duration and then they blend.

### Shared-element ("hero") transitions

An element can persist and morph across a cut. Give the same `Anchor` instance to an element in both
scenes, and Fluvie tweens its position/size/opacity between them during the transition.

**The mechanism: the `SharedElement` wrapper.** Wrap a child with `SharedElement(anchor:, child:)` to bind
it to a shared slot across the boundary. The same `anchor` instance must appear in both adjacent scenes;
during the blend window the child's overlay clone travels from the source rect to the target rect, and its
opacity tracks the enclosing keyframe — so `SharedElement(...).animate([...])` morphs honestly. Outside a
`Video`/`Scene` (no `SharedElementScope` above), a `SharedElement` is a transparent passthrough of `child`.

```dart
final logo = Anchor('logo');

SharedElement(anchor: logo, child: Image.asset('logo.png'))  // big, centered in scene 1
// ...the same anchor in the next scene...
SharedElement(anchor: logo, child: Image.asset('logo.png'))  // morphs to the corner in scene 2
```

**Sugar via `shared:`.** `Image`, `Box`, `Chart`, the annotation elements, and others take a `shared:`
parameter that wraps the child in a `SharedElement` for you:

```dart
Scene(duration: 3.seconds, children: [
  Image.asset('logo.png', shared: logo),                 // big, centered
]),
Scene(duration: 4.seconds, children: [
  Align(alignment: Alignment.topLeft,
    child: Image.asset('logo.png', shared: logo)),        // morphs to the corner
]),
```

---

## 14. Layout

Use Flutter's real widgets — the `V*` family is gone. Timing flows via context and `.animate()`.

```dart
Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Title').animate([Animation.slideFade(from: Edge.bottom)]),
      SizedBox(height: 16),
      Text('Subtitle').animate([Animation.fadeIn(delay: 0.2.seconds)]),
    ],
  ),
);
```

- **Stagger** across `Row`/`Column`/`Stack`/`Wrap` children: put it on the container's `.animate()` (§7).
- **Own visibility window**: `.show(from:, to:)` (§25).
- **`Box`** is kept as a convenience for solid blocks, bars, and dividers (it's animatable like anything else):

```dart
Box(color: Colors.white, size: Size(0.5, 0.01))   // sizes may be fractions of the parent
    .animate([Animation.from(const Keyframe(scaleX: 0))]);   // a rule that grows in
```

---

## 15. Elements

Everything here accepts `.animate([...])`. Intrinsic widgets take constructor params **only** for their
content behaviour; transforms/effects always go through `.animate()`.

### `Image`

Reuses Flutter's name and constructor shape so it's instantly familiar — but it's Fluvie's own widget,
because a renderer must **pre-resolve sources before capture** so frames are deterministic (no "pops in
when it loads"). Fluvie pre-fetches/decodes and caches by content hash.

```dart
Image.network('https://…/photo.jpg', fit: BoxFit.cover)
Image.asset('me.png', frame: Frame.polaroid(caption: 'Summer'))
Image.file(file)   Image.memory(bytes)

Image.network('…').animate([Animation.slideFade(from: Edge.left), Animation.kenBurns(zoom: 1.2)]);
```

`Frame` is an optional decorative wrapper (replaces `PhotoCard`/`PolaroidFrame`):

```dart
Frame.none()   Frame.card({double radius = 16, double elevation = 8})
Frame.polaroid({String? caption})   Frame.rounded(24)
```

### `Clip` — embedded video

```dart
Clip.asset('intro.mp4', trim: 2.seconds.to(7.seconds),
  audio: ClipAudio.included(volume: 0.6, fadeIn: 0.3.seconds))
    .animate([Animation.fadeIn(), Animation.fadeOut()]);
Clip.network('https://…/b-roll.mp4');
```

### Text

Plain Flutter `Text` + `.animate()`. Fluvie swaps in render-safe opacity/transform internally (no
`saveLayer` seams during capture) — you never see it.

```dart
Text('Animated', style: TextStyle(fontSize: 64, color: Colors.white))
    .animate([Animation.slideFade(from: Edge.bottom)]);
```

### `Typewriter` (intrinsic)

```dart
Typewriter('Typed out one glyph at a time.', speed: 18.frames, caret: true)
    .animate([Animation.fadeIn()]);
```

### `Counter` (intrinsic)

```dart
Counter(to: 12500, duration: 2.seconds, format: NumberFormat.compact())   // "12.5K"
Counter.currency(to: 4999, symbol: r'$')   Counter.percent(to: 0.87)
```

### `Chart` (intrinsic)

The chart family — intrinsic, frame-driven elements whose reveal (growth, draw, sweep, pop-in) is built into their own constructor. Like `Counter` and `Typewriter`, a chart reads the frame clock and its time scope, computes a `0 → 1` reveal progress against its own window, and paints a `CustomPaint`. Color comes from `context.fluvie`, so wrapping a chart in a `FluvieTokensScope` (or the `FluvieTheme`) themes it. A per-series `color:` override wins. An optional `shared` anchor wraps the chart in a `SharedElement` for a hero morph across a scene boundary.

#### `Chart.bar` — column chart

Bars grow from the baseline by `value × ease(progress)` over `growIn`. An optional `stagger` delays each bar's growth so the columns rise in a wave.

```dart
Chart.bar(
  data: {'Jan': 30, 'Feb': 45, 'Mar': 80},
  growIn: 0.6.relative,
  stagger: Stagger.each(0.06.seconds),
  shared: logoAnchor,  // optional hero anchor
)
```

#### `Chart.line` — polyline chart

Single or multi-series line drawn left to right, trimmed to the reveal progress so it draws on over the `drawIn` window.

```dart
// Single series:
Chart.line(data: {'Jan': 30, 'Feb': 45}, drawIn: 0.6.relative)

// Multi-series (colored):
Chart.line.series([
  ChartSeries.values(name: 'Sales', data: {'Jan': 30, 'Feb': 45}),
  ChartSeries.values(name: 'Costs', data: {'Jan': 20, 'Feb': 35}, color: Colors.red),
], drawIn: 0.6.relative)
```

#### `Chart.area` — filled area chart

Fills under a sweeping line, stacking multiple series. The fill follows the line sweep and closes to the baseline.

```dart
// Single series:
Chart.area(data: {'Jan': 30, 'Feb': 45}, drawIn: 0.6.relative)

// Multi-series (stacked):
Chart.area.series([
  ChartSeries.values(name: 'A', data: {'Jan': 30, 'Feb': 45}),
  ChartSeries.values(name: 'B', data: {'Jan': 20, 'Feb': 35}),
])
```

#### `Chart.pie` — pie chart

Segments sweep clockwise from 12 o'clock. Each segment's angle is proportional to its value; the whole disc sweeps angularly over `sweepIn` (default `0.6` relative window) so the pie fills in. Segment colors cycle the theme palette.

```dart
Chart.pie(data: {'A': 30, 'B': 45, 'C': 25}, sweepIn: 0.6.relative)
```

#### `Chart.donut` — donut chart

A pie chart with an inner-radius hole. The hole is cut with an even-odd ring path (no `saveLayer`), keeping the draw capture-safe.

```dart
Chart.donut(
  data: {'A': 30, 'B': 45, 'C': 25},
  sweepIn: 0.6.relative,
  innerRadius: 0.6,  // fraction of outer radius; default 0.6
)
```

#### `Chart.scatter` — scatter plot

Markers pop in with a spring scale. Use explicit `(x, y)` points, a category → value map (category index is x), or a colored point series. An optional `stagger` offsets each point's pop so markers pop in a wave.

```dart
// Explicit points:
Chart.scatter(
  points: [ChartPoint(x: 1, y: 2), ChartPoint(x: 2, y: 4)],
  popIn: 0.6.relative,
)

// From data map (index → value):
Chart.scatter(data: {'A': 2, 'B': 4, 'C': 3})

// Multi-series (colored):
Chart.scatter.series(
  ChartSeries.points(name: 'Cloud', data: [
    ChartPoint(x: 1, y: 2, label: 'Q1'),
    ChartPoint(x: 2, y: 4, label: 'Q2'),
  ]),
  popIn: 0.6.relative,
  stagger: Stagger.each(0.08.seconds),
)
```

#### Data shapes: `ChartSeries` and `ChartPoint`

`ChartSeries` holds one named, optionally colored series. Exactly one of `data` (category → value) or `points` (x, y coordinates) is non-null:

```dart
const ChartSeries.values(name: 'Sales', data: {'Jan': 30, 'Feb': 45})
const ChartSeries.values(name: 'Revenue', data: {'Jan': 30, 'Feb': 45}, color: Colors.blue)
const ChartSeries.points(name: 'Cloud', data: [ChartPoint(x: 1, y: 2)])
```

`ChartPoint` is one `(x, y)` sample with an optional `label` for tooltips or legend:

```dart
const ChartPoint(x: 12, y: 4.5, label: 'Q1')
```

### `Code`

Renders syntax-highlighted source as a frame-driven element. Source is highlighted once per content (cached by hash); the painter is deterministic from (parsed spans, reveal progress, theme tokens).

```dart
Code(
  'void main() => print("hi");',
  language: 'dart',              // highlight.js language id ('dart', 'python', …)
  reveal: CodeReveal.instant,    // how the source appears (instant|typing|lineByLine)
  focusLines: {1},               // 1-based line numbers to keep lit; dims others
  highlightLines: {2, 3},        // 1-based lines to tint background
  theme,                         // CodeTheme, or null reads context.fluvie.code
  style,                         // TextStyle (fontSize, fontFamily only); colors from theme
  shared: codeAnchor,            // optional hero anchor
)

Code.diff(
  'final x = 1;',
  'final x = 2;',
  language: 'dart',
  reveal: CodeReveal.lineByLine(12.frames),  // animated line-level LCS diff
)

// CodeReveal variants:
CodeReveal.instant                      // everything visible immediately
CodeReveal.typing(Time speed)           // glyph-by-glyph (e.g. 2.frames per glyph)
CodeReveal.lineByLine(Time perLine)     // whole lines in sequence
```

With `focusLines` set, every other line dims to `theme.dimOpacity`; `highlightLines` tint backgrounds. Both are content params—swap them across scenes to drive focus via frame clock.

### `Markdown`

Renders Markdown as a frame-driven element. Source is parsed once per content (cached by hash) and rendered to widgets: headings, paragraphs, lists, blockquotes, inline `code` / **bold** / *italic*, fenced code blocks (as `Code` widgets), and images (as `Image` widgets). Unsupported nodes render as plain text.

```dart
Markdown(
  '# Release notes\n\n- Faster renders\n- `Code` highlighting',
  style: MarkdownStyle(                    // or null reads context.fluvie
    body: TextStyle(color: Colors.white, fontSize: 18),
    code: TextStyle(color: Colors.orange, fontFamily: 'JetBrains Mono'),
    quote: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
    headingScale: 1.5,                     // each level shrinks by this factor
    headingBase: 32,                       // h1 size
  ),
  reveal: 1.seconds,                       // block-by-block reveal, or null for instant
  shared: docAnchor,                       // optional hero anchor
)

// Predefined styles:
MarkdownStyle.fallback()                    // light body, muted quote, monospace code, dark bg
MarkdownStyle.fromTokens(context.fluvie)   // reads labelColor, code.string, axisColor
```

With `reveal` non-null, top-level blocks appear one after another, each fading and sliding up as its turn arrives. `headingSize(level)` computes a heading's font size by level (1-based).

### `Terminal`

Renders a terminal session as a frame-driven element. Lines play in sequence: commands type glyph by glyph after a prompt with a blinking caret; output streams whole. The painter is a pure function of (lines, reveal state, theme tokens).

```dart
Terminal(
  lines: [
    TerminalLine.cmd('npm install'),           // types out with caret
    TerminalLine.cmd('npm test', prompt: '> '),  // per-line prompt override
    TerminalLine.out('added 120 packages'),    // streams whole
  ],
  prompt: r'$ ',                         // default prefix for all cmd lines
  chrome: TerminalChrome.macos(          // optional window bar
    title: 'zsh',                        // title in bar, or null for empty
    showDots: true,                      // traffic-light dots
  ),
  typingSpeed: const Time.frames(2),     // frames per glyph
  lineGap: const Time.frames(18),        // frames between lines
  style,                                 // TextStyle (fontSize, fontFamily only)
  shared: terminalAnchor,                // optional hero anchor
)

// Chrome variants:
TerminalChrome.macos(title: 'zsh')       // title bar + traffic lights
TerminalChrome(title: 'bash', showDots: true)  // explicit construction
TerminalChrome.none                      // no bar, no dots (same as null)

// Line variants:
TerminalLine.cmd(String text, {String? prompt})  // typed command, optional prompt override
TerminalLine.out(String text)                     // streamed output
```

Colors come from `context.fluvie.code`. Each command types at `typingSpeed`, spaced by `lineGap` from the previous line's completion.

### `Mermaid` (diagrams)

Renders a Mermaid diagram to a raster once before the frame loop (deterministic, never live). The diagram source becomes a still image pre-computed and cached by content hash. An optional [theme] overrides the default; a [reveal] drives opacity over the single raster (fade-in nodes or draw-in edges).

```dart
Mermaid('graph TD; A-->B; B-->C;')
Mermaid(flow, theme: MermaidTheme.light(), reveal: MermaidReveal.fadeNodes(1.seconds))
```

```dart
final class Mermaid extends StatelessWidget implements MediaCarrier {
  const Mermaid(
    this.source, {            // Mermaid source text (e.g. 'graph TD; A-->B;')
    this.theme,               // optional MermaidTheme override; null uses Mermaid's default
    this.reveal = MermaidReveal.none,     // how the diagram reveals (fade-in or draw-in)
    this.fit = BoxFit.contain, // how the raster scales into its box
    this.shared,              // optional Anchor for hero morph across scenes
    super.key,
  });

  final String source;
  final MermaidTheme? theme;
  final MermaidReveal reveal;  // MermaidReveal.none | fadeNodes(Time) | drawEdges(Time)
  final BoxFit fit;
  final Anchor? shared;
}
```

**Theme** — a sealed value type carrying variant and theme variables:

```dart
final class MermaidTheme {
  const MermaidTheme({required this.variant, this.themeVariables = const {}});
  const MermaidTheme.dark();   // 'dark' variant + dark-neutral colors
  const MermaidTheme.light();  // 'base' variant + light-neutral colors

  final String variant;        // Mermaid built-in name ('dark', 'base', etc.)
  final Map<String, String> themeVariables;  // color overrides
  String get cacheKey;  // canonical, context-free key folded into snapshot cache
}
```

**Reveal** — sealed, controls per-frame opacity over the pre-rasterized diagram:

```dart
sealed class MermaidReveal {
  const MermaidReveal();
  const factory MermaidReveal.fadeNodes(Time window) = FadeNodesReveal;
  const factory MermaidReveal.drawEdges(Time window) = DrawEdgesReveal;
  static const MermaidReveal none = …;  // fully visible from frame 0
}
```

The bundled headless-Chrome rasterizer is experimental; inject a `SnapshotService` to capture real diagrams.

### `Snapshot` (subtree capture)

Rasterizes an arbitrary Flutter subtree once before the frame loop and paints the cached still every frame. In-process, so the same child renders the same still and the result caches and goldens. Useful to freeze a busy or expensive subtree into a single image you then animate like any element.

```dart
Snapshot(child: const ComplexChart()).animate([Animation.slideIn()])
```

```dart
final class Snapshot extends StatelessWidget implements CollectibleChildren {
  const Snapshot({
    required this.child,              // subtree to rasterize once
    this.shared,                      // optional Anchor for hero morph
    this.fit = BoxFit.contain,        // how the captured raster scales
    super.key,
  });

  final Widget child;
  final Anchor? shared;
  final BoxFit fit;
}
```

In capture mode, a `SnapshotCaptureScope` pre-pass rasterizes every `Snapshot`; `build` paints from cache (never rebuilds the child). In preview, the child renders live. A capture with no pre-captured image for this instance throws `FluvieRenderException`.

### `DeviceFrame` (pure chrome)

Wraps any child in device chrome: phone bezel, browser window with address bar, or tablet bezel. **Chrome only** — draws no raster, calls no snapshot service, composes over any child (`WebView`, `Mermaid`, `Image`, `Snapshot`, plain Flutter widgets). Chrome colors come from `context.fluvie.code` (bezel from background, address bar from chromeColor, text from lineNumberColor).

```dart
DeviceFrame.browser(
  url: 'https://example.com',
  child: WebView.url('https://example.com', viewport: viewport),
);
DeviceFrame.phone(child: const Mermaid('graph TD; A-->B;'));
DeviceFrame.tablet(child: snapshot);
```

```dart
final class DeviceFrame extends StatelessWidget implements CollectibleChildren {
  const DeviceFrame.phone({
    required Widget child,
    bool notch = true,       // draw top notch (default on)
    Anchor? shared,          // optional hero anchor
    Key? key,
  });

  const DeviceFrame.browser({
    required Widget child,
    String? url,             // optional address bar text
    Anchor? shared,
    Key? key,
  });

  const DeviceFrame.tablet({
    required Widget child,
    Anchor? shared,
    Key? key,
  });

  final Widget child;
  final String? url;           // only on .browser
  final bool notch;            // only on .phone
  final Anchor? shared;
}
```

Chrome is painted behind the child via a capture-safe painter (no `saveLayer`). Child renders inside content inset.

### `WebView` (live page capture)

Captures a live web page deterministically to a raster — the page at a URL becomes a still image rasterized once before the frame loop at a fixed viewport. Headless Chromium navigates (network-allowlisted), screenshots at the declared viewport (GPU-disabled, time-boxed), and the same URL, viewport, scroll, and clip always yield the same raster.

```dart
WebView.url('https://example.com', viewport: SnapshotViewport(width: 1280, height: 720))
WebView.url(Uri.parse('https://example.com'),
  viewport: SnapshotViewport(width: 800, height: 600),
  scroll: const Offset(0, 240), clip: const Rect.fromLTWH(0, 0, 800, 360))
```

```dart
final class WebView extends StatelessWidget implements MediaCarrier {
  WebView.url(
    Object uri,  // Uri or parseable String; normalized at construction
    {
      required this.viewport,   // fixed pixel box for layout and capture
      this.scroll,              // optional offset before capture (null = page top)
      this.clip,                // optional region within viewport (null = whole viewport)
      this.fit = BoxFit.cover,  // how the raster scales into its box
      this.shared,              // optional Anchor for hero morph
      super.key,
    },
  );

  final Uri uri;                // normalized page URL
  final SnapshotViewport viewport;
  final Offset? scroll;
  final Rect? clip;
  final BoxFit fit;
  final Anchor? shared;
}
```

Host is checked against the network allowlist before navigation. A capture with no pre-resolution throws `FluvieRenderException`; a live preview shows a placeholder, never a live view.

### `Html` (inline markup capture)

Captures inline HTML laid out at a fixed viewport to a raster — the markup becomes a still image rasterized once before the frame loop. Unlike `WebView` the markup is local, so no network is touched and no allowlist is consulted. Headless Chromium lays out the source document and screenshots it (GPU-disabled, time-boxed), so the same markup and viewport always yield the same raster.

```dart
Html('<h1>Hello</h1>', viewport: SnapshotViewport(width: 800, height: 200))
Html(snippet, viewport: SnapshotViewport(width: 600, height: 400), fit: BoxFit.contain)
```

```dart
final class Html extends StatelessWidget implements MediaCarrier {
  const Html(
    this.source,  // inline HTML markup
    {
      required this.viewport,   // fixed pixel box for layout and capture
      this.fit = BoxFit.cover,  // how the raster scales into its box
      this.shared,              // optional Anchor for hero morph
      super.key,
    },
  );

  final String source;
  final SnapshotViewport viewport;
  final BoxFit fit;
  final Anchor? shared;
}
```

A capture with no pre-resolution throws `FluvieRenderException`; a live preview shows a placeholder.

### `SnapshotViewport` (fixed layout box)

The deterministic, fixed pixel box a `WebView`/`Html` snapshot is laid out and captured in — size is declared upfront, never discovered from the window. Logical pixels are multiplied by `deviceScale` (default `1.0`) to compute the raster's physical dimensions.

```dart
final class SnapshotViewport {
  const SnapshotViewport({
    required this.width,         // logical width in pixels
    required this.height,        // logical height in pixels
    this.deviceScale = 1.0,      // multiplier to raster physical dimensions
  });

  final int width;
  final int height;
  final double deviceScale;

  int get pixelWidth => (width * deviceScale).round();
  int get pixelHeight => (height * deviceScale).round();
}
```

All three must be positive. The bundled headless-Chrome rasterizer is experimental; inject a `SnapshotService` to capture real content. With no service available, capture throws `FluvieSnapshotUnavailableError`.

### Annotations — overlay callouts, arrows, and emphasis

Annotation elements draw geometric emphasis (arrows, shapes, spotlights) or text overlays (callouts, titles, lower thirds) over scenes. All accept `.animate([...])` and most accept a `shared:` anchor for hero morphs across scene boundaries.

**Arrow** — Points from one position to another with a stroked shaft and triangular head. Optionally draws on over a `drawIn` window (the shaft grows, then the head appears).

```dart
const Arrow.to({
  required Offset from,
  required Offset to,
  Color? color,                      // defaults to context.fluvie palette[0]
  double strokeWidth = 3,
  double headLength = 16,
  Time? drawIn,                      // optional reveal window
  Anchor? shared,
  Key? key,
})
```

**Callout** — A label pill pointing an arrow at a target, wrapping a child (gathered in collect pass). The label sits at `labelAt` and the arrow runs from the pill toward `target`.

```dart
const Callout({
  required String label,
  required Offset target,            // in child's coordinate space
  required Widget child,
  Offset labelAt = const Offset(16, 16),
  Color? color,                      // arrow & pill accent (defaults to palette[0])
  Anchor? shared,
  Key? key,
})
```

**Connector** — A straight or right-angle line linking two points. When `elbow: true`, bends through a corner (horizontal first, then vertical). Draws on over `drawIn`.

```dart
const Connector({
  required Offset from,
  required Offset to,
  bool elbow = false,
  Color? color,                      // defaults to palette[0]
  double strokeWidth = 2,
  Time? drawIn,
  Anchor? shared,
  Key? key,
})
```

**LowerThird** — A broadcast-style name/title bar that slides in from the left and settles. Wraps an optional background child (gathered in collect pass). With no `slideIn`, sits in place.

```dart
const LowerThird({
  required String name,              // primary line
  String? title,                     // secondary line (optional)
  Widget? child,
  Time? slideIn,                     // optional window for horizontal slide
  Color color = const Color(0xCC101418),  // translucent dark band
  Anchor? shared,
  Key? key,
})
```

**Shape** — A stroked annotation primitive: line, rectangle, circle, or arbitrary path. Each variant draws on left-to-right over its `drawIn` window (the stroke grows along its length).

```dart
const Shape.line({
  required Offset from,
  required Offset to,
  Color? color,
  double strokeWidth = 3,
  Time? drawIn,
  Anchor? shared,
  Key? key,
})

const Shape.rect({
  required Rect rect,
  Color? color,
  double strokeWidth = 3,
  Time? drawIn,
  Anchor? shared,
  Key? key,
})

const Shape.circle({
  required Offset center,
  required double radius,
  Color? color,
  double strokeWidth = 3,
  Time? drawIn,
  Anchor? shared,
  Key? key,
})

const Shape.path({
  required Path path,
  Color? color,
  double strokeWidth = 3,
  Time? drawIn,
  Anchor? shared,
  Key? key,
})
```

**Spotlight** — Dims everything except a lit `region`, focusing attention. Wraps a child (gathered in collect pass). The dim is a single even-odd fill with no `saveLayer`, staying capture-safe. The hole grows from nothing to full `region` over `reveal`.

```dart
const Spotlight.on({
  required Rect region,              // the lit area kept clear of dim
  required Widget child,
  Time? reveal,                      // optional window for hole-grow
  Color color = const Color(0xB3000000),  // translucent black
  Anchor? shared,
  Key? key,
})
```

**TitleCard** — A centered title (and optional subtitle) that fades up over its `reveal` window. Wraps an optional background child (gathered in collect pass). With no `reveal`, sits fully opaque.

```dart
const TitleCard({
  required String title,
  String? subtitle,
  Widget? child,
  Time? reveal,                      // optional fade-up window
  Color color = const Color(0xFFFFFFFF),  // title color (subtitle is dimmed)
  Anchor? shared,
  Key? key,
})
```

### Combined example

```dart
Scene(duration: 6.seconds, children: [
  // Annotate a screenshot with arrows, shapes, and a callout
  Image.asset('dashboard.png').animate([
    Animation.fadeIn(),
    Animation.kenBurns(zoom: 1.1),
  ]),

  // Arrow pointing at a metric
  Arrow.to(
    from: const Offset(240, 100),
    to: const Offset(420, 180),
    drawIn: 1.seconds,
  ).animate([Animation.fadeIn()]),

  // Circle highlight around a button
  Shape.circle(
    center: const Offset(640, 320),
    radius: 60,
    color: Colors.green,
    drawIn: 12.frames,
  ),

  // Callout label pointing at active metric
  Callout(
    label: 'Peak hours',
    target: const Offset(720, 200),
    labelAt: const Offset(520, 80),
    child: Container(),  // empty; callout overlays the image
  ),

  // Lower third intro
  LowerThird(
    name: 'Dashboard',
    title: 'Real-time metrics',
    slideIn: 1.5.seconds,
  ).animate([Animation.fadeOut(at: Trigger.at(5.seconds))]),
]);
```

---

## 16. Backgrounds

All variants under `Background.*`. A `Background` is also a normal element, so it can be tagged with an
`Anchor` and animated (that's the gradient-shift trigger in §3).

```dart
Background.color(Colors.black)
Background.gradient([Colors.red, Colors.green], begin: Alignment.topLeft, end: Alignment.bottomRight)
Background.radial([Colors.white, Colors.blue])
Background.image('bg.jpg', fit: BoxFit.cover)
Background.video('loop.mp4')
Background.noise({double scale = 1})   Background.vhs()
```

```dart
Scene(duration: 6.seconds, background: Background.color(Colors.black), children: [ … ]);  // static
// or as an animated, anchored child:
Background.gradient([Colors.red, Colors.green]).animate([Animation.gradientShift(to: […])], anchor: bg);
```

---

## 17. Captions

A first-class track. Import SRT/VTT or build inline; styled, safe-area positioned, word-level pop for free
(word pop is just `Animation` + `stagger` under the hood).

```dart
Video(
  captions: Captions.fromSrt('en.srt', style: CaptionStyle.tikTok(),
      position: CaptionPosition.bottomThird()),
  scenes: [...],
);

Captions.fromVtt('en.vtt');
Captions.words([CaptionWord('Hello', at: 0.0.seconds), CaptionWord('world', at: 0.4.seconds)]);

CaptionStyle.tikTok()   CaptionStyle.subtitle()   CaptionStyle.karaoke()
CaptionPosition.bottomThird()   CaptionPosition.topThird()   CaptionPosition.center()
CaptionPosition.custom(Alignment alignment, {double safeArea})
```

---

## 18. Audio & audio-reactive

Audio on `Video` or `Scene`; multiple tracks layer/mix. Beat-reactivity is a `Trigger` (powered by `BeatDetectionService`); spectrum-reactivity is an animation input (powered by `FrequencyAnalyzer`).

```dart
Video(
  audio: [Audio.music('song.mp3', volume: 0.8, fadeIn: 1.seconds, fadeOut: 1.seconds, track: beat)],
  scenes: [
    Scene(duration: 8.seconds, children: [
      Text('On the beat').animate([Animation.pop(at: Trigger.beat(every: 1, track: beat))]),
      Bars(count: 24).animate([Animation.scaleY(on: AudioBand.bass, gain: 1.5)]),
      Bars(count: 16, band: AudioBand.mid).animate([Animation.pulse(on: AudioBand.mid, gain: 1.2)]),
    ]),
  ],
);

Audio.music(path, {volume, fadeIn, fadeOut, loop, trim, track})
Audio.sfx(path, {at, volume})        // one-shot anchored to a Trigger
```

(`beat` is an `Anchor` naming the track. `AudioBand.bass|mid|treble` drives reactive animations.)

### Reactive animations

Two `Animation` presets consume spectrum data per frame (see §6 for the signature pattern):

```dart
Animation.scaleY({required AudioBand on, double gain = 1.0, Anchor? track, …})
    // Scales Y by 1 + energy·gain each frame; spectrum bars pulse with the bass kick.

Animation.pulse({AudioBand? on, double gain = 1.0, Anchor? track, …})
    // With on: — reactive pulse scaling per band energy (like scaleY but as a 1.0 ± scale).
    // Without on: — non-reactive sine pulse (original form; see §6).
```

Both read from the precomputed band table set up during the precompute pass; `track` scopes to one `Audio.track` or reads the master mix if `null`. They require a `ReactiveScope` in capture.

### Spectrum visualizer

**`Bars`** — an intrinsic element that paints a spectrum bar visualizer:

```dart
Bars({
  int count = 24,                       // how many bars
  AudioBand band = AudioBand.bass,      // which frequency band
  Anchor? track,                        // which audio track (null = master mix)
  double gain = 1.0,                    // multiplier on [0,1] energy
  Anchor? shared,                       // optional hero anchor
});

Bars(count: 24).animate([Animation.scaleY(on: AudioBand.bass, gain: 1.5)])
```

Each bar's height is `energy · gain · profile(i)`, where the profile is a fixed golden-angle bump that distributes energy across bars deterministically. Colored from `context.fluvie.palette`.

### Analysis contracts (precompute layer)

These interfaces (injected by the renderer) power both `Trigger.beat()` and the reactive animations:

**`BeatDetectionService`** — detects beats in an audio source via spectral-flux onset detection:

```dart
abstract interface class BeatDetectionService {
  Future<BeatGrid> detect(AudioSource source, {required int fps, required int totalFrames});
}
```

Returns a queryable `BeatGrid` (immutable, cached by content hash). The real `SpectralBeatDetectionService` lives above `core`; the contract is injected for testing.

**`FrequencyAnalyzer`** — analyses an audio source into per-frame band energy via FFT:

```dart
abstract interface class FrequencyAnalyzer {
  Future<BandTable> analyze(AudioSource source, {required int fps, required int totalFrames});
}
```

Returns a queryable `BandTable` (immutable, cached by content hash) with `energyAt(frame, band)` for each of `AudioBand.bass|mid|treble`. The real `SpectralFrequencyAnalyzer` lives above `core`; the contract is injected for testing. Both analyses run in the precompute pass (before frame 0), and the frame loop only queries the immutable results.

---

## 19. Camera

Scene-wide zoom/pan (was `CameraFocus`) — a property of the scene, not a wrapper widget.

```dart
Scene(duration: 5.seconds,
  camera: Camera.push(zoom: 1.3, toward: Alignment.topRight, over: 1.0.relative),
  children: [ … ]);

Camera.still()   Camera.push(...)   Camera.pull(...)   Camera.pan(from:, to:)
```

---

## 20. `FrameBuilder`

The escape hatch: when no preset fits, drop to a builder with resolved frame/progress and paint anything.

```dart
FrameBuilder((ctx) {
  final p = ctx.progress;            // 0..1 across this element's window
  final f = ctx.frame;               // absolute frame
  final bass = ctx.audio(beat);      // analysed value of a tagged track
  return CustomPaint(painter: MyViz(progress: p));
});
```

`ctx` is a `FrameContext`, exposing `frame`, `progress`, `fps`, `scope` (start/duration), `audio(anchor)`,
and `noise(seed)` (§22).

---

## 21. Theme & design tokens

Centralize palette, type scale, and motion defaults; elements read them via context.

```dart
FluvieTheme(
  palette: Palette(bg: Color(0xFF0E0E12), accent: Color(0xFF6C5CE7), onBg: Colors.white),
  type:    TypeScale.fromBase(16, ratio: 1.25),
  motion:  Defaults(duration: 0.5.seconds, ease: Ease.out),
  child: video,
);

Text('Branded', style: context.fluvie.type.title.copyWith(color: context.fluvie.palette.accent));
```

### The token system: `FluvieTokens` & `FluvieTokensScope`

`FluvieTokens` is the value-object that carries all design state: the chart series palette, axis/grid/label colors, code/mermaid/caption themes, the brand palette, type scale, and motion defaults. A `FluvieTheme` mounts it via `FluvieTokensScope` so every element can read tokens via the `context.fluvie` accessor — no element changes; they just read what's available.

```dart
const FluvieTokens({
  required ChartPalette palette,        // series colors (distinct from brand palette)
  required Color axisColor,             // chart axes
  required Color gridColor,             // plot background gridlines
  required Color labelColor,            // axis labels & legend text
  CodeTheme code = const CodeTheme.dark(),
  MermaidTheme mermaid = const MermaidTheme.dark(),
  CaptionTheme captions = const CaptionTheme.standard(),
  Palette brand = const Palette.fallback(),      // brand bg/accent/onBg
  TypeScale type = const TypeScale.fallback(),   // display/title/headline/body/caption
  Defaults motion = const Defaults(),            // animation cascade defaults
})

// Fallback: automatic if no scope above
const FluvieTokens.fallback()
```

**Wrap with `FluvieTokensScope` to apply tokens to a subtree** — typically `FluvieTheme` does this internally. But you can layer scopes directly:

```dart
FluvieTokensScope(
  tokens: const FluvieTokens(
    palette: ChartPalette([Color(0xFF6C5CE7), Color(0xFF00B894), Color(0xFFE17055)]),
    axisColor: Color(0xFF9E9E9E),
    gridColor: Color(0x33FFFFFF),
    labelColor: Color(0xFFE0E0E0),
    code: CodeTheme.light(),
    brand: Palette(bg: Color(0xFF0E0E12), accent: Color(0xFF6C5CE7), onBg: Colors.white),
  ),
  child: myChart,
)
```

`FluvieTokensScope.of(context)` and the `context.fluvie` extension always succeed — every subtree has a real default (the fallback) even if no scope is mounted:

```dart
// In any element's build
final seriesColor = context.fluvie.palette.colorAt(seriesIndex);
final brandAccent = context.fluvie.brand.accent;
final codeTheme = context.fluvie.code;
```

### Token groups

**Chart colors** — `palette` (a `ChartPalette`), `axisColor`, `gridColor`, `labelColor`:

```dart
const ChartPalette([Color(0xFF6C5CE7), Color(0xFF00B894), Color(0xFFE17055)])
// colorAt(i) wraps modularly, so a palette with 3 colors cycles forever
```

**Brand palette** — distinct from the chart series palette:
```dart
const Palette(
  bg: Color(0xFF0E0E12),
  accent: Color(0xFF6C5CE7),
  onBg: Color(0xFFE0E0E0),
  surface: Color(0xFF2A2A2F),       // optional: raised panels
  onSurface: Color(0xFFFFFFFF),     // optional: text on surface
)
```

**Type scale** — five roles from a single `base` size and step `ratio`:
```dart
TypeScale.fromBase(16, ratio: 1.25)
// derives display, title, headline, body, caption with geometric steps
// Each role carries only fontSize and fontWeight, staying composable at the call site
```

**Code theme** — for `Code` / `Terminal` elements:
```dart
const CodeTheme({
  required Color keyword, string, comment, number, type, function, punctuation, plain,
  required Color background, gutterColor, lineNumberColor, highlightColor, chromeColor,
  required double dimOpacity,
  Color addedGutter = Color(0xFF4EC9B0),
  Color removedGutter = Color(0xFFF14C4C),
})

CodeTheme.dark()   // light text on #1E1E1E
CodeTheme.light()  // dark text on #FFFFFF
```

**Mermaid theme** — for diagram rendering:
```dart
const MermaidTheme({
  required String variant,                    // Mermaid built-in: 'dark', 'base', etc.
  Map<String, String> themeVariables = const {},  // color overrides
})

MermaidTheme.dark()   // 'dark' with primary=#2d2d2d, text=#e0e0e0
MermaidTheme.light()  // 'base' with primary=#ffffff, text=#1e1e1e
```

**Caption theme** — default style when a caption track declares none:
```dart
const CaptionTheme({required CaptionStyle defaultStyle})
CaptionTheme.standard()  // subtitle placement + styling
```

**Motion defaults** — cascade layer for animation timing:
```dart
const Defaults({Time? duration, Curve? ease, Stagger? stagger})
// Every field is nullable — null means "inherit from the level below"
// Precedence: animation-local > Scene > Video > FluvieTokens.motion > package defaults
```

### `FluvieTheme` vs `FluvieTokens`

`FluvieTheme` is a convenience widget that sets **only the brand group** (palette, type, motion) and inherits/preserves the chart colors and element themes from the nearest scope above. It mounts a `FluvieTokensScope` internally:

```dart
FluvieTheme(
  palette: const Palette(...),         // brand only (charts unaffected)
  type: TypeScale.fromBase(18, ratio: 1.3),
  motion: const Defaults(duration: 0.5.seconds),
  child: video,
)
// child reads: context.fluvie.brand (new), context.fluvie.palette (inherited)
```

If you need to override chart colors, element themes, or the full token set, use `FluvieTokensScope` directly — `FluvieTheme` is the sugar for the common case.

All tokens are `@immutable` and value-equal by field, so two identical builds produce identical geometry — the frame-caching contract.

---

## 22. Reproducible randomness

Organic motion that stays stable across frames and re-renders (so caching and goldens
work). Effects pull randomness from a seed; prefer the seeded `noise(seed)` / `random(seed)` API over `dart:math Random()` in render code.

```dart
final n = ctx.noise('petal-$i');                 // stable per seed
Animation.float(amplitude: 0.04, seed: 'leaf-7'); // organic but reproducible
```

`ctx.noise(seed)` reads from a seeded `NoiseSource` — the same seam `Animation.float(seed:)` uses — so a
seed maps to one stable value per frame, identical across machines and re-renders.

---

## 23. Multi-aspect & templates

### One definition, many aspect ratios

```dart
Adaptive(
  reels:     () => Column(children: [...]),   // vertical 9:16
  square:    () => Row(children: [...]),       // square 1:1
  landscape: () => Row(children: [...]),       // horizontal 16:9
  portrait45: () => Column(children: [...]),   // vertical 4:5
);

await render(video, aspect: Aspect.reels);
await render(video, aspect: Aspect.portrait45);
// any element can branch: AspectScope.of(context)
```

**Aspect variants:**

- **`Aspect.reels`** — Vertical 9:16 (Reels, Shorts, TikTok, Stories). The fallback aspect when no `AspectScope` is active.
- **`Aspect.square`** — Square 1:1 (feed posts).
- **`Aspect.landscape`** — Horizontal 16:9 (YouTube, presentations, TV).
- **`Aspect.portrait45`** — Vertical 4:5 (tall feed-post format).

Each branch can be `null` to mark unsupported aspects; rendering an absent aspect throws `ArgumentError` at build.

### Parameterized / data-driven videos

```dart
class IntroTemplate extends VideoTemplate<IntroProps> {
  @override
  Video build(IntroProps p) => Video(
    size: VideoSize.reels, fps: 30,
    scenes: [Scene.centered(duration: 3.seconds, child: Text(p.name).animate([Animation.pop()]))],
  );
}

for (final u in users) {
  await render(IntroTemplate(), props: IntroProps(name: u.name, color: u.brandColor));
}
```

Combined with reproducible rendering (§22), identical props → identical bytes → cacheable. Render a
template directly with `renderTemplate(template, props: …)` (§24). Two batteries-included templates ship
ready to use: `TitleIntro` (with `TitleIntroProps`) and `StatHighlight` (with `StatHighlightProps`).

---

## 24. Export

```dart
Export.mp4(quality: Quality.high)
Export.gif(fps: 15)
Export.imageSequence(format: ImageFormat.png)   // compositing pipelines
Export.transparent()                            // alpha (WebM/ProRes) for overlays
Video(poster: 1.seconds);                       // thumbnail frame
```

### Rendering entry points

Three free functions drive offline video capture. All return manifests encoding the ffmpeg arguments to materialize the output; the CLI wires them through an `FfmpegProvider` for encoding. A capture failure surfaces as a `FluvieRenderException`; an encode failure as a `FluvieEncodeException`.

#### `render(...)` — multi-aspect canonical

Renders a `Widget` composition for one `Aspect`, re-deriving the canvas size from `aspect.sizeFor(longEdge)`. Mounts an `AspectScope` and feeds the composition through the capture shell once per aspect. All aspects share the same clock and animations — only layout branches differ (via `Adaptive` and `AspectScope.of`).

```dart
Future<RenderAspectResult> render({
  required Widget composition,
  required Aspect aspect,
  required int frameCount,
  required Directory outDir,
  required RenderService service,
  required ShellMount pumpWidget,      // host supplies its pump: flutter_test's or CLI binding's
  required ShellFramePump pumpFrame,
  int longEdge = 1920,                 // re-derive size from aspect.sizeFor(longEdge)
  int fps = 30,
  String compositionKey = 'render',
  bool cacheEnabled = false,
  AudioMixStager? stageAudio,          // optional: explicit audio staging
  Iterable<AudioSource>? audioSources,
}) → RenderAspectResult;  // (manifest, config re-derived for this aspect)
```

#### `renderToSandbox(...)` — in-memory, web-friendly

Captures one aspect into a `RenderSandbox` (file or in-memory) without touching the file system. Used by the web encoder and tests. Video-only (no audio staging yet); the manifest carries `-an`.

```dart
Future<RenderManifest> renderToSandbox({
  required Widget composition,
  required Aspect aspect,
  required int frameCount,
  required RenderSandbox sandbox,      // MemoryRenderSandbox on web, FileRenderSandbox elsewhere
  required FrameCaptureService capture,
  required SandboxMount pumpWidget,
  required SandboxFramePump pumpFrame,
  int longEdge = 1920,
  int fps = 30,
  String compositionKey = 'render',
  Export? export,
  int? posterFrame,
  ProgressCallback? onProgress,
  VideoEncoderService encoder = const VideoEncoderService(),
}) → RenderManifest;
```

#### `renderTemplate<P>(...)` — data-driven

Renders a parameterized `VideoTemplate<P>` for one `props` value. Builds `template.build(props)`, wraps it in deterministic LTR `Directionality`, and runs the result through the same capture path as `render`. Defaults to `Aspect.reels` (9:16).

```dart
Future<RenderAspectResult> renderTemplate<P>({
  required VideoTemplate<P> template,
  required P props,
  required int frameCount,
  required Directory outDir,
  required RenderService service,
  required ShellMount pumpWidget,
  required ShellFramePump pumpFrame,
  Aspect aspect = Aspect.reels,
  int longEdge = 1920,
  int fps = 30,
  String compositionKey = 'template',
  bool cacheEnabled = false,
}) → RenderAspectResult;
```

#### `RenderService` — capture & encode separation

The low-level orchestrator: pre-resolves media, runs the deterministic frame loop (cache lookup → pump → capture → append), writes the manifest **last** as the completion signal. Exports are optional (default is silent MP4).

```dart
final class RenderService {
  RenderService({
    required FrameCaptureService capture,
    MediaResolver media = const NoMediaResolver(),
    FrameCache? cache,
    VideoEncoderService encoder = const VideoEncoderService(),
  });

  /// Captures `config.frameCount` frames to `outDir/frames.rgba`, returns manifest.
  Future<RenderManifest> captureToDirectory({
    required RenderConfig config,
    required Directory outDir,
    required FramePump pump,                    // frame-by-frame pump callback
    required GlobalKey boundaryKey,             // where to snapshot
    required String compositionKey,
    Iterable<MediaSource> mediaSources = const [],
    Iterable<AudioSource> audioSources = const [],
    AudioMixStager? stageAudio,
    Export? export,
    int? posterFrame,
    ProgressCallback? onProgress,
  }) → RenderManifest;

  /// captureToDirectory + in-process ffmpeg encode; returns the encoded file.
  Future<File> render({
    required RenderConfig config,
    required Directory outDir,
    required FramePump pump,
    required GlobalKey boundaryKey,
    required String compositionKey,
    required FfmpegProvider provider,          // encoder backend
    // … media, audio, export, posterFrame, onProgress
  }) → File;                                   // outDir/out.mp4 (or .gif, etc.)
}
```

All three entry points run the same capture pipeline, so the same composition renders the same frames for a given aspect.

---

## 25. The `.animate()` extension

One mechanism, works on any widget (Fluvie's or Flutter's):

```dart
extension Animate on Widget {
  Widget animate(
    List<Animation> animations, {
    Anchor? anchor,         // name this element's timeline for Triggers
    TimeRange? window,      // override the element's alive-window (default: whole scene)
    Defaults? defaults,
  });

  Widget show({Time? from, Time? to});   // sugar: animate([], window: from.to(to))
}
```

Independent window (when you don't want the full-scene default):

```dart
Text('Only the middle third')
    .show(from: 0.33.relative, to: 0.66.relative)
    .animate([Animation.fadeIn(), Animation.fadeOut()]);
```

---

## 26. Worked examples

### Multi-scene clip

```dart
final logo = Anchor('logo');
final beat = Anchor('beat');

Video(
  size: VideoSize.reels, fps: 30,
  transition: Transition.crossFade(0.4.seconds, overlap: true),
  motionDefaults: const Defaults(ease: Ease.smooth),
  audio: [Audio.music('track.mp3', fadeIn: 1.seconds, fadeOut: 1.5.seconds, track: beat)],
  scenes: [
    Scene.centered(
      duration: 3.seconds,
      background: Background.gradient([Color(0xFF1D2671), Color(0xFFC33764)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('logo.png', shared: logo),
        Text('2025', style: TextStyle(fontSize: 120, color: Colors.white))
            .animate([Animation.pop()]),                       // spring by default
        Text('Year in review', style: TextStyle(fontSize: 36, color: Colors.white70))
            .animate([Animation.slideFade(from: Edge.bottom, at: Trigger.previous, delay: 0.1.seconds)]),
      ]),
    ),

    Scene(
      duration: 4.seconds, background: Background.color(Colors.black),
      children: [
        Align(alignment: Alignment.topLeft, child: Image.asset('logo.png', shared: logo)),  // morphs in
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Counter(to: 48230, duration: 2.seconds, format: NumberFormat.compact(),
              style: TextStyle(fontSize: 96, color: Colors.greenAccent)),
          Text('minutes listened', style: TextStyle(fontSize: 32, color: Colors.white))
              .animate([Animation.fadeIn(delay: 1.5.seconds)]),
        ])),
      ],
    ).animate([Animation.grain(0.2), Animation.vignette(0.4)]),   // pixel fx in the same list

    Scene.centered(
      duration: 3.seconds, background: Background.color(Colors.black),
      child: Text('See you next year', style: TextStyle(fontSize: 56, color: Colors.white))
          .animate([Animation.blurIn(), Animation.float(), Animation.fadeOut()]),
    ),
  ],
);
```

### Data-driven photo wall with stagger

```dart
Scene(
  duration: 4.seconds, background: Background.color(Colors.white),
  children: [
    Padding(
      padding: EdgeInsets.all(48),
      child: Wrap(spacing: 12, runSpacing: 12, children: [
        for (final p in photos) Image.network(p, frame: Frame.card()),
      ]).animate([Animation.slideFade(from: Edge.bottom, stagger: Stagger.each(0.06.seconds))]),
    ),
  ],
);
```

---

## 27. Under the hood

How duration reaches every element with zero arithmetic at the call site.

### 27.1 `TimeScope` flows down

An `InheritedWidget` at every level that defines a duration:

```dart
class TimeScope { final int fps, startFrame, durationFrames; final TimeScope? parent; }
```

- `Video` → root scope: `fps`, `startFrame: 0`, `durationFrames = Σ scenes` (minus transition overlaps).
- `Scene` → child scope: its resolved duration, `startFrame` = running offset of prior scenes.
- An element with its own `window` (or a `Clip` trim) → nested scope for its subtree.

Like Remotion's scene-relative `useCurrentFrame()`, but resolved at build time instead of read in a hook.

### 27.2 Resolving a `Time`

```dart
int resolveFrames(TimeScope s) => switch (this) {
  FrameTime(:final frames)               => frames,
  SecondTime(:final seconds)             => (seconds * s.fps).round(),
  MsTime(:final milliseconds)            => (milliseconds / 1000 * s.fps).round(),
  RelativeTime(:final fraction, :final max) =>
      _cap((fraction * s.durationFrames).round(), max, s),   // ← the magic line (+ optional cap)
};
```

`0.3.relative` in a 10s scene @30fps → 90 frames. Change the scene to 12s → 108, no code change.
`relative` measures the element's own window if it has one, else the scene (§4).

### 27.3 Default window & placement

- No `window` → the element is alive for the **whole scene**.
- `enter` (a `from`): starts at `windowStart + delay`, runs for the resolved `duration`.
- `exit` (a `to`): **ends at `windowEnd - delay`**; start = end − duration (end-anchored — you never compute it).
- `during`: spans the window; loops per `repeat`.
- Default `duration` = `min(0.2 × window, 0.8s)`.

### 27.4 Springs

When `spring:` is set, there's no fixed duration — Fluvie integrates the spring to a settle threshold and
uses that settle time for the window and for `Trigger.previous`. So chaining after a spring still works.

### 27.5 The two-pass trigger resolver

Triggers let A start relative to B, so a single top-down pass isn't enough:

1. **Collect** every `Anchor` and labelled animation into a dependency graph.
2. **Topologically sort** so dependencies resolve first; `Trigger.beat` resolves against the tagged track's analysed beat grid.
3. **Detect cycles** → a build-time `FluvieTimingError` naming both anchors (never a silent hang).
4. **Resolve** each animation to absolute `[start, end]` frames.

All of this runs **inside** Fluvie. The call site only wrote `anchor: bg` and `Trigger.after(bg)`.

### 27.6 The unified `Animation` pipeline

Because transforms and pixel effects share one list, Fluvie classifies each `Animation` and builds the
pipeline deterministically: **transforms wrap the widget first; pixel effects are applied as a post-process
layer afterward, in list order among themselves.** So `[slideFade, grain]` slides the widget, then lays
grain over the result — regardless of list order between the two classes.

### 27.7 Capture isolation

`Image`/`Clip` sources are pre-resolved and cached by content hash before capture; randomness is seeded
(§22). The frame is the only clock, so a render is reproducible enough to cache and to golden-test. Fluvie does not guarantee byte-identical output across machines or encoders.

### 27.8 Shared frame capture loop

The **one clock all backends use** — desktop (FFmpeg process), mobile (hardware encoder), and web (ffmpeg.wasm). It is `dart:io`-free, so it runs everywhere.

```dart
Future<void> runFrameCaptureLoop({
  required RenderConfig config,
  required String digest,                      // content hash for frame caching
  required FramePump pump,                     // host supplies: frame → pump callback
  required GlobalKey boundaryKey,              // snapshot boundary
  required CaptureSink sink,                   // file or in-memory byte accumulator
  required FrameCaptureService capture,
  FrameStore? store,                           // optional: disk cache
  ProgressCallback? onProgress,
});
```

For each frame in `config.startFrame .. startFrame + frameCount - 1`: **cache lookup by digest+index** → if hit and size matches, append cached bytes (no pump); else pump, snapshot under `boundaryKey`, append, store. The frame is the only clock; the sink is storage-agnostic (disk or in-memory). Progress callbacks are observational — they read no wall-clock and never affect frame bytes.

### 27.9 Storage abstraction — pluggable backends

**`RenderSandbox`** — one render's storage: the frames file, manifest, materialized encoder inputs, and output. Two implementations:

- **`FileRenderSandbox`** — writes through to a real directory (desktop/mobile); process encoders run there.
- **`MemoryRenderSandbox`** — holds all files as `Map<String, Uint8List>` (web, unit tests); no file system needed.

Both implement the same interface; the capture loop and encoders never know which.

**`CaptureSink`** — growable byte sink the loop appends raw RGBA frames to:

```dart
abstract interface class CaptureSink {
  void add(Uint8List bytes);        // append one frame
  Future<void> close();              // flush and close
}
```

**`FrameStore`** — content-addressed frame cache, keyed by render digest + frame index. `dart:io`-free:

```dart
abstract interface class FrameStore {
  Future<Uint8List?> lookup(String digest, int frameIndex);  // cache hit or null
  Future<void> store(String digest, int frameIndex, Uint8List bytes);
}
```

**`FrameCache`** — disk adapter (desktop/mobile only): keys are FNV-1a-64 hex (path-safe), rooted at `$TMPDIR/fluvie_frame_cache` by default. **Advisory:** the digest covers config + composition key + fluvie version, but not the composition's runtime code, so editing a composition under an unchanged key can serve stale frames until the digest moves or `--no-cache` bypasses it.

### 27.10 Audio-mix resolution — encoder-neutral seam

`resolveAudioMix(video:, fps:, totalFrames:)` resolves a `Video`'s declared `Audio` tracks into encoder-neutral `ResolvedAudioMix` — delay, trim, gain, fades resolved as seconds and milliseconds, not FFmpeg strings. Used by custom encoders (mobile hardware, on-device, wasm) to apply the same timing math the FFmpeg path uses.

```dart
ResolvedAudioMix {
  List<ResolvedAudioTrack> tracks;  // per-track timing + the authored source
  double masterVolume = 1;           // final gain after mixing
}

ResolvedAudioTrack {
  String source;                     // asset, file path, or URL
  int delayMs;                       // how far to shift the track later
  double volume = 1;                 // linear gain
  double? trimStartSeconds;          // where playback begins in the source
  double? trimEndSeconds;            // where playback ends
  double? fadeInSeconds;             // ramp in from silence
  double? fadeOutSeconds;            // ramp out to silence
  double fadeOutStartSeconds;        // when the fade-out begins
  bool loop = false;                 // whether to repeat to fill the render window
}
```

The FFmpeg path builds its `FfmpegAudioNode` from the exact same numbers, so a desktop render and an on-device render delay, trim, gain, and fade identically. Pure and synchronous — reads no files, so the custom encoder materializes sources itself.

### 27.11 Content hashing & frame caching

`renderDigest(config:, compositionKey:, fluvieVersion:)` produces the cache key — a **FNV-1a-64 hex over the full `RenderConfig` JSON, the composition key, and the fluvie library version.**

```dart
String renderDigest({
  required RenderConfig config,
  required String compositionKey,
  required String fluvieVersion,
}) → fnv1a64Hex(jsonEncode({...}));
```

Any change to config, key, or version produces a new digest, isolating cache entries across configurations, compositions, and library versions. The **frame cache key itself** is FNV-1a-64 over `digest:frameIndex`, so path-safe by construction. The cache is **advisory**: composition **code** changes under an unchanged key are not detected — stale frames stay in cache until the digest moves or a `--no-cache` run evicts them.

### 27.12 Three backends, one pipeline

**Desktop (FFmpeg process):** `FileRenderSandbox` → frame loop → frames file → ffmpeg subprocess.

**Mobile (hardware encoder):** `FileRenderSandbox` → frame loop → `resolveAudioMix` → hardware codec.

**Web (ffmpeg.wasm):** `MemoryRenderSandbox` → frame loop → manifest → ffmpeg.wasm (driven through the injected `WasmRuntime`) → encoded bytes.

All three share:
- The same `runFrameCaptureLoop`, deterministic and `dart:io`-free.
- The same `TimeScope` resolution, so animations time identically.
- The same frame caching by content digest.
- The same audio-mix timing math (FFmpeg nodes on desktop, `ResolvedAudioMix` on mobile/custom).

Swapping the encoder changes where the encode runs, not the composition: all three drive the same
deterministic capture loop and capture the same frames. The encoded file can differ between backends
(hardware encoders vary); each backend's renders-twice proof holds on the same machine.

### 27.13 Why complexity here is the right trade

The renderer runs on capable devices and isn't a hot path, so Fluvie spends complexity internally — a
timing graph, nested scopes, a resolver, a render pipeline — to keep the call site free of frame numbers
and arithmetic.

---

## 28. Tooling

### `fluvie_lints` (built alongside v1, on `custom_lint`)

Editor squiggles + `dart analyze` failures, with quick-fixes where possible:

- `no_src_import` — flags a `package:<other>/src/...` import (single-barrel rule); suggests the public barrel.
- `layering` — enforces the layering law: dependencies point down only (`core` ← `timing` ← features ← `diagnostics`).
- `deprecated_member` — drives migration from pre-1.0 names with quick-fixes (e.g. `KenBurnsImage` → `Image` + `Animation.kenBurns()`).
- `dangling_anchor` — a `Trigger` references an `Anchor` never attached to an element.
- `cyclic_trigger` — elements wait on each other, forming a cycle.
- `unused_anchor` — declared but never referenced; quick-fix removes it.
- `animation_exceeds_window` — resolved animation duration longer than its element window.
- `conflicting_keyframe_fields` — two animations write the same `Keyframe` field over the same time.
- `relative_outside_scope` — `0.x.relative` where no enclosing duration exists.

Annotations: `@useResult` on `.animate()`/`.show()`; `@Deprecated(...)` on renamed members; `@experimental`
on `Timeline`/`FrameBuilder`/shader `Animation`s.

### Inspector & tests

```dart
debugTimeline(video);   // prints a resolved table: element | window | animation | start | end
testFrame(video, at: 2.seconds, matchesGolden('frames/intro_60.png'));
```

Both build on the same resolver Fluvie already runs — and a scrubbable live inspector is the natural next
step (Fluvie's answer to Remotion Studio).

### Diagnostics & inspector exports

The main barrel (`package:fluvie/fluvie.dart`) re-exports the timing inspection surface:

```dart
// Immutable value: the resolved schedule as an inspector UI consumes it
InspectorModel.fromTimeline(timeline)   // fps, totalFrames, motions[], anchors[], warnings[]
InspectorMotion                         // one resolved animation (ownerId, label, phase, startFrame, endFrame)

// Debug output: fixed-width text table for assertions and tests
debugTimeline(timeline)  // → string: owner | label | phase | start | end | frames

// Embedder-owned probe: the Video pushes its ResolvedTimeline here after each resolution
TimelineProbe()                         // ValueNotifier<ResolvedTimeline?> + error capture
TimelineProbeScope(probe: p, child: v)  // InheritedWidget; Video reads and updates the probe
```

`InspectorModel` is pure (no `BuildContext`, no IO) and golden-stable — the example app's `InspectorViewModel` consumes it. `TimelineProbe` captures both success and timing errors; the embedder listens and renders either the schedule or a diagnostic error message.

---

## 29. Authoring as data

A `VideoSpec` is a JSON-serializable mirror of a `Video`. Author a spec from a prompt with an LLM, persist it as data, and render it deterministically with `buildVideo()` — the model runs once at authoring time, never in the frame loop.

### The spec types

`VideoSpec` is the root—it holds `scenes`, `size`, `fps`, and optional `poster`/`export`/`motionDefaults`/`transition`. Each `SceneSpec` holds `duration`, an optional `BackgroundSpec` (`background`)/`enter`/`exit`, and a list of `ElementSpec` children. Each `ElementSpec` names a `type` (from `knownElementTypes`), carries its content `props` verbatim, optionally declares an `anchor` id, and holds an `animate` list of `AnimationSpec` objects. Each `AnimationSpec` is either a named preset (like `fadeIn`) or a raw `from`/`to`/`fromTo` keyframe, plus the common timing tail (`duration`, `ease`, `delay`, `at`, `stagger`, `repeat`, `label`). Background types come from `knownBackgroundKinds` (`color`, `gradient`, `image`, `video`, `noise`, `vhs`, etc.); animation presets from `knownAnimationPresets` (`fadeIn`, `pop`, `kenBurns`, `slideIn`, `slideFade`, …).

### Time as a string

Durations and delays are unit-tagged strings:
- `"2s"` — seconds
- `"500ms"` — milliseconds  
- `"30f"` — frames
- `"0.3r"` — fraction of the enclosing window; capped relatives like `"0.2r@0.8s"` cap the fraction to a max

Composite times (from `+`, `-`, `*`) have no JSON form and raise a `FluvieSpecError`; always author a duration as a single unit.

### Serialization & identity

Read a spec with `VideoSpec.fromJson(map)`, which validates the schema and builds an `AnchorTable`—minting one canonical `Anchor` per id string so the element that declares `anchor: "intro"` and every trigger pointing to `"intro"` resolve to the same instance. This is why you must reuse the `anchors` table when building:

```dart
final spec = VideoSpec.fromJson(jsonDecode(jsonText) as Map<String, Object?>);
final video = buildVideo(spec);   // reuses spec.anchors internally
```

Write a spec back with `spec.toJson()` (includes the `fluvieSpec: 1` version marker). The serialization is canonical—a load-then-save round trip settles after one pass.

Every spec has a stable digest:

```dart
final id = spec.digest();   // FNV-1a hash of canonical JSON
```

Identical specs share identical digests, so an AI-authored video keys the frame cache and names its output reproducibly.

### Building from a spec

```dart
Video buildVideo(VideoSpec spec) => spec.build();
```

This free function is a pure function: the same spec always builds the same video, so renders are reproducible and cacheable. No model is called during rendering.

### The schema

`videoSpecSchema` is a JSON Schema (draft-07) that defines the spec contract. It's compiled from the same `knownElementTypes`, `knownAnimationPresets`, and `knownBackgroundKinds` that power the codecs—so the schema can never drift from the parser. Fluvie's AI authoring surfaces (`fluvie_ai` and the MCP server in `fluvie_server`) feed this schema to a model as the structured-output contract; `VideoSpec.fromJson` remains the authoritative validator at parse time.

### Example

```json
{
  "fluvieSpec": 1,
  "size": "reels",
  "fps": 30,
  "scenes": [
    {
      "duration": "4s",
      "background": { "kind": "gradient", "colors": ["#1A2980", "#26D0CE"] },
      "children": [
        {
          "type": "Text",
          "text": "Hello, Fluvie",
          "style": { "color": "#FFFFFF", "fontSize": 72 },
          "anchor": "title",
          "animate": [{ "preset": "fadeIn" }]
        },
        {
          "type": "Text",
          "text": "Let's build videos",
          "animate": [{ "preset": "fadeIn", "at": { "kind": "after", "anchor": "title" }, "delay": "0.2s" }]
        }
      ]
    }
  ]
}
```

### Ecosystem

The companion package `fluvie_ai` (Dart API) and the MCP server in `fluvie_server` (for assistants) emit and consume `VideoSpec`. See [AI and MCP](../documentation/guides/ai-and-mcp.md) for authoring from a prompt and connecting an assistant.

---

## 30. Ecosystem & rendering backends

Fluvie's modular design separates authoring (which always stays light—just `package:fluvie`) from rendering, so you pick the backend that fits your constraints. All backends render the same `Video` spec deterministically; they differ only in where encoding happens and which FFmpeg strategy they use.

| Package | Role | Headline API | Guide |
| --- | --- | --- | --- |
| **fluvie_cli** | Headless render CLI (`fluvie render`); FFmpeg auto-provision. | `run()` (the `fluvie render` entry) / `ensureFfmpeg` | [Exporting your video](../documentation/guides/exporting-your-video.md) / [Managing FFmpeg](../documentation/guides/managing-ffmpeg.md) |
| **fluvie_mobile_encoder** | On-device hardware encode (MediaCodec / AVAssetWriter). No FFmpeg; frames never leave the device. | `OnDeviceVideoRenderer` | [On-device mobile rendering](../documentation/guides/on-device-mobile-rendering.md) |
| **fluvie_web_encoder** | In-browser ffmpeg.wasm encode. Opt-in, so web apps stay light. | `WebVideoRenderer` | [package README](../packages/fluvie_web_encoder/README.md) |
| **fluvie_server** | One self-hostable binary: HTTP render API (local or S3), MCP server (stdio/HTTP), and a docs helper, each toggled by env; web-safe client. | `ApiRenderClient` (client) / `serveFluvieApi` + `buildServerApp` (server) | [Rendering on a server](../documentation/guides/rendering-on-a-server.md) / [AI and MCP](../documentation/guides/ai-and-mcp.md) |
| **fluvie_ai** | NL → deterministic `VideoSpec`; provider-agnostic LLM client. | `VideoAuthorService` / `LlmVideoAuthorService` | [AI and MCP](../documentation/guides/ai-and-mcp.md) |

All rendering packages are optional; the core `package:fluvie` never pulls in FFmpeg, WASM, or server deps. See [Tooling](#28-tooling) for `fluvie_lints` (available in all environments).

---

## 31. Consolidation map (old → new)

| Today                                                                 | Becomes                                            |
| --------------------------------------------------------------------- | -------------------------------------------------- |
| `PropAnimation`, `EntryAnimation`, `AmbientAnimation`/`FloatingVibe`, `SlideIn`, `SceneTransition`-as-animation | `Animation.*` presets / `Animation.from`/`to`/`keyframes` / `AnimationEffect` |
| `AnimatedProp`                                                        | `.animate([...])`                                  |
| `Stagger` widget + `StaggerConfig`                                    | `stagger:` on an `Animation`                       |
| `EffectOverlay`, `ParticleEffect`, `MaskedClip`, `ParallaxLayer`      | `Animation.grain/vignette/particles/shader/maskWipe` (same `.animate()` list) |
| `VStack` `VColumn` `VRow` `VCenter` `VPadding` `VPositioned` `VSizedBox` | `Stack` `Column` `Row` `Center` `Padding` `Positioned` `SizedBox` |
| `LayerStack`/`Layer`, `VideoTimingMixin`                              | internal `TimeScope`                               |
| `EmbeddedVideo`/`VideoSequence`                                       | `Clip`                                             |
| raw image use, `KenBurnsImage`, `PhotoCard`, `PolaroidFrame`          | `Image` (+ `Animation.kenBurns`, `Frame.*`)        |
| `AnimatedText`, `FadeText`/`Fade`/`FadeContainer`                     | `Text` + `.animate()` (render-safe internals)      |
| `FloatingElement`                                                     | `Animation.float`                                  |
| `TypewriterText`                                                      | `Typewriter`                                       |
| `CounterText`/`DataDrivenText`                                        | `Counter`                                          |
| `AnimatedChart`                                                       | `Chart`                                            |
| `StatCard`, `Collage`                                                 | recipes (composition), not core widgets            |
| `CameraFocus`                                                         | `Scene(camera: Camera.*)`                          |
| `Loop`                                                                | `repeat:` on an `Animation`                        |
| `AudioTrack`/`AudioSource`/`BackgroundAudio`                          | `Audio.music`/`Audio.sfx`                          |
| `AudioReactive`/`BpmDetector`/`FrequencyAnalyzer`                     | `Trigger.beat()` + `Animation.*(on: AudioBand.*)`  |
| `SyncAnchor`/`SyncAnchorRegistry`                                     | internal (powers `Trigger`/`Anchor`)              |
| `EncodingConfig`                                                      | `Export.*`                                         |

Templates: keep all, rebuilt on this public API so each is also a readable example.

**New in this revision (no prior prototype equivalent):** the `Code`/`Markdown`/`Terminal`/`Mermaid`/`Snapshot`/`DeviceFrame`/`WebView`/`Html` and annotation elements (`Arrow`, `Callout`, `Connector`, `LowerThird`, `Shape`, `Spotlight`, `TitleCard`), `Bars`, the `VideoSpec` spec layer (§29), the `FluvieTokens` token system (§21), the public render entry points (§24), and the mobile/web/server rendering backends (§30).

---

## Decision log

The design choices behind the API:

| #  | Decision                              | Choice                                                        |
| -- | ------------------------------------- | ------------------------------------------------------------- |
| 1  | Default child timing                  | Elements span the whole scene; animate in / out               |
| 2  | Time syntax                           | `num` extensions: `20.frames`, `2.5.seconds`, `0.3.relative`  |
| 3  | Attachment mechanism                  | `.animate([...])` extension                                   |
| 4  | Preset architecture                   | `Keyframe` property core; presets are sugar                   |
| 5  | Triggers/anchors                      | Typed `Anchor` handles only                                   |
| 6  | Default animation duration            | Relative — 20% of window, capped at 0.8s                      |
| 7  | `relative` scope                      | Element window if set, else scene                             |
| 8  | Scene length                          | Explicit `Scene(duration:)` **and** derived `Scene.sequence`  |
| 9  | `Timeline` orchestration              | In v1                                                         |
| 10 | `FrameBuilder` escape hatch           | In v1                                                         |
| 11 | `fluvie_lints`                        | Built alongside v1                                            |
| 12 | Future features (all selected)        | Multi-aspect, templates/params, captions, theme, audio-reactive, seeded randomness, inspector+goldens, export modes |
| 13 | Hero transitions + shader `Fx`        | Both in v1                                                    |
| 14 | Image element name                    | `Image` (familiar API; deterministic loading under the hood)  |
| 15 | Property snapshot name                | `Keyframe`                                                    |
| 16 | Trigger type name                     | `Trigger`                                                     |
| 17 | Anchor handle name                    | `Anchor`                                                      |
| 18 | Motion vs Fx                          | Unified under `.animate()`; the unit is renamed `Animation`   |
| 19 | Bouncy presets                        | Spring by default                                             |
| 20 | Transition timing                     | Overlap supported **and** elements can carry across scenes    |
| 21 | `Keyframe` offset units               | Fraction of the element's own size                            |
| 22 | Default ease                          | `Ease.smooth` (ease-in-out)                                   |
| 23 | `Box` helper                          | Kept                                                          |
| 24 | Imports                               | Single barrel `package:fluvie/fluvie.dart`                    |
| 25 | Authoring as data                     | `VideoSpec` is a JSON mirror; `buildVideo` is pure; `fluvie_ai` and `fluvie_server`'s MCP emit specs |
| 26 | Rendering backends                    | One deterministic capture loop + pluggable encoders: FFmpeg process, mobile hardware, web wasm |
| 27 | Design tokens                         | `FluvieTokens` + `FluvieTokensScope` carry every token; `FluvieTheme` is brand-group sugar |
| 28 | New element families                  | Code/terminal, diagrams/web, and annotation elements added as intrinsic, frame-driven elements |

### Micro-defaults I chose for you (easy to change)

- `VideoSize.story` is an **alias** of `reels` (one canonical 1080×1920).
- Trigger parameter is named **`at:`** (`at: Trigger.after(intro)`).
- Multiple audio tracks **layer/mix** by default.
- `Animation.keyframes` stops are **evenly spaced** unless explicit `at:` times are given.
- Spring **settle threshold** drives a spring's effective duration for windowing/chaining.
