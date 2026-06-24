# On-device mobile rendering

Render a Fluvie video to an MP4 on a phone, with no FFmpeg, no server, and no
network. The frames never leave the device, so generation is private by
construction. This is what [`fluvie_mobile_encoder`](https://pub.dev/packages/fluvie_mobile_encoder)
adds, on Android and iOS.

You write the same `Video` you would render anywhere. Only the renderer changes:

<!-- code-excerpt "examples/gallery/lib/on_device/on_device_page.dart (render)" -->
```dart
final renderer = OnDeviceVideoRenderer();
final file = await renderer.render(
  composition: lesson10Video(),
  aspect: Aspect.landscape,
  duration: const Duration(seconds: 4),
  longEdge: 480,
  audio: _withAudio, // mix and mux the lesson's music bed on the device
  onProgress: (progress) => debugPrint('on-device render: ${progress.phase.name}'),
);
```

The result is an MP4 in the app's temporary directory, ready to share or save. A
runnable demo lives in the example app, with its own entry point:

```sh
flutter run -t lib/on_device/on_device_page.dart   # on a device or simulator
```

## How it works

A normal Fluvie render is two steps: capture the widget tree to raw frames, then
encode those frames with FFmpeg. FFmpeg cannot run on a phone, so this package
keeps the capture step exactly and swaps the encode step for the platform's own
hardware video encoder.

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

Both encoders ship on the device and are already licensed for H.264 and HEVC, so
there is nothing to download and no codec to bundle.

## The advantages

- **Privacy.** The frames are captured and encoded on the device. Nothing is
  uploaded, so there is no server that can see, cache, or index the video.
- **No render bill and no wait.** No round trip to a render service.
- **Hardware accelerated.** The platform encoders run on dedicated silicon.

## The trade-offs

Because the capture half is Fluvie's own, every element, animation, and
transition renders identically to a desktop render. The trade-offs are all at the
encode edge:

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
then decodes, mixes, and muxes them (Android `MediaCodec`, iOS AVFoundation), so
the on-device mix matches the desktop one.

Pass `audio: true` to `OnDeviceVideoRenderer.render` to turn it on. Bundle your
audio as an asset or pass a local file path. A looping `Audio.music(loop: true)`
bed fills the whole video on both Android and iOS. For a network source,
construct the renderer with a `NetworkAudioMaterializer` and a `NetworkAllowlist`
of permitted hosts; the bytes are fetched to a local file, then mixed as usual.
If a `Video` declares audio but you leave `audio` off, the render is silent and
the renderer warns once through `OnDeviceVideoRenderer.onWarning` — pass
`warnOnDroppedAudio: false` to silence it.

See [Audio across platforms](audio-and-captions.md#audio-across-platforms) for the
full per-platform support table.

## Clips

A `Clip` plays its real frames on-device — no FFmpeg. The platform decoder
(Android `MediaMetadataRetriever`/`MediaExtractor`, iOS AVFoundation) extracts
the source frames the clip's window reads, the same resample math the desktop
uses, so motion matches a desktop render. A clip's embedded audio is mixed in
when you pass `audio: true`, delayed to where the clip plays and trimmed to its
window, alongside any declared `Audio` tracks.

Clip frames **stream through a disk-backed store** instead of all living in
memory: the pre-pass extracts the window's frames to a temp directory, and the
capture loop decodes only the few frames each composition frame paints, evicting
the rest. So a full-resolution or multi-second clip renders without the decode
cache exhausting the app heap — only a small, bounded window is ever decoded at
once, and the store is deleted when the resolver is disposed. Frames are decoded
at most at the render's own resolution (a 4K source is scaled down to the reel
size it is composited into), which bounds both the window and the throughput.

The browser renders the same clips through WebCodecs instead of a native decoder;
because a page has no file system to stream to, it decodes them all into memory
rather than through a disk store — see [web clips](on-device-web-rendering.md#clips).

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
