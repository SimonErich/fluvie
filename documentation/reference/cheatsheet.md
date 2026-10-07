# Cheatsheet

The whole public surface on one page. Everything here works today. Preview and
render a composition file:

```sh
fluvie preview ./lib/my_video.dart                      # live, hot-reloading
fluvie render ./lib/my_video.dart                      # build/fluvie/my_video.mp4
```

From a clone of this repo, render a lesson by its key, because the gallery keeps
a registry:

```sh
dart run packages/fluvie_cli/bin/fluvie.dart render 01_hello_video --out build/01_hello_video.mp4
```

## Time

| Literal | Meaning |
| --- | --- |
| `18.frames` | absolute frames |
| `4.seconds`, `300.ms` | absolute time, resolved at the video's fps |
| `0.3.relative` | 30 percent of the enclosing window |
| `Time.zero` | frame 0 |
| `4.seconds.to(7.seconds)` | a `TimeRange` (trims, windows) |

## Structure

| Surface | Notes |
| --- | --- |
| `Video(size:, fps:, scenes:, motionDefaults:, poster:, audio:, captions:, export:, transition:)` | the root |
| `Scene(duration:, children:, background:, motionDefaults:, audio:, camera:)` | one segment; children sit on a centered stack |
| `Scene.centered(duration:, child:)` | one-child convenience |
| `Scene.sequence(timeline:, children:)` | duration from a `TimelineSchedule` |
| `VideoSize.square / reels / story / hd / fourK` | canvas presets; `story` aliases `reels` |
| `Transition.cut / crossFade / wipe / zoom / slide` | between-scene transitions |
| `ClipTransitionGroup(children:, transitions:)` + `ElementId(id:, lane:, child:)` | native clip blends inside one scene |
| `VideoPreview.builder(builder:)` | prepared Flutter preview, controls, and hot reload |

## Motion

Every preset, with exactly what it does and its defaults, is in
[Animation presets](animation-presets.md).

| Surface | Notes |
| --- | --- |
| `widget.animate([...], anchor:, window:, defaults:)` | attach animations to any widget |
| `widget.show(from:, to:)` | bound an element to a window |
| `Animation.fadeIn / fadeOut` | opacity |
| `Animation.slideIn / slideOut / slideFadeIn / slideFadeOut` | offset, optionally with fade |
| `Animation.pop / scaleIn / scaleOut` | springy scale |
| `Animation.blurIn / blurOut` | blur |
| `Animation.color(to:)` | color lerp, consumed by color-capable elements |
| `Animation.gradientShift(to:)` | pairwise gradient lerp |
| `Animation.maskWipeIn(shape:) / maskWipeOut(shape:)` | reveal or hide with a wipe |
| `Animation.float / pulse / drift / spin / kenBurns` | ambient loops |
| `Animation.from / to / fromTo / keyframes / along / custom` | build your own |
| `Stagger.each(time) / evenly(over:) / from(origin)` | offset multi-child targets |
| `Repeat.forever(yoyo:) / times(n, gap:)` | loop inside the span |
| `Defaults(duration:, ease:, stagger:)` | cascade: element over scene over video over package |
| `Spring.gentle / snappy / bouncy / stiff`, `Ease.smooth / out / snappy / …` | timing feel |

## Pixel effects and shaders

| Surface | Notes |
| --- | --- |
| `Animation.grain / vignette / scanlines / chromatic / bloom / glitchIn / glitchOut` | post-process the rendered frame |
| `Animation.particles(spec)` | deterministic field; build with `Particles.confetti / snow / sparkle` |
| `Animation.parallax(depth:)` | scene-clock drift for parallax layers |
| `Animation.shader(asset, uniforms:)` | experimental fragment shader over the element |

## Elements

