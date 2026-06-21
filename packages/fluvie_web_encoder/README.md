# fluvie_web_encoder

Render [Fluvie](https://pub.dev/packages/fluvie) videos to MP4 **fully in the
browser** with ffmpeg.wasm. The frames never leave the page.

[![pub package](https://img.shields.io/pub/v/fluvie_web_encoder.svg)](https://pub.dev/packages/fluvie_web_encoder)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

## Why

Fluvie normally renders in two steps: capture the widget tree to raw frames, then
encode them with FFmpeg. In a browser there is no FFmpeg binary — but there is
**ffmpeg.wasm, which *is* FFmpeg**. So this package keeps Fluvie's capture step
and runs the *exact same* encode argument plan through ffmpeg.wasm: H.264, GIF,
and transparent WebM all work with no reimplementation and no native code.

It is **opt-in**. The ffmpeg.wasm payload is large, so only apps that depend on
this package load it; apps that render through `fluvie_api` (a server) or only
target mobile stay light.

## How it works

1. `WebVideoRenderer` runs Fluvie's deterministic capture loop into an off-screen
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

Because both halves are Fluvie's own (capture) and real FFmpeg (encode), the full
feature set works: every element, animation, transition, and `Export` mode (MP4,
GIF, transparent WebM) renders exactly as on the desktop.

- **Performance**: ffmpeg.wasm is roughly 10–50× slower than native FFmpeg. Web
  on-device suits previews and short clips; use `fluvie_api` for long renders.
- **Audio**: opt-in. Pass `audio: true` to mix and mux a `Video`'s `Audio` tracks
  (the same `amix` plan the desktop uses — looping beds, fades, trims, multi-track).
  Bundle audio as an asset or fetch it from an allowlisted URL; the browser has no
  local-file source. See the
  [audio guide](https://docs.fluvie.dev/guides/on-device-web-rendering/#audio).
- **Determinism**: the captured frames are byte-identical run-to-run; the encoded
  MP4 may differ from a native FFmpeg build, so give web its own golden baseline.

## Documentation

See the Fluvie
[on-device web rendering guide](https://docs.fluvie.dev/guides/on-device-web-rendering/).

## License

MIT. See [LICENSE](LICENSE).
