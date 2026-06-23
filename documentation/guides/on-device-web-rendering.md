# On-device web rendering

Render a Fluvie video to an MP4 inside the browser, with no server and no
network. The frames and the encode both run on the page, so the video never
leaves the user's machine. This is what [`fluvie_web_encoder`](https://pub.dev/packages/fluvie_web_encoder)
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

This is the cleanest on-device path Fluvie has. `ffmpeg.wasm` **is** FFmpeg
compiled to WebAssembly, so the exact argument plan the desktop and server use
runs verbatim in the browser. There is no native encoder to reimplement (the way
mobile reimplements it), so the feature set matches the desktop.

## Setup

Two small steps, both opt-in. An app that does not add the plugin never ships any
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

**4. Install the clip-decoder bridge — only if you render `Clip`s.**

A `Clip` decodes in the browser through WebCodecs, behind a second page-global
object, `FluvieClipDecoder`. It demuxes the clip's MP4 with
[mp4box.js](https://github.com/gpac/mp4box.js) and decodes the samples it reads
with a `VideoDecoder`, returning RGBA pixels per source frame — the in-browser
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
[reday](https://github.com/SimonErich/reday)'s `web/index.html`; vendor mp4box.js
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
   to disk. Encoding per frame keeps capture memory flat — one frame at a time —
   instead of holding every raw frame at once, so a longer render no longer
   overflows the browser tab during capture.
2. It hands the sandbox to `ffmpeg.wasm`, which runs the same H.264 encode and
   audio-mix plan a desktop render would — reading the PNG image sequence as its
   input (the desktop path reads a raw stream) and writing the output in its
   in-memory file system.
3. The renderer reads the encoded file back and returns it as a `Uint8List`.

No `dart:io`, no temp directory, no subprocess. The capture half is Fluvie's own,
so every element, animation, and transition renders exactly as it does on the
desktop.

## The advantages

- **Privacy.** The frames are captured and the MP4 is encoded on the page.
  Nothing is uploaded, so no server can see, cache, or index the video.
- **No render bill and no round trip.** There is no render service to run or pay
  for.
- **The full FFmpeg feature set.** Because `ffmpeg.wasm` is FFmpeg, the same plan
  runs as on the desktop: H.264, and GIF or transparent WebM through `Export`.

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
clip composition is not silent in the browser — see [Clips](#clips).

If a `Video` declares audio but you leave `audio` off, the render is silent and
the renderer warns once through `WebVideoRenderer.onWarning` — pass
`warnOnDroppedAudio: false` to silence it. Audio rides the MP4 export only; a GIF
or transparent render drops it (also warned). For the full audio API, see
[Audio and captions](audio-and-captions.md).

## Clips

A `Clip` plays its real frames in the browser through **WebCodecs** — no FFmpeg
for the decode. `WebVideoRenderer` wires a decoder by default; it bridges to the
`FluvieClipDecoder` object the page installs (the same way `FluvieFfmpeg` provides
the encoder), which demuxes the clip's MP4 with mp4box.js and decodes the samples
it reads with a `VideoDecoder`. The **same** resample math the desktop uses picks
the source frames, so motion matches a desktop render. A clip's embedded audio is
mixed in when you pass `audio: true` (see [Audio](#audio)).

The browser has no file system to stream frames to, so — unlike the
[mobile](on-device-mobile-rendering.md#clips) path, which streams clip frames to
disk — the web decoder holds every frame it extracts **in memory**, at the source
resolution. Memory therefore scales with the clip's length × resolution: a short
reel is fine, but a long or high-resolution clip can exhaust a browser tab. Keep
in-browser clips short and known, and render long or full-resolution clips on the
[server](rendering-on-a-server.md) or [mobile](on-device-mobile-rendering.md) path.

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
`WebVideoRenderer` from `fluvie_web_encoder` on the web. The `Video` you pass is
identical; only the encoder differs.

<!-- code-excerpt "example/lib/cross_platform/render_on_device.dart (conditional-export)" -->
```dart
export 'render_on_device_stub.dart'
    if (dart.library.io) 'render_on_device_mobile.dart'
    if (dart.library.js_interop) 'render_on_device_web.dart';
```

Each file exposes the same `Future<Uint8List> renderOnDevice(Video video)`; the
mobile one reads the encoder's file back to bytes, the web one returns them
directly. The runnable demo lives in
[`example/lib/cross_platform`](https://github.com/SimonErich/fluvie/tree/main/example/lib/cross_platform).

## Testing without a browser

`fluvie_web_encoder` injects its capture host and its ffmpeg.wasm runtime, so the
renderer's orchestration runs in a plain VM unit test against a fake runtime. The
full browser chain (real capture plus `ffmpeg.wasm`) is proven by a headless
Chrome end-to-end render in the package's example.

## Where to next

- [Rendering on a server](rendering-on-a-server.md): the hosted path, for long
  renders, an audio mix, or to keep the web bundle light.
- [On-device mobile rendering](on-device-mobile-rendering.md): the same idea on
  Android and iOS, with the platform's native encoder.
- [Exporting your video](exporting-your-video.md): every export format, including
  the GIF and transparent WebM that `ffmpeg.wasm` renders in the browser too.
