# Diagrams and web pages

Draw a Mermaid diagram, render a web page, or rasterize any Flutter subtree, then
paint the result as a still in your video. Each of these elements turns into one
decoded image before frame 0 and the same image paints every frame:

<!-- code-excerpt "examples/gallery/lib/lessons/09_diagrams_and_webviews.dart (mermaid)" -->
```dart
child: const Mermaid(
  _flow,
  theme: MermaidTheme.dark(),
  reveal: MermaidReveal.drawEdges(Time.seconds(1)),
).animate([Animation.slideFadeIn()]),
```

That lays out the Mermaid source, rasterizes it to one image, and draws the
edges in over one second while `.animate()` slides and fades the whole diagram.
Lesson 09 builds the full three-scene explainer.

## The rule: rasterize once, paint every frame

This is the headline for every element on this page. A diagram, a web page, or a
subtree is rasterized once, before frame 0, into a decoded image. That image is
cached by content hash and painted synchronously on every frame after. The frame
loop never runs a live browser or a live platform view.

This is what keeps a snapshot stable across the render. The same source produces
the same image, and that image paints the same on frame 0 and frame 200. A
snapshot is just another resolved media, so it caches and goldens like an
`Image` or a `Clip`.

Because resolution happens before the frame loop, the diagram or page is present
from the first frame. There is no async pop-in. A reveal animation runs over the
already-rendered raster, not over the act of rendering it.

## What works today

