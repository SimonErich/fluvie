# On-device mobile rendering

Render a Fluvie video to an MP4 on a phone using native video encoding and clip
decoding, without bundling FFmpeg or uploading frames to a render server.
Reactive audio analysis uses the native PCM decoder described below. Local assets
let a composition run offline; network media and generators can
still make requests. This is what [`fluvie_mobile_encoder`](https://pub.dev/packages/fluvie_mobile_encoder)
adds, on Android and iOS.

You write the same `Video` you would render anywhere. Only the renderer changes:

<!-- code-excerpt "examples/gallery/lib/snippets/mobile_authoring_snippets.dart (mobile-render)" -->
```dart
import 'dart:io';

import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

Future<File> renderSimpleVideo() => OnDeviceVideoRenderer().render(
  composition: Video(
    scenes: [
      Scene.centered(
        duration: 2.seconds,
        background: Background.color(Colors.teal),
        child: const Text('Hello, Fluvie', style: TextStyle(fontSize: 64, color: Colors.white)),
      ),
    ],
  ),
  aspect: Aspect.square,
  duration: const Duration(seconds: 2),
  longEdge: 480,
);
```

The result is an MP4 in the app's temporary directory, ready to share or save.
Call this helper from a mounted Flutter app on Android or iOS. The source is
statically checked; native execution still needs acceptance on your actual
device or simulator. The gallery's `on_device/on_device_page.dart` is an advanced
audio/caption example, not this minimal composition; reactive tracks use the
native analysis service described below.

## How it works

A normal Fluvie render is two steps: capture the widget tree to raw frames, then
encode those frames with FFmpeg. This package uses the shared capture clock and
timing engine with the platform's native video encoders instead of bundling
FFmpeg. Actual codec availability depends on the target device.

```text
Video  ->  off-screen capture (Fluvie)  ->  frames.rgba  ->  native encoder  ->  out.mp4
                                                              MediaCodec (Android)
                                                              AVAssetWriter (iOS)
```

1. `OnDeviceVideoRenderer` runs Fluvie's deterministic capture loop into an
   off-screen surface sized to your target resolution, so the live UI never
   flickers. It writes `frames.rgba` (raw RGBA8888) into an app sandbox.
2. It hands that file to the platform encoder over a method channel.
3. The native side reads the frames, converts and encodes each with the hardware
   encoder, and writes the MP4. Presentation timestamps come from the frame index
   and fps, so the encode carries no wall-clock.

The native APIs avoid a bundled software encoder. H.264 and HEVC availability
still depends on the device; validate the chosen codec on your supported targets.

## The advantages

- **Local encoding.** The renderer captures and encodes frames on the device.
  It does not upload them to a render service; your asset loaders, generators
  and app's file-delivery flow control other network traffic.
- **No render bill and no wait.** No round trip to a render service.
- **Hardware accelerated.** The platform encoders run on dedicated silicon.

## The trade-offs

The capture half shares Fluvie's frame clock and timing engine. Fonts, the
Flutter rasterizer, resource services and platform codecs can still produce
different pictures or behavior. Validate the target backend with the composition
you intend to ship:

- **The encoded file is per-device.** Hardware encoders are not bit-exact across
  chips, so the MP4 a phone writes will not match a desktop render byte for byte.
  Validate a mobile render structurally (frame count, duration, resolution) or by
  decoding it back within a tolerance, never by byte-comparing the files.
- **Audio is opt-in.** Declare `Audio` on your `Video` as usual and pass
  `audio: true` to encode it; the renderer materializes, mixes, and muxes the
  tracks with the platform audio encoder. Looping beds work on both platforms, and
  network audio is supported opt-in (see [Audio](#audio)). Left off, a `Video` with
  audio renders silent and warns once.
- **MP4 only.** H.264 or HEVC. GIF and transparent WebM have no hardware path;
  render those with `fluvie_cli` or `fluvie_server`.

## Audio

Audio stays opt-in, so the default flow never changes for anyone. The same
`Audio.music`/`Audio.sfx` you declare for a desktop render are read on-device
through Fluvie's `resolveAudioMix`, which resolves each track's delay, volume,
trim, and fades with the **same timing math** the FFmpeg mix uses. The platform
then decodes, mixes, and muxes them (Android `MediaCodec`, iOS AVFoundation).
Shared track timing does not imply identical decoded samples or encoded bytes.

Pass `audio: true` to `OnDeviceVideoRenderer.render` to turn it on. Bundle your
audio as an asset or pass a local file path. A looping `Audio.music(loop: true)`
bed fills the whole video on both Android and iOS. For a network source,
construct the renderer with a `NetworkAudioMaterializer` and a `NetworkAllowlist`
of permitted hosts; the bytes are fetched to a local file, then mixed as usual.
An `Audio.musicSource(AudioSource.memory(bytes))` track needs no materializer at
all: the renderer writes the bytes into the render sandbox under their content
hash and mixes that file, the same way the web renderer stages them.
If a `Video` declares audio but you leave `audio` off, the render is silent and
the renderer warns once through `OnDeviceVideoRenderer.onWarning`. Pass
`warnOnDroppedAudio: false` to silence it.

See [Audio across platforms](audio-and-captions.md#audio-across-platforms) for the
full per-platform support table.

## Clips

A `Clip` plays its real frames on-device, with no FFmpeg. The platform decoder
(Android `MediaMetadataRetriever`/`MediaExtractor`, iOS AVFoundation) extracts
the source frames the clip's window reads, using the shared resample math.
`NativeVideoProbeService` reads the platform's optional presentation-time index,
validates its frame count and passes `MediaTimeline` through the shared media
repository. Indexed sources use their real display intervals for trim, speed and
resampling, including variable frame rates. Older or injected probes without a
timeline retain average-fps mapping. Dart channel tests cover variable intervals;
the capability registry keeps exact mobile clip timing disabled until physical
device source fixtures verify the complete native path.

A clip's embedded audio is mixed in
when you pass `audio: true`, delayed to where the clip plays and trimmed to its
window, alongside any declared `Audio` tracks.

Clip frames use a disk-backed store and the shared composition session requests
the source frames needed for each picture, instead of keeping a full decoded
clip in the app heap. Cached picture handles are retired after paint. The store
is deleted when the resolver is disposed. Large source frames, multiple
simultaneous clips and the output itself still require a memory budget; see
[Performance](../advanced/performance.md).

The browser renders the same clips through WebCodecs instead of a native decoder;
its retained pictures live in a bounded memory cache rather than that disk
store. See [web clips](on-device-web-rendering.md#clips).

### Current composition limits

Native encoding, clip decoding and default reactive audio analysis do not use
FFmpeg. `OnDeviceVideoRenderer` creates an owned `NativePcmDecoder` for compressed
audio and shares its decoded samples between beat and frequency analysis. Android
uses MediaCodec; iOS uses AVFoundation. Decoded mono PCM is staged through a file
rather than a large method-channel payload, then validated before DSP.

The default bound is 16 million samples, about six minutes at 44.1 kHz. A longer
reactive track fails before capture instead of allocating an unbounded buffer.
Pass an injected `PcmDecoder` through `pcmDecoder:` to supply a custom analysis
source or a `NativePcmDecoder(maxSamples: ...)` with an appropriate memory budget.
The caller owns an injected decoder's lifetime; dispose an injected native
decoder when its scope ends. Normal audible music does not require PCM analysis.

Dart channel/analysis tests and Android decoder compilation establish the current
implementation. iOS AVFoundation code still needs Darwin compilation and native
device acceptance; validate compressed source formats and audio behavior on your
supported devices.

Flutter `Snapshot` subtrees are prepared while their original keyed layout and
frame clock stay mounted. External Mermaid, Html or WebView snapshots require an
explicit `SnapshotService` suitable for the target platform.

Mounted preparation discovers clips and their embedded audio inside ordinary
custom Flutter widgets. It also reads authored `Video.export` through wrappers,
so a wrapper does not bypass output policy. The default adapter checks its
supported codecs, pixel format and MP4 output before capture. Its `codec` and
`bitRate` arguments select supported mobile encoding options explicitly.

For an exact canvas and capture range, use `renderRequest(VideoRenderRequest(...))`.
The [complete request](../reference/rendering-surface.md#receive-one-complete-render-request)
includes authored overrides, poster, audio policy, progress and cancellation.
Audio defaults to enabled on that interface; the legacy `render` method keeps
its explicit opt-in behavior. See the [capability registry](../reference/render-capabilities.md)
for the mobile profile and required environment.

## Codec and bitrate

Pass `codec: MobileVideoCodec.hevc` for smaller files where the device supports
it. The bitrate scales with resolution and frame rate by default (`defaultBitRate`);
pass an explicit `bitRate:` to override it.

## Saving and progress

`render` returns the `File` it wrote. By default that file lives in a fresh temp
sandbox; pass `outputFile:` to have the encoder write straight to a path you
choose (for example one from `path_provider`), and that file is returned.

`render` reports progress through `onProgress`, a `RenderProgress` carrying the
current phase (`capturing`, `encoding`, `complete`). To restrict which hosts
network images may load from, pass a `networkAllowlist` to the
`OnDeviceVideoRenderer` constructor.

## Platform support

| Platform | Encoder | Status |
| --- | --- | --- |
| Android (API 24+) | `MediaCodec` + `MediaMuxer` | supported |
| iOS (12+) | `AVAssetWriter` + VideoToolbox | supported |
| Desktop / web | none | use the CLI or the render server |

On an unsupported platform the renderer throws a `FluvieMobileEncoderException`
with the code `unsupported_platform`.

## Testing without a device

`fluvie_mobile_encoder` ships a `FakeMobileVideoEncoder` and lets you inject a
`CaptureHost`, so the whole pipeline runs in a widget test with no device. The
package's own suite drives a real capture against a tester-backed host and a fake
encoder, asserting the frames file and the encode request.

## Where to next

- [Rendering on a server](rendering-on-a-server.md): the hosted path, for when you
  want FFmpeg's full encode (audio, GIF, transparency) or a shared render service.
- [Exporting your video](exporting-your-video.md): every export format the
  desktop and server renderers support.
