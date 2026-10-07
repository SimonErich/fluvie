# fluvie_mobile_encoder

Render [Fluvie](https://pub.dev/packages/fluvie) videos to MP4 fully on-device,
on Android and iOS. Native video encoding and clip decoding use platform services
without bundling FFmpeg or uploading frames to a render server. Default reactive
audio analysis uses `NativePcmDecoder`; see the
[composition limits](https://docs.fluvie.dev/guides/on-device-mobile-rendering/#current-composition-limits).

[![pub package](https://img.shields.io/pub/v/fluvie_mobile_encoder.svg)](https://pub.dev/packages/fluvie_mobile_encoder)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

## Why

Fluvie normally renders in two steps: capture the widget tree to raw frames, then
encode them with FFmpeg on a desktop or a server. This package instead uses
the platform's native video encoders without bundling FFmpeg. It shares Fluvie's
capture clock and timing engine and supplies a native encode backend:

- **Android**: `MediaCodec` + `MediaMuxer`.
- **iOS**: `AVAssetWriter` over VideoToolbox.

The platform APIs are available on supported devices; actual H.264/HEVC codec
availability depends on the device. No bundled FFmpeg download is required.
Capture and encoding stay on-device; network media,
generators and your app's file-delivery flow can still make requests.

`OnDeviceVideoRenderer(pcmDecoder: ...)` accepts a custom PCM analysis backend.
Its default `NativePcmDecoder` uses Android MediaCodec or iOS AVFoundation, caches
one decoded result for beat/spectrum analysis, and caps tracks at 16 million
mono samples. Inject a configured native decoder to change that memory bound;
the caller disposes injected decoders. Dart and Android checks cover the current
implementation; iOS native compilation and target-device acceptance remain
required before claiming a supported compressed source format on every device.

## How it works

1. `OnDeviceVideoRenderer` runs Fluvie's capture loop into an
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

- **The encoded file is per-device**: hardware encoders are not bit-exact across
  chips, so do not byte-compare a phone's MP4 against a desktop's. Validate
  structurally (frame count, duration, resolution) or by decoding back within a
  tolerance.
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
FFmpeg path; platform decoding and encoding can still produce different samples
and output bytes.

If a `Video` declares audio but you do not pass `audio: true`, the render is
silent and the renderer warns once through its warning sink. Pass
`warnOnDroppedAudio: false` to silence that, or pass `onWarning` to the
constructor to route it. Looping beds are supported. Network sources require a
`NetworkAudioMaterializer` with an explicit allowlist. See the
[mobile guide](https://docs.fluvie.dev/guides/on-device-mobile-rendering/#current-composition-limits)
for current custom-widget embedded-audio and wrapper/export limits.

## Platform support

| Platform | Encoder | Status |
| --- | --- | --- |
| Android (API 24+) | `MediaCodec` + `MediaMuxer` | supported |
| iOS (12+) | `AVAssetWriter` + VideoToolbox | supported |
| Desktop / web | none | use `fluvie_cli` or `fluvie_server` |

On an unsupported platform the encoder throws a `FluvieMobileEncoderException`
with code `unsupported_platform`.

On-device `Clip` sources use `MediaMetadataRetriever` on Android 9/API 28+ and
AVFoundation on iOS 12+. Probing reports display-oriented dimensions, actual
frame count, declared frame rate and audio-track presence. iOS indexes sample
presentation timestamps, then requests exact images with the track's display
transform; fractional/VFR sources are not located by rounding a frame rate.
Both implementations return packed RGBA frames in request order.

The iOS index cache holds at most four assets and one million frame timestamps;
clips exceeding one million frames must be split. Each iOS extraction call
is capped at 256 MiB. The Dart adapter already splits work into eight-frame
batches. Device codec support still determines which source formats decode.

**iOS validation boundary:** the probe/extraction bridge and macOS simulator CI
gate are implemented, but their Swift compilation and simulator/device
acceptance have not been run in the Linux implementation environment. Do not
treat Dart method-channel tests as native iOS verification. The concrete checks
below must pass on macOS before claiming that validation.

## Testing

Override the encoder with the shipped `FakeMobileVideoEncoder`, and inject a
tester-backed `CaptureHost`, to drive the whole pipeline in a widget test with no
device. See this package's own test suite for the pattern.

For actual platform decoding, `examples/mobile_purrfect` provides
`integration_test/native_clip_reader_test.dart`: generated H.264 fixtures cover
B-frame presentation order, fractional/VFR timing, display rotation, RGBA
channel/row layout, nonsequential requests, and duplicate indices. The companion
`native_media_acceptance_test.dart` encodes, re-imports, trims, retimes and mixes
real clips, then retains files for independent FFmpeg pixel/PCM verification.
See that example's README for exact Android and iOS commands. The
`example_ios_media` CI job compiles the plugin and runs both suites on an iPhone
simulator; this does not establish physical-device performance or HEVC support.

## Documentation

See the Fluvie
[on-device mobile rendering guide](https://docs.fluvie.dev/guides/on-device-mobile-rendering/).

## License

MIT. See [LICENSE](https://github.com/SimonErich/fluvie/blob/main/packages/fluvie_mobile_encoder/LICENSE).