`Snapshot`, `DeviceFrame`, and the full rasterize-once API work now.
Live Mermaid and live web rasterization need a renderer that is not wired in this
version yet. See [The live renderer is experimental](#the-live-renderer-is-experimental)
below for the exact state and how to supply your own. Read this page top to
bottom: the API is final, and the parts that need a renderer are called out where
they apply.

## Snapshot

`Snapshot(child)` rasterizes a Flutter subtree to one image, in process, with no
browser. This path is fully deterministic and runs in the gate today.

<!-- code-excerpt "examples/gallery/lib/snippets/phase_13_snippets.dart (snapshot)" -->
```dart
Snapshot(
  child: Center(
    child: Container(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF1E2A36),
      child: const Text('rasterized once'),
    ),
  ),
);
```

Fluvie wraps the child in a hidden boundary, captures it once before frame 0,
and paints the cached image on every frame. In preview the child renders live so
you can iterate, then capture takes over at render time. Use `Snapshot` to freeze
an expensive or non-deterministic subtree into one stable image.

## Mermaid

`Mermaid(source, {theme, reveal})` takes the diagram source as its first
argument. The source string is the only required input:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_13_snippets.dart (mermaid)" -->
```dart
const Mermaid('graph LR; A --> B; B --> C;');
```

### Theming

Pass a `MermaidTheme` to `theme`. Two presets ship:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_13_snippets.dart (mermaid-theme)" -->
```dart
Mermaid(source, theme: const MermaidTheme.dark()),
Mermaid(source, theme: const MermaidTheme.light()),
```

The theme feeds the content hash, so a dark diagram and a light diagram from the
same source rasterize to two distinct cached images. With no `theme` the diagram
reads `context.fluvie.mermaid`, the inherited token theme. A `theme:` override
wins over the inherited one for that element.

### The staged reveal

`reveal` is a `MermaidReveal` and has three modes:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_13_snippets.dart (mermaid-reveal)" -->
```dart
Mermaid(src, reveal: MermaidReveal.none), // the whole diagram at once (default)
Mermaid(src, reveal: MermaidReveal.fadeNodes(1.seconds)), // nodes fade in over the window
Mermaid(src, reveal: MermaidReveal.drawEdges(1.seconds)), // edges draw on over the window
```

The reveal carries a `Time` that resolves against the element window, so a
relative time scales with the scene. The reveal drives per-frame opacity or a
clip over the single rendered raster. It does not re-rasterize the diagram per
frame, so a 4 second reveal costs the same as no reveal at render time.

## WebView and Html

`Html(source, {viewport})` renders an HTML string to one image at a fixed
viewport. `WebView.url(uri, {viewport, scroll, clip})` does the same for a URL:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_13_snippets.dart (webview)" -->
```dart
Html('<h1>fluvie.dev</h1>', viewport: const SnapshotViewport(width: 720, height: 405)),
WebView.url('https://fluvie.dev', viewport: const SnapshotViewport(width: 1280, height: 720)),
```

`SnapshotViewport` fixes the layout box in logical pixels (`width`, `height`, and
`deviceScale`, which defaults to `1.0`). A fixed viewport is what makes the
raster deterministic: the same page laid out in the same box produces the same
image. `WebView.url` also takes an optional `scroll` (an `Offset`) and
`clip` (a `Rect`) to capture part of a tall page.

Every `WebView.url` host passes through the network allowlist before any
navigation. A host that is not on the allowlist throws a `FluvieRenderException`
during resolution, so a render never reaches out to an address you did not
permit.

## DeviceFrame

`DeviceFrame.phone({child})`, `DeviceFrame.browser({child})`, and
`DeviceFrame.tablet({child})` wrap any child in presentational chrome: a phone
bezel and notch, a browser address bar and traffic lights, or a tablet bezel.
The frame draws no raster and runs no service. It composes over any child,
including a snapshot:

<!-- code-excerpt "examples/gallery/lib/lessons/09_diagrams_and_webviews.dart (browser)" -->
```dart
child: const DeviceFrame.browser(
  url: 'https://fluvie.dev',
  child: SizedBox.expand(child: Html(_page, viewport: _viewport)),
).animate([Animation.slideFadeIn()]),
```

That captures the inline HTML to a raster, paints it inside a browser window with
the URL in the address bar, and slides the framed page in. `DeviceFrame.browser`
takes an optional `url:` string for the address bar. The chrome colors come from
`context.fluvie`, so the frame matches your theme.

## Reusing Markdown

`Markdown` from the code-and-terminal phase composes here too. It parses a
document once and renders it to widgets, with the same intrinsic reveal:

<!-- code-excerpt "examples/gallery/lib/lessons/09_diagrams_and_webviews.dart (markdown)" -->
```dart
child: const Markdown(
  _notes,
  reveal: Time.seconds(1),
).animate([Animation.fadeIn()]),
```

Lesson 09 pairs a Mermaid diagram, a Markdown explainer, and a framed web page in
one explainer. See [Code and terminal videos](code-and-terminal-videos.md) for
the full `Markdown` reference.

## The live renderer is experimental

`Mermaid`, `WebView`, and `Html` resolve through an injected `SnapshotService`.
In this version the bundled headless-Chrome renderer is experimental and not yet
wired. Two failure modes name what is wrong rather than painting a blank frame:
the bundled `ChromeSnapshotService` raises a `FluvieRenderException` ("live
capture is not wired in this build"), and when no service is supplied at all a
`Mermaid`/`WebView`/`Html` capture raises a `FluvieRenderException` naming the
source and the pre-resolution pass. So live diagram and page rasterization is not
available out of the box yet.

To rasterize a `Mermaid`, `WebView`, or `Html` today, you supply a
`SnapshotService`. The example app uses an offline fixture service that maps
known requests to committed images, which is why lesson 09 renders offline with
no Chromium and no network.

What works now:

- `Snapshot(child)` rasterizes any subtree in process, fully deterministic.
- `DeviceFrame.phone/browser/tablet` chrome over any child.
- The full API for `Mermaid`, `WebView`, and `Html`, plus the rasterize-once
  caching model.
- Your own `SnapshotService` (an offline fixture one is enough).

What is forthcoming:

- The bundled Mermaid and WebView live renderer, so live rasterization works with
  no service to supply.

When the bundled renderer is enabled and Chromium is missing, the service throws
a typed `FluvieSnapshotUnavailableError`. That error names the missing capability
and the install fix, so a fresh clone gets a clear message rather than a blank
frame.

## Rasterized once, cached by content

Every element here is a pure function of its source, its viewport or theme, and
its reveal progress. The rasterize step runs once per content and is cached by
content hash, never per frame. The same input paints the same way every time, so
diagrams, pages, and snapshots cache and golden like every other element.

## Where to next

- [Code and terminal videos](code-and-terminal-videos.md): the `Markdown`,
  `Code`, and `Terminal` elements a diagram sits beside.
- [Images and video clips](images-and-video-clips.md): the media pipeline a
  snapshot rides, pre-resolved before the frame loop.
