# Cheatsheet

The whole public surface on one page. Everything here works today. Render any
registered composition from the repo root:

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
| `Transition.crossFade / slide / wipe` | between-scene transitions |

## Motion

| Surface | Notes |
| --- | --- |
| `widget.animate([...], anchor:, window:, defaults:)` | attach animations to any widget |
| `widget.show(from:, to:)` | bound an element to a window |
| `Animation.fadeIn / fadeOut` | opacity |
| `Animation.slideIn / slideOut / slideFade` | offset, optionally with fade |
| `Animation.pop / scaleIn` | springy scale |
| `Animation.blurIn / blurOut` | blur |
| `Animation.color(to:)` | color lerp, consumed by color-capable elements |
| `Animation.gradientShift(to:)` | pairwise gradient lerp |
| `Animation.maskWipe(shape:)` | reveal wipe |
| `Animation.float / pulse / drift / spin / kenBurns` | ambient loops |
| `Animation.from / to / fromTo / keyframes / along / custom` | build your own |
| `Stagger.each(time) / evenly(over:) / from(origin)` | offset multi-child targets |
| `Repeat.forever(yoyo:) / times(n, gap:)` | loop inside the span |
| `Defaults(duration:, ease:, stagger:)` | cascade: element over scene over video over package |
| `Spring.gentle / snappy / bouncy`, `Ease.smooth / out / snappy / …` | timing feel |

## Pixel effects and shaders

| Surface | Notes |
| --- | --- |
| `Animation.grain / vignette / scanlines / chromatic / bloom / glitchIn` | post-process the rendered frame |
| `Animation.particles(spec)` | deterministic field; build with `Particles.confetti / snow / sparkle` |
| `Animation.parallax(depth:)` | scene-clock drift for parallax layers |
| `Animation.shader(asset, uniforms:)` | experimental fragment shader over the element |

## Elements

| Surface | Notes |
| --- | --- |
| `Text(...).animate([...])` | plain Flutter text plus motion |
| `Typewriter(text, speed:, caret:)` | frame-driven per-glyph reveal |
| `Counter(to:, from:, duration:, format:)` | frame-driven number tween, `intl`-formatted |
| `Counter.currency / percent` | fixed-locale money and percentage presets |
| `Image.asset / file / memory / network(url, fit:, frame:, shared:)` | a still, pre-resolved before frame 0 |
| `Clip.asset / network(url, trim:, audio:, fit:, shared:)` | an embedded video |
| `ClipAudio.included / muted` | a clip's audio policy |
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
| `Trigger.after(a)` / `Trigger.whenStarts(a)` | react to an `Anchor` |
| `Trigger.previous` | chain off the previous animation |
| `Trigger.sceneStart` / `Trigger.sceneEnd` | scene boundaries |
| `Trigger.beat(every:, track:)` | on the analysed beat grid of an audio track |

## Backgrounds and layout

| Surface | Notes |
| --- | --- |
| `Background.color / gradient / radial / noise / vhs` | painted fills |
| `Background.image / video` | pre-resolved like `Image`/`Clip` |
| `Box(color:, size:)` | fractional-size rectangle; null size fills |
| `Frame.none / rounded / card / polaroid` | styled wrappers |
| `FadeBox(opacity:, child:)` | render-safe opacity primitive |

## Audio and captions

| Surface | Notes |
| --- | --- |
| `Audio.music(source, volume:, fadeIn:, fadeOut:, loop:, trim:, track:)` | a music bed mixed under the frames |
| `Audio.sfx(source, at:, volume:)` | a one-shot effect fired at a trigger |
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
| `render(video, aspect:)` | render one definition for one aspect |

## Templates

| Surface | Notes |
| --- | --- |
| `VideoTemplate` | a pure function of props, rendered per data row |
| `TitleIntro / TitleIntroProps`, `StatHighlight / StatHighlightProps` | built-in templates |
| `renderTemplate(template, props)` | render one props row |

## Export

| Surface | Notes |
| --- | --- |
| `Export.mp4(quality:)` | H.264 MP4; `Quality.low / medium / high / max` |
| `Export.gif(fps:)` | animated GIF |
| `Export.imageSequence()` | one PNG per frame |
| `Export.transparent()` | WebM with an alpha channel |

## Escape hatches and diagnostics

| Surface | Notes |
| --- | --- |
| `FrameBuilder((ctx) => …)` | experimental frame-clock builder when no preset fits |
| `Timeline()` (experimental) | GSAP-style builder; `play` / `playAll` / `wait` / `label`, `at:` takes a `Trigger` / label |
| `TimelineProbe` + `TimelineProbeScope` | mount above a `Video` to receive its `ResolvedTimeline` |
| `debugTimeline(timeline)` | a fixed-width text table of every animation |
| `InspectorModel.fromTimeline(...)` | the inspector's value model: motions, anchors, warnings |

## Where to next

- [Core concepts](../getting-started/core-concepts.md): the ideas behind the
  tables above.
- [Animating elements](../guides/animating-elements.md): the motion list in
  depth.
- [Migration](migration.md): old names mapped to the surface above.
