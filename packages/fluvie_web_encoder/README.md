# fluvie_web_encoder

Render [Fluvie](https://pub.dev/packages/fluvie) videos to MP4 **fully in the
browser** with ffmpeg.wasm. The default render path keeps captured frames on the
page; the optional local preview adapters described below use a separate server.

[![pub package](https://img.shields.io/pub/v/fluvie_web_encoder.svg)](https://pub.dev/packages/fluvie_web_encoder)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

## Why

Fluvie normally renders in two steps: capture the widget tree to raw frames, then
encode them with FFmpeg. In a browser there is no FFmpeg binary — but there is
**ffmpeg.wasm, which *is* FFmpeg**. So this package keeps Fluvie's capture step
and shares the encode-plan builder with the native path, adapting the input to
PNG files. H.264, GIF and transparent WebM require the corresponding codecs in
the configured wasm build.

It is **opt-in**. The ffmpeg.wasm payload is large, so only apps that depend on
this package load it; apps that render through `fluvie_server` (a server) or only
target mobile stay light.

## How it works

1. `WebVideoRenderer` runs Fluvie's capture loop into an off-screen
   surface inside your app's own pipeline (a `FluvieWebStage`), writing the frames
   into an in-memory sandbox.
2. It feeds that sandbox to ffmpeg.wasm through Fluvie's `WasmRuntime`, runs the
   manifest's argument plan, and reads the MP4 back as bytes.

You write the same `Video` you would render anywhere.

## Install

```sh
flutter pub add fluvie_web_encoder
```

The package loads ffmpeg.wasm lazily, on the first render, through a page-global
`FluvieFfmpeg` bridge. The bridge wraps `@ffmpeg/ffmpeg`; see the
[setup guide](https://docs.fluvie.dev/guides/on-device-web-rendering/) for the
script to add to `web/index.html` (or self-host the wasm for offline use). Use
the single-threaded core to avoid needing cross-origin-isolation headers.

For clips, load the package's shared decoder rather than maintaining a separate
app bridge:

```html
<script type="module" src="assets/packages/fluvie_web_encoder/assets/clip_decoder.js"></script>
```

Vendor `mp4box@0.5.4`'s `dist/mp4box.all.min.js` at
`web/vendor/mp4box/mp4box.all.min.js`. The decoder loads that file lazily relative
to `document.baseURI`. Its `FluvieClipDecoder.probe(bytes)` reports `hasAudio` as
well as frame rate, count and dimensions; this field allows embedded clip sound
to reach both live playback and export. `extractFrames` bounds retained RGBA
batches to 128 MiB and limits the compressed decode queue. Include the package
asset and the demuxer in your offline cache.

## Quick start

Wrap your app once in a `FluvieWebStage`. It gives in-browser capture a surface
inside your app's own pipeline (off-screen, never shown), which is what lets the
render boundary mount and paint:

```dart
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';

void main() => runApp(const FluvieWebStage(child: MyApp()));
```

Then render anywhere in the app. The same `Video` you render on the desktop:

```dart
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';

Future<Uint8List> renderInBrowser(Video video) async {
  final renderer = WebVideoRenderer();
  return renderer.render(
    composition: video,
    aspect: Aspect.square,
    duration: const Duration(seconds: 4),
    longEdge: 720,
  );
}
```

The returned bytes are an MP4: hand them to a download link or upload them.

## What carries over, and what does not

The browser shares Fluvie's timing engine and export plans. Fonts,
rasterization, resource services and codec availability can differ from desktop
capture. The default browser media resolver does not support reactive audio
analysis, caption sources or snapshots; the renderer also supplies no generator.
See the [capability table](https://docs.fluvie.dev/guides/on-device-web-rendering/#capabilities-of-the-default-browser-host).

- **Performance**: wasm encoding and the retained PNG sequence can make long
  renders expensive. Measure your codec, resolution and browser; use
  `fluvie_server` when the browser's time or memory budget is insufficient.
- **Clips**: a `Clip` decodes on-device through WebCodecs. `WebVideoRenderer`
  wires a decoder by default; it needs a browser with WebCodecs and the
  `FluvieClipDecoder` bridge on the page. Without them a clip fails with a clear
  error, so wire the bridge or render clip compositions on the server or mobile.
- **Audio**: opt-in. Pass `audio: true` to mix and mux a `Video`'s `Audio` tracks
  (the same `amix` plan the desktop uses — looping beds, fades, trims, multi-track).
  Bundle audio as an asset or fetch it from an allowlisted URL; the browser has no
  local-file source. See the
  [audio guide](https://docs.fluvie.dev/guides/on-device-web-rendering/#audio).
- **Golden baseline**: the encoded MP4 may differ from a native FFmpeg build, so
  give web its own golden baseline.

## Cancellation and cleanup

Pass a `RenderCancellation` to the renderer or a `VideoRenderRequest` to stop
capture or encoding. Capture cancellation releases the host without starting
the encoder. Cancellable encoding requires a `WasmRuntimeLifecycle` bridge;
legacy runtimes without it fail with `UnsupportedError` rather than pretending
to stop an active job. A lifecycle-capable runtime also releases staged input
and output files after encoding. Cancelling a completed request does not affect
later jobs.

## Optional local preview

`createLocalFfmpegClipDecoder` uses a configured workspace endpoint and session
token instead of WebCodecs. It uploads compressed clip bytes to that endpoint
and fetches decoded RGBA frames; this mode is not browser-only processing. Use
only an endpoint you trust with your media, and dispose the returned decoder
when its preview session ends. Successful metadata or frame responses arriving
after disposal are rejected with `StateError` rather than returning stale media.

`createLocalPreviewAudioController` and `watchLocalPreviewReloads` provide the
browser audio and reload companions for the same workspace. They are not
available on native Dart platforms. These preview adapters do not replace the
FFmpeg wasm bridge required for in-browser exports.

## Documentation

See the Fluvie
[on-device web rendering guide](https://docs.fluvie.dev/guides/on-device-web-rendering/).

## License

MIT. See [LICENSE](https://github.com/SimonErich/fluvie/blob/main/packages/fluvie_web_encoder/LICENSE).
