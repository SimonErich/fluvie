# Determinism and caching

Fluvie renders are reproducible: the same input produces the same frames,
byte for byte. That is what makes the frame cache, golden tests, and batch
rendering safe. Render a video twice and the captured frames are identical:

<!-- code-excerpt "example/test/render/render_harness_self_test.dart (determinism-proof)" -->
```dart
for (final outDir in [outA, outB]) {
  await runCaptureHarness(
    tester: tester,
    entry: demoComposition,
    outDir: outDir,
    frameCountOverride: 8,
    cacheEnabled: false,
  );
}

expect(
  File('${outA.path}/frames.rgba').readAsBytesSync(),
  File('${outB.path}/frames.rgba').readAsBytesSync(),
); // byte-identical
```

This page explains the three things that guarantee it.

## The frame is the only clock

In capture mode there is no wall-clock and no async work inside a frame. Every
element reads the current frame and its time scope, and nothing else. There is
no `DateTime.now()` and no unseeded `Random()` in render code. Randomness flows
through seeded `noise(seed)` and `random(seed)`, so a seed reproduces a
sequence exactly.

## Media is pre-resolved before frame 0

Media is the one thing that needs IO, so Fluvie does all of it up front. Before
the first frame, a collect pass walks your scenes and gathers every `Image` and
`Clip` source. The resolver then resolves them all in one pass:

- fetch bytes (asset bundle, file, or allowlisted HTTP);
- content-hash the bytes;
- decode images to GPU images;
- probe each clip and extract the frames it will need.

During the frame loop, every media read is a synchronous cache lookup. No frame
ever waits on a download or a decode, so nothing pops in late, and two renders
resolve the same media the same way.

## Content-hash caching

Each resolved asset is keyed by the hash of its bytes. The same bytes resolve
once and replay from the cache; identical declarations across scenes share one
load. The hash is a fast, in-house FNV-1a, chosen because the cache needs a
path-safe key, not cryptographic strength.

The frame cache works the same way at the frame level. Each frame's render
digest combines the composition key, the config, and the Fluvie version. A
frame whose digest is already on disk replays without pumping the widget tree at
all. A version bump invalidates every cached frame.

## Seeded noise has one source

Randomness flows through a seeded noise source, and every reader shares it. The
effects (grain, particles, seeded float) and a `FrameBuilder`'s `ctx.noise` read
the same source, so a seed reproduces the same value wherever you read it.

That source lives behind a provider and a scope, so a host can override it for a
render while every reader still resolves the same value. The default source is
plain value noise, so an unoverridden render produces the exact same frames every
time, and every grain, glitch, particle, and float golden stays byte-identical.

## Templates render the same frames per props

A `VideoTemplate.build` is a pure function of its props, so the same template
rendered for the same props twice produces byte-identical frames. The render path
proves it: render three cards from a data list, and equal props give equal bytes
while different props give different bytes. This is what makes data-driven batch
rendering safe. Re-run a batch of a thousand rows tomorrow and every unchanged
row produces the file it did today.

## Multi-aspect is deterministic per aspect

`render(video, aspect:)` resolves the same plan for every aspect, so only the
layout branches; the timing does not. Each aspect is deterministic on its own
terms: render the same composition for the same aspect twice and the frames are
byte-identical. The per-aspect renders each carry their own canvas size in the
cache key, so the reel and the landscape cut cache separately and never collide.

## The network allowlist

Any fetch during a render is checked against an allowlist first. Only the
configured schemes (https by default) and hosts are allowed. A disallowed host
raises a typed error that names it. Tests never touch the live network: media
flows through an injected fake client or local fixtures.

## What "byte-identical" means

Frames are byte-identical on every machine. Encoded files are byte-identical
per machine, because ffmpeg builds differ. Encoder runs use bit-exact flags and
a single thread, so a given ffmpeg build always produces the same file.

## Where to next

- [Templates](templates.md): why the same props render the same frames, and how
  data-driven batches rely on it.
- [Multi-aspect](multi-aspect.md): why each aspect is deterministic on its own
  and caches separately.
- [Exporting your video](../guides/exporting-your-video.md): why frames are
  byte-identical everywhere and encoded files are per-machine.
- [Shaders and effects](shaders-and-effects.md): seeded randomness in action,
  for particles and organic float.
- [Cheatsheet](../reference/cheatsheet.md): the whole shipped surface on one
  page.
