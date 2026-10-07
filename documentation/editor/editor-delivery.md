# Delivery

Quick export offers Draft, Share and Master presets. Draft selects up to 720 px
and a fast low-quality H.264 encode; Share selects up to 1080 px at high quality;
Master keeps the authored canvas at maximum quality. Presets never upscale a
smaller document. Deliver opens the encoder controls by default.

## Encoder controls

MP4 supports H.264 and H.265, an explicit CRF from 0 to 51 or a positive target
bitrate, a closed set of encoder speed presets, and yuv420p, yuv420p10le or
yuv444p output. CRF and bitrate are mutually exclusive. The default remains
H.264, quality high, medium preset and yuv420p; absent knobs preserve the
existing argument list and serialization.

<!-- code-excerpt "examples/gallery/lib/snippets/spec_serialization_snippets.dart (delivery-encoder)" -->
```dart
const settings = Export.mp4(
  codec: ExportCodec.h265,
  crf: 21,
  preset: EncoderPreset.fast,
  pixelFormat: ExportPixelFormat.yuv420p10le,
);
```

The dialog's choices affect one render snapshot. The saved document changes
only when explicitly edited. Frame-rate changes are document edits because
all timing is measured in composition frames.

Desktop and browser FFmpeg receive typed, validated argument arrays. Browser
codec availability depends on the installed FFmpeg build; an unavailable codec
fails visibly. Mobile hardware export accepts codec and target bitrate and
rejects software-only CRF, preset and pixel-format requests before capture.

## Cancellation and cleanup

Each export can carry a `RenderCancellation` token. Desktop capture checks it
between frames; encoding terminates the FFmpeg child process and waits for it
to exit before deleting the partial sandbox. Failed renders also remove their
sandbox. Successful desktop delivery copies the completed artifact to the
chosen location and then removes the temporary render files.

Browser cancellation terminates the FFmpeg worker, resets its loaded state and
clears the in-memory capture sandbox. A later job reloads the worker. Successful
and failed encodes delete staged virtual input/output files. The browser bridge
must expose `terminate` and `deleteFile` for cancellable jobs; unsupported
bridges fail explicitly. Disposing the desktop capture surface unmounts the
widget subtree before releasing the render pipeline.

Maintained tests exercise typed argument combinations, legacy defaults,
round-trip digests, actual H.264/H.265 encodes, real process cancellation,
partial-sandbox removal, browser worker reload/cleanup, and desktop capture
subtree disposal.

The maintained browser acceptance runs the app's real local FFmpeg worker and
WebCodecs bridge, including encode, cancellation, reload, staged-file cleanup,
first/middle/last source-frame pixels, embedded-audio metadata, and bounded RGBA
retention. Run `dart apps/slides/tool/verify_web_encoder.dart` after vendoring
browser assets. Source video preview currently demuxes MP4/MOV ISO BMFF files;
other containers report that conversion is needed. Browser codec availability
also depends on WebCodecs support for the file's video codec.

## Preview quality and background exports

Full, Half and Quarter bound the preview's decoded clip raster. A 4K RGBA frame
uses about 31.6 MiB at Full, 7.9 MiB at Half and 2.0 MiB at Quarter. Scrubbing
keeps a bounded recent-frame cache. Layout and source timing stay the same.
Draft can bypass effects and grades; the stage explicitly labels that choice.
These preferences never modify the project or an export snapshot.

Add exports to the Deliver queue or choose **Batch 1080p + 720p**. Each job owns
the project snapshot taken when queued, so later edits do not change an ongoing
render. Jobs run in order, display progress and can be cancelled individually.
A failed job leaves following jobs runnable. The queue survives workspace
switches and belongs to the current editor session, rather than disk storage.

The repeatable optimized performance checks are
`bash tool/verify_editor_performance.sh profile` and
`bash tool/verify_editor_performance.sh release`.
They drive a three-minute 4K project with eight lanes and 240 placements sharing
one six-second source on Linux, measuring loading, digest work, timeline gestures,
canvas drag, source decoding and preview capture. Engine frame timings are
recorded separately from test-driver latency. Reproduction steps and measurement
limits are in the [release verification guide](../contributing/editor-release-verification.md).
The complete native journey saves and reopens identical project data, continues
editing during rendering, then verifies both real MP4 artifacts with ffprobe.
