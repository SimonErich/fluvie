# fluvie_media

Flutter-independent media work for Fluvie's CLI, rendering and local browser preview. Native tools probe source metadata and decode sorted, deduplicated frame requests in bounded batches, preserving alpha and using exact configured FFmpeg/ffprobe paths.

Import `package:fluvie_media/fluvie_media.dart` for web-safe frame values and batch planning, or `package:fluvie_media/native.dart` for `FfmpegMediaTools`. Close the native tools when the owning render or preview ends; timeouts and disposal terminate their child processes.

Managed probes, frame decoders and contact sheets accept local paths and local
file URIs, not network URLs or file URIs with remote hosts. They explicitly
restrict FFmpeg input protocols to `file`, including resources referenced by a
local playlist. Download allowed network sources through your allowlisted loader
first, then pass the staged local path. The low-level `run` operation preserves
your arguments; input validation and protocol restrictions remain your
responsibility for custom commands.

Tests can inject a collected-output `runner` and a streaming `processStarter`.
The latter returns an owned `Process`, so the same frame-reading, cancellation
and disposal logic runs with either an in-memory adapter or a real native child.

`MediaTimeline` records normalized presentation timing, including variable-rate
frames and the final picture interval. `probeTimeline` obtains that source index.
`openFrameSession` owns a forward FFmpeg decoder: sequential requests reuse its
position; distant and backward reads restart from an indexed keyframe, verify
presentation alignment and fall back to the origin when exact alignment is
uncertain. `decoderStarts` and `framesRead` expose decode work. Close the session when its source is
released. `whenCancelled` stops owned native work; custom process runners must
handle their own cancellation.

`contactSheet` writes a bounded, letterboxed PNG and returns source frame indexes
and actual presentation times. It records visual evidence without inventing
descriptions or uploading pictures to an authoring model. Default samples cover
the source timeline; explicit timestamps select source seconds. Native tool
timeouts, cancellation and output failures still apply.

`RenderCapabilities` supplies the shared versioned desktop, browser and mobile
profiles used by backend preflight, CLI diagnostics and the
[capability documentation](https://docs.fluvie.dev/reference/render-capabilities/).

The Fluvie CLI provisions the platform toolchain automatically. Native adapters also honor `FLUVIE_FFMPEG` and `FLUVIE_FFPROBE`. This package performs no semantic asset analysis.
