# Migration

Fluvie used to spread motion, effects, and layout across many widgets. The v1
surface consolidates them. There is now one motion type (`Animation`), one
attachment (`.animate([...])`), and plain Flutter layout. This page maps each
old name to its replacement.

## 0.2.x to 0.3.x

The `Video` and `Scene` authoring model remains familiar. The CLI now owns the
preview and render support around that composition, with additional native APIs
for clip transitions and clip-audio gain.

A composition can live in an ordinary Flutter application or a smaller project
holding a composition file, an `assets/` folder, and a `pubspec.yaml`. Neither a
capture harness nor a registry is required. `fluvie render` and `fluvie preview`
take the `.dart` file directly and prepare their package-owned support.

### Your existing project still works

`resolveProjectDir` still finds a project by its pubspec, and the legacy
`fluvie render <key> --out <file>` registry path remains available. `fluvie list`
still prints your keys. Moving to file targets is optional.

### The recommended path

Render the composition file directly. For a project that looks like the 0.2
scaffold:

1. **Keep the composition in `lib/`** (or anywhere you like) and rename its builder
   to `build`:

   <!-- code-excerpt-ignore: a before/after of one signature, not a runnable composition -->
   ```dart
   // lib/videos/intro.dart
   Video intro() { ... }     // before
   Video build() { ... }     // after
   ```

   Keep the old name if you prefer, and pass `--entry intro` on every render and
   preview instead.

2. **Retire rendering-only boilerplate.** The CLI supplies its own external
   capture harness, so a legacy capture test and composition registry are no
   longer required. Remove them only if nothing else uses them. An existing
   Flutter application's `lib/main.dart` and application tests remain useful;
   keep them when Fluvie is one feature of that app.

3. **Render the file:**

   ```sh
   fluvie render ./lib/intro.dart --out intro.mp4
   fluvie preview ./lib/intro.dart
   ```

4. **Keep media under `assets/`** for automatic nested discovery. Preserve
   existing Flutter asset and font declarations. A normal Flutter `assets/`
   entry is not recursive, so Fluvie discovers subdirectories when preparing
   rendering resources without replacing unrelated application assets.

5. **Drop the platform directories** (`android/`, `ios/`, `linux/`, `macos/`,
   `windows/`, `web/`) if the project existed only to render. `fluvie preview`
   generates and caches its own app in `~/.cache/fluvie/preview/`, outside your
   project.

### What to know afterwards

- **The frame cache is on by default for a file target.** The CLI fingerprints
  source code, resolved package code, project configuration, declared and
  discovered assets, render options, and toolchain identity before reusing
  frames. Use `--no-cache` for resources whose bytes can change outside those
  inputs, such as a runtime network request.
- **`fluvie init` merges into an existing Flutter project.** `--with-ai` and
  `--with-lints` add optional packages; `--fluvie-path` selects a local checkout.
  `--name`, `--dir`, and `--force` remain available. `--path`,
  `--render` / `--no-render`, and `--yes` / `-y` are gone. It is no longer
  interactive and it no longer runs `flutter create`, so there is nothing to say
  yes to.
- **`fluvie preview` starts a browser URL by default.** Its local FFmpeg bridge
  decodes source clips and audio, including ProRes alpha and WebM. Pass
  `-d chrome` to open Chrome, or select an installed desktop device explicitly.
- **`runFluvieRender` owns the CLI capture host.** A normal Dart entry needs no
  consumer harness. Advanced hosts can call it directly; `renderVideo` remains
  the lower level composition render entry for a custom integration.
  See [the rendering surface](rendering-surface.md).
- **`RENDER_PROJECT` now means a Fluvie project**, a pubspec that depends on
  `fluvie`, rather than a project containing `test/render/capture_harness_test.dart`.
  See [Rendering on a server](../guides/rendering-on-a-server.md).

New in 0.3.0, not a rename: WebM/VP9 clips work, including alpha. See
[Images and video clips](../guides/images-and-video-clips.md).

