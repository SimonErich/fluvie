# Performance

A render does two jobs in order: capture every frame, then encode them into a
file. This page explains what each costs, where the caches help, and the small
habits that keep a render fast. Start with the biggest lever, the frame cache:

```sh
# an unchanged composition, re-rendered: every frame is a cache hit
fluvie render ./lib/my_video.dart --out out.mp4 --cache
```

Run that twice and the second run reads frames from disk instead of pumping the
widget tree. The rest of this page covers why, and why you have to ask for it.

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

Captured frames are stored on disk, keyed by a render digest. The digest combines
the composition key, the render config, and the Fluvie version. On the next run, a
frame whose digest and index are already on disk replays from the cache without
pumping the tree at all. For a file target there is no registry key, so the file's
path stands in.

The cache is advisory: the digest does not cover the composition's source code. An
edited composition with the same size and frame count keeps the same digest, so it
would replay its old frames and you would render yesterday's video. A Fluvie
version bump invalidates every cached frame on its own.

That is why the cache is **off by default** when you render a `.dart` file. You
edit a file far more often than you re-render an unchanged one, so the safe
default is to capture fresh. Pass `--cache` when you know the composition has not
changed:

```sh
fluvie render ./lib/my_video.dart --out out.mp4                       # fresh capture
fluvie render ./lib/my_video.dart --out out.gif --format gif --cache  # reuse the frames
```

The second call hits the cache because `--format` changes only the encode, not
the capture. `--quality` and `--aspect` are part of the render config and so part
of the digest, so changing either one re-captures whether or not you pass
`--cache`.

A key render is the other way round: the cache is on, and `--no-cache` bypasses it
for one run.

## Content-hash caching loads media once

Media is the one thing that needs IO, so Fluvie resolves all of it before frame
0. A collect pass walks your scenes, gathers every `Image` and `Clip` source,
fetches the bytes, hashes them, and decodes them. During the frame loop every
media read is a synchronous cache lookup. No frame waits on a download or a
decode.

Each asset is keyed by the hash of its bytes, so identical declarations share
one load. Reuse a declaration to get the cache hit:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_15_snippets.dart (reuse-media)" -->
```dart
logo, // scene one: one decode
logo, // scene two: a cache hit on the same bytes
```

Two `Image.network` calls to the same URL also hash to the same bytes, so they
share a decode even when they are separate declarations.

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

Captured frames stream straight to a file as they are produced, so the captured
sequence does not sit in memory. The two things that do grow with the
composition are the resolved media cache (one decoded image or clip-frame set
per unique asset) and the frame cache on disk (one file per cached frame).

For a long video with many large stills, reuse declarations so the media cache
holds one copy per unique asset. For a quick draft, render a frame window with
`--frames N` to capture only the first `N` frames.

## Where to next

- [Multi-aspect](multi-aspect.md): why each aspect renders and caches
  independently.
- [Templates](templates.md): one definition per data row, the unit a batch
  shards on.