| Surface | Notes |
| --- | --- |
| `Text(...).animate([...])` | plain Flutter text plus motion |
| `Typewriter(text, speed:, caret:)` | frame-driven per-glyph reveal |
| `Counter(to:, from:, reveal:, format:)` | frame-driven number tween, `intl`-formatted |
| `Counter.currency / percent` | fixed-locale money and percentage presets |
| `Image.asset / file / memory / network(url, fit:, frame:, shared:)` | a still, pre-resolved before frame 0 |
| `Clip.asset / file / memory / network(url, trim:, audio:, fit:, speed:, shared:)` | an embedded video, pre-resolved before frame 0 |
| `ClipAudio.included(volume:, automation:, fadeIn:, fadeOut:) / muted` | a clip's audio policy, ramps anchored to its window |
| `ClipAudio.scaledBy(gain)` | multiply gain while preserving automation, fades, and mute |
| `Chart.bar / line / area / pie / donut / scatter` | data-driven charts that reveal from your data |
| `Bars(...)` | a standalone bar set |
| `Code(...) / CodeReveal(...)` | highlighted, typed code |
| `Terminal(...) / TerminalChrome / TerminalLine` | an animated terminal session |
| `Markdown(...)` | rendered Markdown |

## Annotations

| Surface | Notes |
| --- | --- |
| `Arrow / Connector / Callout` | pointers and labels |
| `Spotlight / Shape / LowerThird / TitleCard` | emphasis and titles |

## Snapshots and external sources

| Surface | Notes |
| --- | --- |
| `Snapshot(...) / DeviceFrame(...)` | a Flutter subtree rasterized once in-process, painted every frame (no service needed) |
| `Mermaid(...) / MermaidReveal(...)` | a diagram rasterized once (experimental, needs a `SnapshotService`) |
| `WebView(...) / Html(...)` | a web page or HTML rasterized once (experimental, needs a `SnapshotService`) |

## Triggers

| Surface | Notes |
| --- | --- |
| `Trigger.auto` | the phase default |
| `Trigger.at(time)` | explicit time in the window |
| `Trigger.whenEnds(a)` / `Trigger.whenStarts(a)` | react to an `Anchor` |
| `Trigger.previous` | chain off the previous animation |
| `Trigger.sceneStart` / `Trigger.sceneEnd` | scene boundaries |
| `Trigger.beat(every:, track:)` | on the analysed beat grid of an audio track |

## Backgrounds and layout

| Surface | Notes |
| --- | --- |
| `Background.color / gradient / radial / noise / vhs` | painted fills |
| `Background.image / video` | pre-resolved like `Image`/`Clip` |
| `Box(color:, size:)` | fractional-size rectangle; null size fills |
| `PhotoFrame.none / rounded / card / polaroid` | styled wrappers |
| `FadeBox(opacity:, child:)` (`package:fluvie/rendering.dart`) | render-safe opacity primitive |

## Audio and captions

| Surface | Notes |
| --- | --- |
| `Audio.music(source, volume:, fadeIn:, fadeOut:, loop:, trim:, track:)` | a music bed mixed under the frames |
| `Audio.sfx(source, at:, volume:)` | a one-shot effect fired at a trigger |
| `Audio.musicSource / sfxSource(AudioSource, ...)` | the same tracks over a typed source (`AudioSource.memory` for bytes that never touched disk) |
| `Animation.pulse(on: AudioBand.bass) / scaleY(on:)` | reactive motion, analysed before frame 0 |
| `Captions.fromSrt / fromVtt / words` | subtitle sources |
| `CaptionStyle.subtitle / tikTok / karaoke`, `CaptionPosition.bottomThird / topThird / center / custom` | look and placement |

## Theme and multi-aspect

| Surface | Notes |
| --- | --- |
| `FluvieTheme(palette:, type:, motion:, child:)` | brand a subtree |
| `Palette(bg:, accent:, onBg:, …)`, `TypeScale.fromBase(base, ratio:)` | the tokens |
| `context.fluvie.brand / type` | read tokens at the call site |
| `Adaptive(reels:, square:, landscape:, portrait45:)` | branch layout per aspect |
| `Aspect.reels / square / landscape / portrait45` | aspect families |
| `render(video, aspect:)` (`package:fluvie/rendering.dart`) | render one definition for one aspect |

## Templates

| Surface | Notes |
| --- | --- |
| `VideoTemplate` | a pure function of props, rendered per data row |
| `TitleIntro / TitleIntroProps`, `StatHighlight / StatHighlightProps` | built-in templates |
| `renderTemplate(template, props)` (`package:fluvie/rendering.dart`) | render one props row |

## Export

| Surface | Notes |
| --- | --- |
| `Export.mp4(quality:)` | H.264 MP4; `Quality.low / medium / high / max` |
| `Export.gif(fps:)` | animated GIF |
| `Export.imageSequence()` | one PNG per frame |
| `Export.transparent()` | WebM with an alpha channel |