## 0.1.x to 0.2.0

Version 0.2.0 renames hard: the old names are gone, not deprecated. Every
change below is mechanical.

| 0.1.x | 0.2.0 |
| --- | --- |
| Pipeline exports on `package:fluvie/fluvie.dart` (`RenderService`, `RenderConfig`, `render`, `renderToSandbox`, `renderTemplate`, sandboxes, capture services, resolver contracts, `resolveAudioMix`, collectors, `FadeBox`, `FfmpegVersion`, the wasm runtime) | Import `package:fluvie/rendering.dart`. See [the rendering surface](rendering-surface.md) |
| `NumberFormat` re-exported from the barrel | Import `package:intl/intl.dart` yourself |
| `FfmpegProvider`, `ProcessFfmpegProvider`, `WasmFfmpegProvider`, `ffmpegProviderProvider` | `FfmpegRunner`; the platform runner is selected for you through `ffmpegRunnerProvider` (backed by `FfmpegRunnerRegistry`), all on the rendering barrel |
| `RenderService.render(provider:)` | `RenderService.render(runner:)` |
| `Trigger.after(a)` (and the JSON trigger kind `"after"`) | `Trigger.whenEnds(a)` / `"whenEnds"`, the parallel twin of `Trigger.whenStarts(a)`; old specs fail with a rename hint |
| `Chart.bar(growIn:)`, `Chart.line/area(drawIn:)`, `Chart.pie/donut(sweepIn:)`, `Chart.scatter(popIn:)` | `reveal:` on every chart: one word for "how long the built-in reveal takes" |
| `Counter(duration:)` (and the Counter spec prop `"duration"`) | `Counter(reveal:)` / `"reveal"` |
| `Arrow(drawIn:)`, `Shape(drawIn:)`, `Connector(drawIn:)`, `LowerThird(slideIn:)` | `reveal:` (annotations share the same word) |
| `Animation.slideFade(...)` (and the spec preset `"slideFade"`) | `Animation.slideFadeIn(...)` / `"slideFadeIn"`; a new `slideFadeOut` mirrors it |
| `Animation.maskWipe(...)` | `Animation.maskWipeIn(...)`; a new `maskWipeOut` mirrors it |
| `Animation.spin(per:)` (and the spec arg `"per"`) | `Animation.spin(period:)` / `"period"` |
| `Animation.float(frequency: 0.4)` (cycles per second) | `Animation.float(period: 2.5.seconds)` (one bob per period) |
| `Timeline(fps: 30)` | `Timeline()`: the timeline resolves at the enclosing `Video`'s fps, so a 60 fps video can no longer silently mistime a schedule; `timeline.placements` becomes `placementsAt(fps)` |
| `Frame.polaroid/card/rounded/none` (the decorative photo mat) | `PhotoFrame.*`: "Frame" now always means the render clock (`FrameBuilder`, `n.frames`, `RawFrame`) |

New preset mirrors in 0.2.0: `scaleOut`, `glitchOut`, `slideFadeOut`, and
`maskWipeOut` complete every directional pair, so guessing the `*Out` twin of
an `*In` preset now always works.

The authoring surface (`Video`, `Scene`, elements, `Animation`, `Trigger`,
themes, specs, the preview runtime) stays on `package:fluvie/fluvie.dart`.

New in 0.2.0, not a rename: the `VideoRenderer<T>` contract unifies the render
entry points. `DesktopVideoRenderer` (local FFmpeg, returns a `File`),
`OnDeviceVideoRenderer` (mobile hardware encoder, returns a `File`), and
`WebVideoRenderer` (ffmpeg.wasm, returns bytes) all implement it, so the same
call shape renders on every platform.

Most renames are mechanical. Here is the most common one, an animated text line,
before and after:

<!-- code-excerpt-ignore: the old AnimatedText API predates v1 and no longer compiles -->
```dart
// old
AnimatedText('Hello', animation: EntryAnimation.slideFade());
```

