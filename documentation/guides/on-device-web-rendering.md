# On-device web rendering

Capture and encode a Fluvie video to an MP4 inside the browser, without sending
frames to a render server. Offline rendering requires self-hosted encoder files
and locally available media; network assets or generators can still make
requests. This is what [`fluvie_web_encoder`](https://pub.dev/packages/fluvie_web_encoder)
adds, on Flutter web.

You write the same `Video` you would render anywhere. Only the renderer changes,
and it returns the MP4 bytes:

<!-- code-excerpt "packages/fluvie_web_encoder/example/lib/main.dart (render)" -->
```dart
final bytes = await WebVideoRenderer().render(
  composition: _demoVideo(),
  aspect: Aspect.square,
  duration: const Duration(seconds: 2),
  longEdge: 480,
  audio: true, // mix the bundled music bed into the MP4, in the browser
);
// The MP4 never left the browser; deliver `bytes` as a download or upload.
```

`ffmpeg.wasm` is FFmpeg compiled to WebAssembly. Fluvie shares its encode-plan
builder with the desktop path and adapts the video input to PNG files. The
selected wasm build still determines which codecs and filters are available;
sharing the plan does not give every browser the desktop's capabilities.

## Setup

The steps below are opt-in. An app that does not add the plugin never ships any
of this.

**1. Add the plugin.**

```sh
flutter pub add fluvie_web_encoder
```

**2. Wrap your app once in a `FluvieWebStage`.**

In-browser capture reads pixels back from a `RepaintBoundary` the engine has
actually painted, so the capture surface must live inside your app's own render
pipeline. `FluvieWebStage` provides that surface off-screen; nothing shows on
screen.

<!-- code-excerpt "packages/fluvie_web_encoder/example/lib/main.dart (stage)" -->
```dart
void main() => runApp(const FluvieWebStage(child: WebEncoderExampleApp()));
```

**3. Install the ffmpeg.wasm bridge in your `web/index.html`.**

The renderer drives a small page-global object, `FluvieFfmpeg`, which wraps
[@ffmpeg/ffmpeg](https://github.com/ffmpegwasm/ffmpeg.wasm). It lazy-loads the
wasm core on the first render (not at app boot), so the payload is fetched only
when a user actually renders. The single-threaded core needs no cross-origin
isolation headers:

```html
<script type="importmap">
  {
    "imports": {
      "@ffmpeg/ffmpeg": "/ffmpeg/ffmpeg/index.js",
      "@ffmpeg/util": "/ffmpeg/util/index.js"
    }
  }
</script>
<script type="module">
  import { FFmpeg } from '@ffmpeg/ffmpeg';

  async function toBlobURL(url, type) {
    const buffer = await (await fetch(url)).arrayBuffer();
    return URL.createObjectURL(new Blob([buffer], { type }));
  }

  const ffmpeg = new FFmpeg();
  let loaded = null;
  async function loadFfmpeg() {
    await ffmpeg.load({
      coreURL: await toBlobURL('/ffmpeg/core/ffmpeg-core.js', 'text/javascript'),
      wasmURL: await toBlobURL('/ffmpeg/core/ffmpeg-core.wasm', 'application/wasm'),
    });
  }

  globalThis.FluvieFfmpeg = {
    load: () => (loaded ??= loadFfmpeg()),
    writeFile: (name, bytes) => ffmpeg.writeFile(name, bytes),
    exec: (args) => ffmpeg.exec(args),
    readFile: (name) => ffmpeg.readFile(name),
  };
</script>
```

Self-host the files under `web/ffmpeg/` for offline, private rendering, or point
the URLs at a CDN. The wasm core is large (tens of megabytes), so vendor it with a
fetch step rather than committing it. A runnable demo, with that step and the
bridge wired up, lives in
[`packages/fluvie_web_encoder/example`](https://github.com/SimonErich/fluvie/tree/main/packages/fluvie_web_encoder/example).

**4. Install the clip-decoder bridge (only if you render `Clip`s).**

A `Clip` decodes in the browser through WebCodecs, behind a second page-global
object, `FluvieClipDecoder`. It demuxes the clip's MP4 with
[mp4box.js](https://github.com/gpac/mp4box.js) and decodes the samples it reads
with a `VideoDecoder`, returning RGBA pixels per source frame, the in-browser
analogue of the on-device native frame reader. Like the encoder bridge it loads
its demuxer lazily, so a page that renders no clips never fetches it:

```html
<script type="module">
  // mp4box.js is a UMD bundle (sets the MP4Box + DataStream globals); inject it
  // lazily so the demuxer is fetched only when a clip actually renders.
  let loading = null;
  const loadMp4box = () => (loading ??= new Promise((ok, fail) => {
    if (globalThis.MP4Box) return ok();
    const s = document.createElement('script');
    s.src = 'vendor/mp4box/mp4box.all.min.js'; // vendor mp4box.js here
    s.onload = () => globalThis.MP4Box ? ok() : fail(new Error('no MP4Box global'));
    s.onerror = () => fail(new Error('failed to load mp4box.js'));
    document.head.appendChild(s);
  }));

  globalThis.FluvieClipDecoder = {
    // probe(bytes)                          -> { fps, frameCount, width, height }
    // extractFrames(bytes, indices, w, h)   -> Uint8Array[] (one RGBA frame each)
    //
    // Implement both with `await loadMp4box()`, `MP4Box.createFile()` to demux
    // the track's samples + its avcC/hvcC description, a WebCodecs `VideoDecoder`
    // to decode them, and an `OffscreenCanvas` + `getImageData` to read RGBA.
    // Indices are presentation-order (frame 0 = first displayed).
  };
</script>
```

A complete, working bridge (sample extraction, codec description,
presentation-order reindexing, error handling) lives in
the local [browser studio example](../../examples/web_browser_studio/README.md),
in `web/clip_decoder.js`; vendor mp4box.js
under `web/vendor/` with a fetch step, the same way you vendor the wasm core. A
browser without WebCodecs, or that can't decode the clip's codec (Safari and some
headless Chromium builds can't do H.264), fails fast with a clear typed error.

## How it works

A normal Fluvie render is two steps: capture the widget tree to frames, then
encode those frames with FFmpeg. On the web both steps run on the page.

```text
Video  ->  off-screen capture (Fluvie)  ->  PNG frame sequence  ->  ffmpeg.wasm  ->  MP4 bytes
           inside the app's own pipeline    in memory (one file/frame)  (real FFmpeg, in the browser)
```

1. `WebVideoRenderer` runs Fluvie's capture loop into the
   `FluvieWebStage` surface, sized to your target resolution and parked
   off-screen. Each captured frame is encoded to a PNG and written to an
   in-memory sandbox as a numbered image sequence (`frame_000000.png`, …), never
   to disk. Compressing each frame avoids retaining the entire raw RGBA
   sequence. The PNG sequence remains in the sandbox and is then copied into
   the wasm file system, so total memory still grows with the render's length.
2. It hands the sandbox to `ffmpeg.wasm`, which runs the same H.264 encode and
   audio-mix plan a desktop render would, reading the PNG image sequence as its
   input (the desktop path reads a raw stream) and writing the output in its
   in-memory file system.
3. The renderer reads the encoded file back and returns it as a `Uint8List`.

No `dart:io`, no temp directory, no subprocess. The capture half shares Fluvie's
frame clock and timing engine. Browser rasterization, fonts, shaders and resource
support can differ from desktop capture; compare decoded pictures within an
appropriate tolerance rather than assuming pixel or file equality.

## The advantages

- **Local encoding.** The renderer captures frames and encodes the MP4 on the
  page. It does not upload them to a render service; your asset loaders,
  generators and app's download/upload flow control other network traffic.
- **No render bill and no round trip.** There is no render service to run or pay
  for.
- **Shared export plans.** H.264, GIF and transparent WebM use the shared
  `Export` plans when the configured wasm build includes the required codecs.

## Capabilities of the default browser host

| Composition feature | Default `WebVideoRenderer` |
| --- | --- |
| Flutter layout, authored animation and scene transitions | Shared timing engine; browser rasterization. |
| Images and video clips | Assets/memory/allowlisted URLs; clips require the installed decoder and a supported source codec. |
| Declared music, effects and embedded clip audio | Opt-in with `audio: true`, for MP4 output. |
| Beat/spectrum-reactive widgets and `ctx.audio` | No default browser analysis backend. |
| Caption sources | Not supported by the built-in browser media resolver. |
| Flutter `Snapshot` subtrees | Mounted snapshot preparation follows the shared frame clock. |
| Mermaid, Html and WebView snapshots | External capture requires a suitable backend; not provided by the default browser adapter. |
| Generated media | No default generator in this renderer. Resolve it to ordinary assets first, or use an advanced host with the required services. |

These are the independently hosted browser defaults. `fluvie preview` instead
adds an authenticated local native FFmpeg bridge for clip and audio decoding;
that bridge does not establish feature parity for all browser capture services.

## The trade-offs

- **Bundle size.** The wasm core is a few tens of megabytes. It is fetched lazily
  on the first render, not at app boot, and it ships **only** if you add the
  plugin and wire the bridge. If you want to keep the bundle light, render through
  [`fluvie_server`](rendering-on-a-server.md) instead and skip the wasm entirely.
- **Speed.** The single-threaded wasm core is slower than a native FFmpeg binary.
  Keep web renders short and modest in resolution, or move long renders to the
  server.
- **No local files.** The browser has no file system, so a `/path/to.wav` audio
  source is not valid here. Bundle audio as an asset or serve it over an
  allowlisted URL (see [Audio](#audio)).
- **Clips need WebCodecs.** A `Clip` decodes in the browser through WebCodecs.
  `WebVideoRenderer` wires a decoder by default, but it needs a browser with
  WebCodecs and the `FluvieClipDecoder` bridge on the page; without them a clip
  fails with a clear error. Render clip compositions on the server or on mobile
  if the page has no decoder.
- **Requires the bridge.** Without the `FluvieFfmpeg` object in `index.html`, the
  encode step has nothing to call. The renderer fails fast with a clear error.

## Audio

Audio is opt-in, so the default flow never changes. The same `Audio.music` and
`Audio.sfx` you declare for a desktop render are read in the browser through
Fluvie's `resolveAudioMix`, then mixed by `ffmpeg.wasm` with the **same** `amix`
plan the desktop uses. Looping beds, fades, trims, per-track volume, and multiple
tracks all work, because the argument plan is identical.

Pass `audio: true` to `WebVideoRenderer.render` to turn it on. Bundle your audio
as an asset (loaded through `rootBundle`), or fetch it from an allowlisted URL by
constructing the renderer with a `BundleWebAudioMaterializer` that has a
`NetworkAllowlist`. A network fetch is subject to the browser's CORS rules, so the
audio host must allow your page's origin. Local file paths are not valid in the
browser (there is no file system).

A `Clip`'s own audio track is mixed in too when `audio: true`: `ffmpeg.wasm`
demuxes the AAC straight from the clip's MP4 and the mix delays and trims it to
where the clip plays, using the **same** plan as on mobile and the desktop. So a
clip composition is not silent in the browser. See [Clips](#clips).

If a `Video` declares audio but you leave `audio` off, the render is silent and
the renderer warns once through `WebVideoRenderer.onWarning`. Pass
`warnOnDroppedAudio: false` to silence it. Audio rides the MP4 export only; a GIF
or transparent render drops it (also warned). For the full audio API, see
[Audio and captions](audio-and-captions.md).

## Clips

A `Clip` plays its real frames in the browser through **WebCodecs**, not FFmpeg,
for the decode. `WebVideoRenderer` wires a decoder by default; it bridges to the
`FluvieClipDecoder` object the page installs (the same way `FluvieFfmpeg` provides
the encoder), which demuxes the clip's MP4 with mp4box.js and decodes the samples
it reads with a `VideoDecoder`. The **same** resample math the desktop uses picks
the source frames. A browser decoder without a presentation timeline falls back
to average FPS, so variable frame rate sources can have imperfect timestamp alignment. A clip's embedded audio is
mixed in when you pass `audio: true` (see [Audio](#audio)).

The shared composition session requests source frames on demand and retires
its bounded scrub cache after paint; it no longer retains every extracted frame
for a clip's full duration. Full-resolution RGBA pictures, the loaded source
bytes, captured PNG sequence and wasm file system still consume browser memory.
A preview can limit clip decode size; export preserves the source resolution.
For long renders, budget those retained inputs or use the
[server](rendering-on-a-server.md). See [Performance](../advanced/performance.md)
for the per-source cache budget and its exceptions.

A clip's `trim` and its `ClipAudio` policy are the same shared behavior as every
other renderer: `trim` selects which source frames the decoder is asked for (only
those are decoded), and a `ClipAudio.muted` clip contributes no audio track. The
decoder is created and closed per render, and a wedged decode (a corrupt clip, or
exhausted hardware decoder sessions) fails with a clear typed error after a
watchdog timeout rather than hanging the render.

Clips need a browser with WebCodecs that can decode the clip's codec. Chrome and
Edge decode H.264; **Safari and some headless Chromium builds cannot**, and a
browser missing WebCodecs or the bridge fails fast with a clear typed error.

## Images

Declared image media renders in the browser the same way it does on the desktop.
An `Image.asset`, an allowlisted `Image.network`, or an `Image.memory` is
resolved and decoded once before the frame loop, then painted from the decoded
cache. There is no async pop-in and the render stays deterministic. Bundle the
asset (loaded through `rootBundle`) or serve it from an allowlisted, CORS-enabled
URL, exactly as for audio.

## Delivering the result

`render` returns the MP4 bytes; nothing is downloaded for you. Hand them to
`downloadBytes` to save the file straight from the page:
`downloadBytes(bytes, filename: 'render.mp4')`. It wraps the bytes in a Blob and
clicks a temporary object-URL link, so the file lands in the user's downloads
with no server. Pass `mimeType:` for a GIF or WebM export.

`render` reports progress through `onProgress`, a `RenderProgress` carrying the
current phase (`capturing`, `encoding`, `complete`) and, while capturing, the
frame counts. To restrict which hosts network images may load from, pass a
`networkAllowlist` to the `WebVideoRenderer` constructor.

## Keeping the bundle light

The wasm payload is part of `fluvie_web_encoder`, never of `fluvie`. An app that
depends only on `fluvie` plus `fluvie_server` builds with no wasm at all. Adding or
removing in-browser rendering is one line in `pubspec.yaml` plus the bridge
`<script>`, so you can ship the API path by default and add the plugin only where
in-browser rendering earns its size.

## One app, mobile and web

A single Flutter app can render on-device on both mobile and web. Pick the
renderer per platform behind a conditional import: `OnDeviceVideoRenderer` from
[`fluvie_mobile_encoder`](on-device-mobile-rendering.md) on Android and iOS,
`WebVideoRenderer` from `fluvie_web_encoder` on the web. The authored `Video` stays
the same; decoder, snapshot, audio-analysis and output support depend on the
selected backend. Use the [capability registry](../reference/render-capabilities.md)
and validate on your supported browsers and devices.

<!-- code-excerpt "examples/gallery/lib/cross_platform/render_on_device.dart (conditional-export)" -->
```dart
export 'render_on_device_stub.dart'
    if (dart.library.io) 'render_on_device_mobile.dart'
    if (dart.library.js_interop) 'render_on_device_web.dart';
```

Each file exposes the same `Future<Uint8List> renderOnDevice(Video video)`; the
mobile one reads the encoder's file back to bytes, the web one returns them
directly. The runnable demo lives in
[`examples/gallery/lib/cross_platform`](https://github.com/SimonErich/fluvie/tree/main/examples/gallery/lib/cross_platform).

## Testing without a browser

`fluvie_web_encoder` injects its capture host and its ffmpeg.wasm runtime, so the
renderer's orchestration runs in a plain VM unit test against a fake runtime. The
real browser acceptance checks exercise capture, decoding and wasm encoding on
specific fixtures and engine versions. See [Browser release checks](../contributing/browser-release-checks.md)
for coverage and comparison tolerances. Those checks do not prove every
composition or codec works in every browser.

## Where to next

- [Rendering on a server](rendering-on-a-server.md): the hosted path, for long
  renders, an audio mix, or to keep the web bundle light.
- [On-device mobile rendering](on-device-mobile-rendering.md): the same idea on
  Android and iOS, with the platform's native encoder.
- [Exporting your video](exporting-your-video.md): export plans, including GIF
  and transparent WebM; verify the codecs in your configured wasm build.
