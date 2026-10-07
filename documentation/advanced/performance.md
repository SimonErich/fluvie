# Performance

A render does two jobs in order: capture every frame, then encode them into a
file. This page explains what each costs, where the caches help, and the small
habits that keep a render fast. Start with the biggest lever, the frame cache:

```sh
# an unchanged composition, re-rendered: every frame is a cache hit
fluvie render ./lib/my_video.dart
```

Run that twice and the second run reads frames from disk instead of pumping the
widget tree. File renders enable this cache automatically.

## Keep the authoring engine warm

`fluvie workspace lib/my_video.dart` keeps one Flutter worker alive per source
revision. Exact frames, reviews and exports reuse compilation and engine startup.
Each request still mounts a fresh composition and releases its media. Source
changes retire the worker, and edits during rendering reject stale results.
Measure `startupMilliseconds`, `captureMilliseconds` and `elapsedMilliseconds`
separately. See [the authoring workspace](../guides/authoring-workspace.md).

## Capture and encode are two phases

Capture pumps the widget tree to each frame in turn and reads its pixels. The
frame is the only clock, so capture is sequential: frame `n` is built and read
before frame `n + 1`. Capture cost scales with the frame count and with how much
work each frame's tree does.

Encode hands the captured frames to FFmpeg, which compresses them into the
container. Encode cost scales with the resolution, the frame count, and the
quality. A higher `Quality` (a lower CRF) writes a bigger file and takes longer.

For most videos capture dominates. A 6 second reel at 30 fps is 180 frames, and
each frame pumps a full tree. The encode is one FFmpeg pass over those frames.

## The frame cache skips repeated work

Captured frames are stored on disk, keyed by a render digest and frame index.
For a Dart file, the CLI adds a content fingerprint covering project-local Dart
sources, including helpers and parts outside `lib/`, resolved dependency Dart
code, pubspec and package resolution, assets and fonts,
explicit renderer or harness files, export options, and toolchain identity.
Editing a source file or replacing an asset invalidates the cached frames even
when the video keeps the same duration and dimensions.

Build/tool caches and generated adapter directories are excluded from the
project scan. A target or renderer physically outside the selected project
disables frame caching unless you supply a caller-owned `--cache-key`: its
external relative dependency closure is not covered. Include a version or hash
for external input in that key and change it when the input changes. Runtime
network data, generators and undeclared external files need `--no-cache` when
you cannot establish a reliable identity.

An unchanged file render reuses frames by default. Changing an export option also
changes the fingerprint; this conservative rule can recapture frames even when
an option affects only encoding. Use `--no-cache` to force fresh capture:

```sh
fluvie render ./lib/my_video.dart
fluvie render ./lib/my_video.dart --no-cache
```

