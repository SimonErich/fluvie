# fluvie_mobile_encoder

Render [Fluvie](https://pub.dev/packages/fluvie) videos to MP4 fully on-device,
on Android and iOS. No FFmpeg, no bundled binary, no server: the frames never
leave the phone.

[![pub package](https://img.shields.io/pub/v/fluvie_mobile_encoder.svg)](https://pub.dev/packages/fluvie_mobile_encoder)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

## Why

Fluvie normally renders in two steps: capture the widget tree to raw frames, then
encode them with FFmpeg on a desktop or a server. FFmpeg cannot run on a phone
(iOS forbids spawning binaries, and shipping one raises GPL and codec-patent
questions). This package keeps Fluvie's exact capture pipeline and swaps only the
encode step for the platform's own hardware video encoder:

- **Android**: `MediaCodec` + `MediaMuxer`.
- **iOS**: `AVAssetWriter` over VideoToolbox.

Both are already on the device, already licensed for H.264/HEVC, and need no
extra download. So a video you generate on the device is private by construction.

## How it works

1. `OnDeviceVideoRenderer` runs Fluvie's deterministic capture loop into an
   off-screen surface sized to your target resolution, so the live UI never
   flickers. It writes `frames.rgba` (raw RGBA8888) into an app sandbox.
2. It hands the frames file to the platform encoder over a method channel.
3. The native side reads the frames, converts and encodes each with the hardware
   encoder, and writes the MP4. Presentation timestamps come from the frame index
   and fps, so the encode carries no wall-clock.

You write the same Fluvie `Video` you would render anywhere. Only the renderer
changes.

## Install

```sh
flutter pub add fluvie_mobile_encoder
```

This is a plugin with Android and iOS implementations. There is nothing to
configure.

## Quick start

```dart
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

Future<void> renderOnDevice(Video video) async {
  final renderer = OnDeviceVideoRenderer();
  final file = await renderer.render(
    composition: video,
    aspect: Aspect.square,
    duration: const Duration(seconds: 4),
    longEdge: 720,
    onProgress: (phase) => debugPrint('render: ${phase.name}'),
  );
  // `file` is an MP4 in the app's temp directory, ready to share or save.
}
```

Pick the codec with `codec: MobileVideoCodec.hevc` for smaller files where the
device supports it, and set an explicit `bitRate:` to override the
resolution-scaled default from `defaultBitRate`.

A runnable demo lives in the Fluvie example app, with its own entry point:

```sh
flutter run -t lib/on_device/on_device_page.dart   # on a device or simulator
```

## What carries over, and what does not

Because the capture half is Fluvie's own, **every visual element, animation, and
transition renders identically** to a desktop render. The trade-offs are at the
encode edge:

- **Determinism**: the captured frames are byte-identical on every machine (so
  Fluvie's frame goldens still hold), but the encoded MP4 is per-device. Hardware
  encoders are not bit-exact across chips, so do not byte-compare a phone's MP4
  against a desktop's. Validate structurally (frame count, duration, resolution)
  or by decoding back within a tolerance.
- **Export formats**: MP4 (H.264 or HEVC) only. GIF and transparent WebM have no
  hardware path; render those on a desktop or server.

## Audio

Audio is opt-in, so the default path never changes for anyone. Declare `Audio`
on your `Video` exactly as you would for a desktop render, then pass `audio: true`:

```dart
final file = await OnDeviceVideoRenderer().render(
  composition: myVideoWithMusic,
  aspect: Aspect.square,
  duration: const Duration(seconds: 8),
  audio: true,
);
```

The renderer reads the `Video`'s tracks through Fluvie's `resolveAudioMix`,
materializes each source (bundled assets and local files; pre-download network
audio), then decodes, mixes (delays, volumes, trims, fades), and muxes them with
the platform's own audio encoder. The mix uses the same timing math as the
FFmpeg path, so the result matches a desktop render.

If a `Video` declares audio but you do not pass `audio: true`, the render is
silent and the renderer warns once through `OnDeviceVideoRenderer.onWarning`.
Pass `warnOnDroppedAudio: false` to silence that, or replace `onWarning` to route
it. Looping beds and network sources are not honored on-device yet.

## Platform support

| Platform | Encoder | Status |
| --- | --- | --- |
| Android (API 24+) | `MediaCodec` + `MediaMuxer` | supported |
| iOS (12+) | `AVAssetWriter` + VideoToolbox | supported |
| Desktop / web | none | use `fluvie_cli` or `fluvie_api` |

On an unsupported platform the encoder throws a `FluvieMobileEncoderException`
with code `unsupported_platform`.

## Testing

Override the encoder with the shipped `FakeMobileVideoEncoder`, and inject a
tester-backed `CaptureHost`, to drive the whole pipeline in a widget test with no
device. See this package's own test suite for the pattern.

## Documentation

See the Fluvie
[on-device mobile rendering guide](https://docs.fluvie.dev/guides/on-device-mobile-rendering/).

## License

MIT. See [LICENSE](LICENSE).