<!-- code-excerpt "examples/gallery/lib/snippets/migration_snippets.dart (migrate-animate)" -->
```dart
const Text('Hello', style: _line).animate([Animation.slideFadeIn()]);
```

The `deprecated_member` lint flags many of the old type names in your code and
offers a rename quick-fix for each name it knows. It does not cover the parameter
renames or every name below, so read the rest by hand. Each section that follows
maps one row of the consolidation table.

## Animations become one type

The old motion widgets (`PropAnimation`, `EntryAnimation`, `AmbientAnimation`,
`SlideIn`, and a scene transition used as an animation) are now `Animation.*`
presets, or `Animation.from` / `Animation.to` / `Animation.keyframes` for custom
motion.

`AnimatedProp` becomes the `.animate([...])` extension on any widget:

<!-- code-excerpt-ignore: the old AnimatedProp API predates v1 and no longer compiles -->
```dart
// old
AnimatedProp(animation: PropAnimation.fade(), child: Text('Hi'));
```

<!-- code-excerpt "examples/gallery/lib/snippets/migration_snippets.dart (migrate-animate)" -->
```dart
const Text('Hello', style: _line).animate([Animation.slideFadeIn()]);
```

See [Animating elements](../guides/animating-elements.md) for the full preset
menu.

## Stagger moves onto the animation

The `Stagger` widget and `StaggerConfig` are gone. Pass a `stagger:` on the
animation that plays across the group:

<!-- code-excerpt-ignore: the old Stagger widget predates v1 and no longer compiles -->
```dart
// old
Stagger(config: StaggerConfig(each: 0.1.seconds), children: [...]);
```

<!-- code-excerpt "examples/gallery/lib/snippets/migration_snippets.dart (migrate-stagger)" -->
```dart
const Column(children: [Text('A'), Text('B')]).animate([
  Animation.fadeIn(stagger: const Stagger.each(Time.frames(6))),
]);
```

## Effects join the animate list

`EffectOverlay`, `ParticleEffect`, `MaskedClip`, and `ParallaxLayer` are gone.
The pixel post-effects (`grain`, `vignette`, `particles`, `shader`, `maskWipeIn`,
and the rest) sit in the same `.animate([...])` list as everything else:

<!-- code-excerpt-ignore: the old EffectOverlay API predates v1 and no longer compiles -->
```dart
// old
EffectOverlay(effects: [ParticleEffect.confetti()], child: card);
```

<!-- code-excerpt "examples/gallery/lib/snippets/migration_snippets.dart (migrate-effects)" -->
```dart
const ColoredBox(color: Color(0xFF13131F)).animate([
  Animation.grain(0.12),
  Animation.vignette(0.4),
]);
```

See [Shaders and effects](../advanced/shaders-and-effects.md).

## Layout is plain Flutter

The `V`-prefixed wrappers (`VStack`, `VColumn`, `VRow`, `VCenter`, `VPadding`,
`VPositioned`, `VSizedBox`) are gone. Use the real Flutter widgets:

<!-- code-excerpt-ignore: the old V-prefixed layout widgets predate v1 and no longer compile -->
```dart
// old
VColumn(children: [VCenter(child: text)]);
```

<!-- code-excerpt "examples/gallery/lib/snippets/migration_snippets.dart (migrate-layout)" -->
```dart
const Column(
  children: [
    Text('Plain Flutter', style: _line),
    Text('Row, Column, Stack, Center', style: _line),
  ],
);
```

`LayerStack`, `Layer`, and `VideoTimingMixin` had no public replacement; their
job is now the internal `TimeScope`. See [Layouts](../guides/layouts.md).

## Images, clips, and frames

Raw image use, `KenBurnsImage`, `PhotoCard`, and `PolaroidFrame` collapse into
one `Image` plus `Animation.kenBurns` and the `PhotoFrame.*` styles:

<!-- code-excerpt-ignore: the old KenBurnsImage/PolaroidFrame APIs predate v1 and no longer compile -->
```dart
// old
PolaroidFrame(child: KenBurnsImage.network(url));
```

<!-- code-excerpt "examples/gallery/lib/snippets/migration_snippets.dart (migrate-image)" -->
```dart
PhotoFrame.polaroid(
  child: Image.network(url, fit: BoxFit.cover).animate([Animation.kenBurns()]),
);
```

`EmbeddedVideo` and `VideoSequence` become one `Clip`:

<!-- code-excerpt-ignore: the old EmbeddedVideo API predates v1 and no longer compiles -->
```dart
// old
EmbeddedVideo.network(url, muted: true);
```

<!-- code-excerpt "examples/gallery/lib/snippets/migration_snippets.dart (migrate-clip)" -->
```dart
Clip.network(url, audio: const ClipAudio.muted(), fit: BoxFit.cover);
```

See [Images and video clips](../guides/images-and-video-clips.md).

## Text and counters

`AnimatedText`, `FadeText`, `Fade`, and `FadeContainer` become a plain `Text`
plus `.animate()`. `TypewriterText` becomes `Typewriter`. `CounterText` and
`DataDrivenText` become `Counter`. `FloatingElement` becomes `Animation.float`.
See [Text and typography](../guides/text-and-typography.md).

## Charts, cards, and the camera

`AnimatedChart` becomes `Chart`. `StatCard` and `Collage` are no longer core
widgets; they are recipes you compose from the public API (the built-in
templates show how). `CameraFocus` moves onto the scene as
`Scene(camera: Camera.*)`. See [Charts and data](../guides/charts-and-data.md).

## Repeat, audio, and export

`Loop` becomes a `repeat:` on the animation:

<!-- code-excerpt-ignore: the old Loop widget predates v1 and no longer compiles -->
```dart
// old
Loop(child: spinner);
```

<!-- code-excerpt "examples/gallery/lib/snippets/migration_snippets.dart (migrate-loop)" -->
```dart
const Text('Spinning', style: _line).animate([
  Animation.spin(repeat: const Repeat.forever()),
]);
```

`AudioTrack`, `AudioSource`, and `BackgroundAudio` become `Audio.music` and
`Audio.sfx`:

<!-- code-excerpt-ignore: the old AudioTrack API predates v1 and no longer compiles -->
```dart
// old
BackgroundAudio(AudioTrack.asset(path));
```

<!-- code-excerpt "examples/gallery/lib/snippets/migration_snippets.dart (migrate-audio)" -->
```dart
Audio.music(path, fadeOut: const Time.seconds(0.5)),
```

`AudioReactive`, `BpmDetector`, and `FrequencyAnalyzer` become `Trigger.beat()`
plus the reactive presets (`Animation.pulse(on: AudioBand.bass)` and
`Animation.scaleY`). `EncodingConfig` becomes `Export.*`:

<!-- code-excerpt-ignore: the old EncodingConfig API predates v1 and no longer compiles -->
```dart
// old
EncodingConfig(crf: 14);
```

<!-- code-excerpt "examples/gallery/lib/snippets/migration_snippets.dart (migrate-export)" -->
```dart
const Export.mp4(quality: Quality.max);
```

See [Audio and captions](../guides/audio-and-captions.md) and
[Exporting your video](../guides/exporting-your-video.md).

## Anchors are internal now

`SyncAnchor` and `SyncAnchorRegistry` are gone from the public surface. They
power `Trigger` and `Anchor` from the inside. Name a moment with an `Anchor` and
react to it with a `Trigger`. See [Timing and triggers](../guides/timing-and-triggers.md).

## Where to next

- [Animating elements](../guides/animating-elements.md): the one motion list
  that most renames lead to.
- [Cheatsheet](cheatsheet.md): the full v1 surface on one page.
- [FAQ](faq.md): the questions a new user asks first.