The CLI does not automatically track changing network content. Built-in
`generate` and `edit` author-and-render operations capture fresh. A custom
programmatic renderer must supply its own stable composition identity when it
enables frame caching; the CLI source fingerprint belongs to the CLI host.
See the [cache identity contract](../guides/exporting-your-video.md#the-frame-cache)
for the command-line and `runRenderPipeline` options.

## Content-hash caching loads media once

Preparation mounts the composition's real Flutter tree, gathers its media,
resolves images, and probes clips before capture. Resource bytes and decoded
images are shared through content-hash caches. Clip source frames use a bounded
frame cache instead of decoding an entire long clip upfront.

Painting reads prepared media synchronously. The preparation step for a capture
frame can still await clip decoding; that work happens before pumping and reading
the widget's pixels. Synchronous paint lookup does not mean decoding is free.

Each asset is keyed by the hash of its bytes, so identical declarations share
one load. Reuse a declaration to get the cache hit:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (reuse-media)" -->
```dart
logo, // scene one: one decode
logo, // scene two: a cache hit on the same bytes
```

Two `Image.network` calls to the same URL also hash to the same bytes, so they
share a decode even when they are separate declarations.

## Native clip decoding stays bounded

Persistent decoded clip frames also include the extractor's implementation/build
identity in their key, alongside source content, dimensions and decoder choice.
The default desktop extractor streams a SHA-256 of the resolved FFmpeg executable
and hashes its full version/build output. It memoizes that lookup by canonical
path, size and filesystem times, with up to 16 build lookups retained; normal
binary replacement invalidates reuse without per-frame hashing. Changes that
preserve all of those filesystem metadata values are outside that memoization
contract.

A custom extractor can implement `FrameExtractionCacheIdentity` and return a
stable `cacheIdentity`, or supply an explicit identity to
`FfmpegFrameExtractionService` when using an injected process runner. Include
every pixel-affecting setting and change it when output can change. Missing,
empty or unavailable identities disable persistent clip-frame reuse; bounded
in-run decoding remains available. The versioned cache key leaves older entries
cold so an earlier decoder build cannot silently supply new pixels.

Package export hosts look ahead 15 frames, grouping up to 16 source-frame requests
into one decode. A per-source 32 MiB RGBA budget limits batch size and retained
scrub frames, normally to at most 16 indices. This is a soft budget: a single
larger frame or simultaneously required pictures can exceed it. Direct preview
seeks use zero lookahead. Future clip
windows wait until visible, and a seek that needs a held final picture reuses
that picture. Replaced decode-all frame handles are released after painting.
Advanced hosts can tune `CompositionSession.clipLookaheadFrames` on the rendering
barrel; ordinary CLI renders use the package default automatically.

A local two-second H.264 fixture at 160×90 and 30 fps took 2,741 ms for 60 cold
single-frame native requests, compared with 221 ms for four batches of up to 16
frames: about 12.4 times faster, with identical concatenated RGBA hashes. This is
one extraction measurement; resolution, codec, source offset, and machine change
the cost.

The default native clip reader keeps an owned FFmpeg frame session. Sequential
requests continue from the decoder's current position; backward seeks restart it.
Only requested pixels enter the Dart frame cache. A distant or backward request
seeks from an indexed source keyframe and verifies the first decoded presentation
timestamp. If the demuxer cannot establish exact alignment, the reader falls back
to decoding from the origin. `decoderStarts` and `framesRead` expose the work for
diagnostics; long GOPs and uncertain seek alignment can still cost more.
Close the session when its source is released. Timeout,
cancellation and disposal terminate and reap its owned decoder.
The local HTTP bridge used by browser preview retains at most four source
sessions with least-recently-used eviction. Decoded frame caching is bounded to
32 MiB; releasing a source or closing the bridge closes its owned decoder.

Native timing uses presentation timestamps rather than average FPS when a source
has variable frame intervals. `MediaTimeline` normalizes the first displayed
picture to time zero and preserves the final picture's interval. The default
native resolver supplies that index to clip trim, speed and resampling logic.
Custom media resolvers can expose `ClipTimelineResolver`. Browser byte decoders
can additionally implement `WebClipTimelineDecoder` from the rendering barrel;
`WebImageMediaResolver` uses its `MediaTimeline` when one is available. The local
preview bridge supplies the native source index through this interface. A decoder
without a source timeline falls back to its reported constant frame rate.

## Keep snapshots pre-resolved

A `Snapshot`, `Mermaid`, `WebView`, or `Html` is rasterized once before the
frame loop and painted every frame from the cached image. That pre-pass is the
expensive part, and it runs outside capture. Declare a snapshot once and reuse
the result rather than rebuilding the source every frame.

## Parallelism is per render, not per frame

One render captures frames in order, so a single composition does not split
across cores at the frame level. Parallelism lives one level up: each render is
an independent, deterministic process.

- A data-driven batch renders one definition per row. The rows are independent,
  so run them as separate processes across your cores.
- A multi-aspect fan-out renders the same definition to reels, square,
  landscape, and portrait. Each aspect is an independent render and caches under
  its own canvas size, so they never collide.

Because every render is independent, a batch is safe to shard: re-run only the
rows that changed, on as many workers as you have.

## Keep animation lists stable

The resolver must see the same animations on every frame. An element inside a
per-frame `Builder` rebuilds each frame, so a fresh list literal inside that
builder registers a new token after resolution and throws. Hoist the list to a
stable field instead:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (stable-list)" -->
```dart
Builder(
  builder: (context) => const Text('Stable', style: _line).animate(_stablePop),
);
```

`_stablePop` is a `final List<Animation>` declared once, so every rebuild binds
the same list. Lessons 11 and 12 follow this rule for every element inside a
`Builder`. An element built once (directly in a scene's `children`) can keep its
inline list.

## Memory for large compositions

Default native reactive-audio analysis decodes the audible source interval plus
250 ms of FFT/onset lookahead. Declared `Audio` tracks share the encoder's timing
resolution: trims start at source time, scene and sound-effect delays place the
analysis on the composition clock, and loops repeat the decoded interval. Source
EOF carries its actual duration so a fractional-frame loop does not accumulate
rounding drift. Energies and beats are silent outside the audible window.

`AudioWindowResolver`, `RangedBeatDetectionService` and
`RangedFrequencyAnalyzer` are additive capabilities for custom hosts. The ranged
band result includes the actual source duration. Existing resolvers retain their
source-only contract; existing analysis services can analyze the needed source
prefix for a window-aware repository. Native `FfmpegPcmDecoder.decodeRange`
seeks and bounds the decoded interval. Legacy PCM decoders can be sliced after
full decoding; their peak allocation remains the delegate's responsibility.

Reactivity still reads normalized energies from the selected track, with the
first audible declared track as the default. This is not analysis of the encoded
master mix, gain automation or clipping. Generated audio without a declared
track window retains the source-only fallback.

Default reactive-audio preparation shares one PCM decode between beat detection
and frequency-band analysis for the same source. `SharedPcmDecoder` coalesces
equal active requests and retains at most one completed source and 128 MiB by
default, counting the backing buffer. Preparation releases that PCM after the
derived beat grids and band tables are built, including on failure. A failed band
analysis publishes neither table, so retry can prepare the complete source.
Injected analysis services keep their own decoder ownership.

Custom hosts can share `SharedPcmDecoder` between their analysis services, tune
`maxBytes`/`maxSources`, and call `clear()` when source files change or `dispose()`
when the preparation ends. Its budgets bound completed retention, not allocations
inside a delegate or samples still held by callers. Disposal rejects pending
requests but does not dispose an injected delegate; connect the same cancellation
signal to any native decoder it owns.

Captured frames stream straight to a file as they are produced, so the captured
sequence does not sit in memory. The things that do grow with the
composition are the resolved resource bytes and images, bounded clip-frame
caches, and the frame cache on disk (one file per cached frame).

For a long video with many large stills, reuse declarations so the media cache
holds one copy per unique asset. For a quick draft, render a frame window with
`--frames N` to capture only the first `N` frames.

## Where to next

- [Multi-aspect](multi-aspect.md): why each aspect renders and caches
  independently.
- [Templates](templates.md): one definition per data row, the unit a batch
  shards on.
