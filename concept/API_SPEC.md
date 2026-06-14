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
29. [Consolidation map (old → new)](#29-consolidation-map)
30. [Decision log](#decision-log)

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
Animation.keyframes(List<Keyframe> stops, {List<Curve>? easings, List<Time>? at})
Animation.along(Path path, {bool orient = true})   // travel a path
Animation.custom(AnimationEffect effect)           // your own effect
```

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
Animation.pulse({double min = 0.97, double max = 1.03})
Animation.drift({Edge to = Edge.right, double distance = 0.1})
Animation.kenBurns({double zoom = 1.15, Edge pan = Edge.left})
Animation.spin({Time per = const Time.seconds(4)})
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
class Animation {
  final AnimationEffect effect;   // built-in or custom
  final AnimationPhase phase;     // enter | exit | during  (inferred: from→enter, to→exit, continuous→during)
  final Timing timing;            // Tween(duration+ease)  XOR  Spring(...)   — see §9
  final Time delay;               // default: Time.zero
  final Trigger at;               // default: Trigger.auto (the element's own window edge)
  final Stagger? stagger;         // distribute across a multi-child target
  final Repeat? repeat;           // see below
  final String? label;            // name THIS animation so others can chain off it
}

Repeat.times(int n, {bool yoyo = false, Time gap = Time.zero})
Repeat.forever({bool yoyo = false})
```

Most calls only touch `duration`, `delay`, `at`, and maybe `stagger` — everything else defaults.

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

An element can persist and morph across a cut. Give the same `Anchor` to an element in both scenes via
`shared:`, and Fluvie tweens its position/size/opacity between them:

```dart
final logo = Anchor('logo');

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

```dart
Chart.bar(data: {'Jan': 30, 'Feb': 45, 'Mar': 80},
  growIn: 0.6.relative, stagger: Stagger.each(0.06.seconds));
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
  captions: Captions.fromSrt('en.srt', style: CaptionStyle.tikTok(), position: Align.thirds.bottom),
  scenes: [...],
);

Captions.fromVtt('en.vtt');
Captions.words([CaptionWord('Hello', at: 0.0.seconds), CaptionWord('world', at: 0.4.seconds)]);

CaptionStyle.tikTok()   CaptionStyle.subtitle()   CaptionStyle.karaoke()
```

---

## 18. Audio & audio-reactive

Audio on `Video` or `Scene`; multiple tracks layer/mix. Beat-reactivity is a `Trigger`; spectrum-reactivity
is an animation input.

```dart
Video(
  audio: [Audio.music('song.mp3', volume: 0.8, fadeIn: 1.seconds, fadeOut: 1.seconds, track: beat)],
  scenes: [
    Scene(duration: 8.seconds, children: [
      Text('On the beat').animate([Animation.pop(at: Trigger.beat(every: 1, track: beat))]),
      Bars(count: 24).animate([Animation.scaleY(on: AudioBand.bass, gain: 1.5)]),  // spectrum bars
    ]),
  ],
);

Audio.music(path, {volume, fadeIn, fadeOut, loop, trim, track})
Audio.sfx(path, {at, volume})        // one-shot anchored to a Trigger
```

(`beat` is an `Anchor` naming the track. `AudioBand.bass|mid|treble` drives reactive animations.)

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

`ctx` exposes `frame`, `progress`, `fps`, `scope` (start/duration), `audio(anchor)`, and `noise(seed)` (§22).

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

---

## 22. Reproducible randomness

Organic motion that's still deterministic across frames, machines, and re-renders (so caching and goldens
work). A lint forbids `dart:math Random()` in render code.

```dart
final n = ctx.noise('petal-$i');                 // stable per seed
Animation.float(amplitude: 0.04, seed: 'leaf-7'); // organic but reproducible
```

---

## 23. Multi-aspect & templates

### One definition, many aspect ratios

```dart
Adaptive(
  reels:     () => Column(children: [...]),   // vertical
  square:    () => Row(children: [...]),       // side by side
  landscape: () => Row(children: [...]),
);

await render(video, aspect: Aspect.square);
await render(video, aspect: Aspect.reels);
// any element can branch: Aspect.of(context)
```

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

Combined with reproducible rendering (§22), identical props → identical bytes → cacheable.

---

## 24. Export

```dart
Export.mp4(quality: Quality.high)
Export.gif(fps: 15)
Export.imageSequence(format: ImageFormat.png)   // compositing pipelines
Export.transparent()                            // alpha (WebM/ProRes) for overlays
Video(poster: 1.seconds);                       // thumbnail frame
```

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

### 27.7 Determinism

`Image`/`Clip` sources are pre-resolved and cached by content hash before capture; randomness is seeded
(§22). Identical input → identical frames → safe to cache and to golden-test.

### 27.8 Why complexity here is the right trade

The renderer runs on capable devices and isn't a hot path, so Fluvie spends complexity internally — a
timing graph, nested scopes, a resolver, a render pipeline — to keep the call site free of frame numbers
and arithmetic.

---

## 28. Tooling

### `fluvie_lints` (built alongside v1, on `custom_lint`)

Editor squiggles + `dart analyze` failures, with quick-fixes where possible:

- `dangling_anchor` — a `Trigger` references an `Anchor` never attached (or out of scope).
- `cyclic_trigger` — A waits for B waits for A.
- `animation_exceeds_window` — resolved duration longer than its window.
- `conflicting_keyframe_fields` — two animations write the same `Keyframe` field over the same time.
- `relative_outside_scope` — `0.x.relative` where no enclosing duration exists.
- `unused_anchor` — declared, never referenced.
- `nondeterministic_random` — `dart:math Random()` in render code.
- `deprecated_member` — drives migration from old names with quick-fixes (e.g. `KenBurnsImage` → `Image` + `Animation.kenBurns`).

Annotations: `@useResult` on `.animate()`/`.show()`; `@Deprecated(...)` on renamed members; `@experimental`
on `Timeline`/`FrameBuilder`/shader `Animation`s.

### Inspector & tests

```dart
debugTimeline(video);   // prints a resolved table: element | window | animation | start | end
testFrame(video, at: 2.seconds, matchesGolden('frames/intro_60.png'));
```

Both build on the same resolver Fluvie already runs — and a scrubbable live inspector is the natural next
step (Fluvie's answer to Remotion Studio).

---

## 29. Consolidation map (old → new)

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

### Micro-defaults I chose for you (easy to change)

- `VideoSize.story` is an **alias** of `reels` (one canonical 1080×1920).
- Trigger parameter is named **`at:`** (`at: Trigger.after(intro)`).
- Multiple audio tracks **layer/mix** by default.
- `Animation.keyframes` stops are **evenly spaced** unless explicit `at:` times are given.
- Spring **settle threshold** drives a spring's effective duration for windowing/chaining.