## The CLI

| Command | Notes |
| --- | --- |
| `fluvie init [--name] [--dir] [--force]` | scaffold or merge a Flutter project; optional `--with-ai`, `--with-lints`, `--fluvie-path` |
| `fluvie preview <file.dart> [-d <device>]` | browser URL and hot reload by default; automatic native media bridge; `-d chrome` opens Chrome |
| `fluvie render <file.dart> [--out <file>]` | automatic output in `build/fluvie/`; authored export/poster/settings; `--entry`, `--no-cache`, `--aspect`, `--quality`, `--format`, `--poster`, `--frames` |
| `fluvie render <file.dart> --machine` | JSON-line progress and final artifact receipt |
| `fluvie render <key> --out <file>` | legacy registry path; `--no-cache` bypasses the cache |
| `fluvie generate "<prompt>" [--dart-out <file>] [--no-render]` | AI spec and editable native Dart, with optional capture |
| `fluvie edit <spec> "<change>" [--dart-out <file>] [--no-render]` | refine a saved spec and readable Dart |
| `fluvie doctor --json` | read-only SDK, dependency, native pair, and codec diagnostics |
| `fluvie assets [directory] --json` | recursive factual files/media/fonts/story notes; `--download-tools` explicitly warms missing tools |
| `fluvie validate <file.dart> --json` | non-executing compiler and Fluvie lint diagnostics from the original file |
| `fluvie review <file.dart> --determinism --json` | validation, mounted facts and sampled pictures; compares reverse seeks and fresh entry initialization |
| `fluvie inspect <file.dart> --json` | compile and prepare the real composition; report its resolved timing |
| `fluvie frame <file.dart> --frame <index> --json` | capture a reviewable PNG |
| `fluvie docs [page] [--context] [--json]` | installed-version offline documentation and focused authoring context |
| `fluvie list` | render keys of a registry project |
| `fluvie ffmpeg <install\|path\|status\|uninstall>` | manage the pinned FFmpeg/ffprobe pair |

`--toolchain managed` is the default; `--toolchain system` opts into PATH.
`--ffmpeg`, `--ffprobe`, and `--no-download` select native tools explicitly.
Render hosts can use `--renderer <file>` with `--renderer-entry <factory>`, or a
complete custom `--harness <file>`; ordinary authoring needs neither.

A composition file exposes a top-level `Video build()`; `--entry <name>` names
another.

## Hosting a render

| Surface | Notes |
| --- | --- |
| `renderVideo(video:, outDir:, pumpWidget:, pumpFrame:, setViewSize:)` (`package:fluvie/rendering.dart`) | the one capture entry a host drives; derives geometry, media, audio, captions from the `Video` |
| `runFluvieRender`, `RenderInvocation`, `RenderHostContext` | package-owned prepared host and optional renderer factory |
| `runAsyncDirectly`, `SetViewSize`, `ShellRunAsync` | the host seams `renderVideo` takes |
| `parseAspect / parseQuality / parseExportFormat / parsePosterTime` | CLI define strings to typed arguments |
| `writeRenderProgress(file, completed, total)` | the progress file a supervising process polls |

## Escape hatches and diagnostics

| Surface | Notes |
| --- | --- |
| `FrameBuilder((ctx) => …)` | experimental frame-clock builder when no preset fits |
| `Timeline()` (experimental) | GSAP-style builder; `play` / `playAll` / `wait` / `label`, `at:` takes a `Trigger` / label |
| `TimelineProbe` + `TimelineProbeScope` | mount above a `Video` to receive its `ResolvedTimeline` |
| `debugTimeline(timeline)` | a fixed-width text table of every animation |
| `InspectorModel.fromTimeline(...)` | the inspector's value model: motions, anchors, warnings |
| `printVideoSpecJson(Map)` (`package:fluvie_cli`, experimental) | turn a `VideoSpec` into an editable `Video build()` snippet; pure, no model, no render |

## Where to next

- [Core concepts](../getting-started/core-concepts.md): the ideas behind the
  tables above.
- [Animating elements](../guides/animating-elements.md): the motion list in
  depth.
- [Animation presets](animation-presets.md): every preset, with exactly what
  each one does.
- [Migration](migration.md): old names mapped to the surface above.
