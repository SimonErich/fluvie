# Render capabilities

The shared backend registry drives render preflight and this table. It describes library support, not a guarantee that a codec or host exists on every device. Choose supported settings before capture; unsupported requests fail with a capability diagnostic. Custom renderers provide their own profile.

| Capability | desktop | browser | mobile |
| --- | --- | --- | --- |
| Export formats | `gif`, `imageSequence`, `mp4`, `transparent` | `gif`, `imageSequence`, `mp4`, `transparent` | `mp4` |
| Video codecs | `h264`, `h265` | `h264`, `h265` | `h264`, `h265` |
| Pixel formats | `yuv420p`, `yuv420p10le`, `yuv444p` | `yuv420p`, `yuv420p10le`, `yuv444p` | `yuv420p` |
| Audio | yes | yes | yes |
| Owned snapshot host | yes | yes | yes |
| Exact clip presentation timing | yes | no | no |
| Target bitrate | yes | yes | yes |
| CRF control | yes | yes | no |
| Encoder presets | yes | yes | no |

### desktop

- Requires a Flutter capture host and a paired FFmpeg/ffprobe toolchain.
- In-process Flutter Snapshot is prepared automatically; external browser snapshots require SnapshotService.

Regression evidence: [packages/fluvie/test/rendering/desktop_video_renderer_test.dart](https://github.com/SimonErich/fluvie/blob/main/packages/fluvie/test/rendering/desktop_video_renderer_test.dart), [packages/fluvie_media/test/frame_session_integration_test.dart](https://github.com/SimonErich/fluvie/blob/main/packages/fluvie_media/test/frame_session_integration_test.dart), [packages/fluvie/test/rendering/encoding/video_probe_service_test.dart](https://github.com/SimonErich/fluvie/blob/main/packages/fluvie/test/rendering/encoding/video_probe_service_test.dart), [packages/fluvie/test/rendering/render_to_sandbox_test.dart](https://github.com/SimonErich/fluvie/blob/main/packages/fluvie/test/rendering/render_to_sandbox_test.dart).

### browser

- Requires supported browser decoding and FFmpeg wasm.
- Threaded wasm requires cross-origin isolation. Encoded bytes remain in browser memory.

Regression evidence: [packages/fluvie_web_encoder/test/web_video_renderer_test.dart](https://github.com/SimonErich/fluvie/blob/main/packages/fluvie_web_encoder/test/web_video_renderer_test.dart), [packages/fluvie/test/rendering/render_to_sandbox_test.dart](https://github.com/SimonErich/fluvie/blob/main/packages/fluvie/test/rendering/render_to_sandbox_test.dart).

### mobile

- Requires an Android/iOS Flutter host and available device codecs.
- Hardware decoding and encoding can vary by device.

Regression evidence: [packages/fluvie_mobile_encoder/test/on_device_video_renderer_test.dart](https://github.com/SimonErich/fluvie/blob/main/packages/fluvie_mobile_encoder/test/on_device_video_renderer_test.dart), [packages/fluvie/test/rendering/render_to_sandbox_test.dart](https://github.com/SimonErich/fluvie/blob/main/packages/fluvie/test/rendering/render_to_sandbox_test.dart).

A “no” for an owned snapshot host means the adapter does not provide that host by default. A suitable custom host can supply additional capabilities explicitly.

## Where to next

- [The rendering surface](rendering-surface.md): custom render requests and adapters.
- [Exporting your video](../guides/exporting-your-video.md): select an output.
