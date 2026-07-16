# Migration

Fluvie used to spread motion, effects, and layout across many widgets. The v1
surface consolidates them. There is now one motion type (`Animation`), one
attachment (`.animate([...])`), and plain Flutter layout. This page maps each
old name to its replacement.

## 0.2.x to 0.3.0

Nothing in the authoring surface changed. A `Video` you wrote for 0.2 builds
unchanged in 0.3. What changed is the shape of a project around it.

A Fluvie project is now a directory holding a composition file, an `assets/`
folder, and a `pubspec.yaml`. There is no app, no `lib/main.dart`, no capture
harness, and no registry. `fluvie render` and `fluvie preview` take the `.dart`
file directly and generate whatever they need, per invocation.

### Your existing project still works

Nothing breaks on upgrade. `resolveProjectDir` still finds a project by its
pubspec, and `fluvie render <key> --out <file>` is unchanged, so your committed
harness and registry keep rendering exactly as they did. `fluvie list` still
prints your keys. You can stop here.

### The recommended path

Delete the machinery and render the file. For a project that looks like the 0.2
scaffold:

1. **Move the composition to the project root** (or anywhere you like) and rename
   its builder to `build`:

   <!-- code-excerpt-ignore: a before/after of one signature, not a runnable composition -->
   ```dart
   // lib/videos/intro.dart  ->  intro.dart
   Video intro() { ... }     // before
   Video build() { ... }     // after
   ```

   Keep the old name if you prefer, and pass `--entry intro` on every render and
   preview instead.

2. **Delete the three files you no longer own:**

   ```sh
   rm test/render/capture_harness_test.dart   # the CLI generates one per render
   rm lib/main.dart                           # `fluvie preview` replaces the app
   rm lib/videos/compositions.dart            # or wherever your registry lives
   ```

   Delete the widget test that pumped the app, too, if it only existed to prove
   the app booted.

3. **Render the file:**

   ```sh
   fluvie render ./lib/intro.dart --out intro.mp4
   fluvie preview ./lib/intro.dart
   ```

4. **Move your media under `assets/`** and drop the `flutter: assets:` block from
   your pubspec. The CLI re-derives it from the asset tree on every render and
   preview. It enumerates every subdirectory that holds files, which a
   hand-written `assets/` entry does not: Flutter bundles a declared asset
   directory non-recursively, so `assets/images/logo.png` was silently missing at
   runtime unless you declared `assets/images/` yourself.

5. **Drop the platform directories** (`android/`, `ios/`, `linux/`, `macos/`,
   `windows/`, `web/`) if the project existed only to render. `fluvie preview`
   generates and caches its own app in `~/.cache/fluvie/preview/`, outside your
   project.

### What to know afterwards

- **The frame cache is off by default for a file target.** The render digest keys
  on the config and the composition key, never on the composition itself, so an
  edited file with the same size and frame count would replay stale frames. Pass
  `--cache` to opt in. On the key path the cache is still on, and `--no-cache`
  still bypasses it.
- **`fluvie init` takes only `--name`, `--dir`, and `--force`.** `--path`,
  `--render` / `--no-render`, and `--yes` / `-y` are gone. It is no longer
  interactive and it no longer runs `flutter create`, so there is nothing to say
  yes to.
- **`fluvie preview` defaults to your desktop, not the browser.** A desktop
  preview decodes any clip through FFmpeg; a browser is limited to what WebCodecs
  supports, and ProRes is not on that list. Pass `-d chrome` for the browser.
- **`renderVideo` is the entry point if you host renders yourself.** It replaces
  hand-assembling the capture shell, the media pre-pass, and the audio staging.
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
