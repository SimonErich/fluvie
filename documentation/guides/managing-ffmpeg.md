# Managing FFmpeg

Fluvie encodes video with FFmpeg. You do not have to install it. The first time
you render, Fluvie downloads a pinned FFmpeg build, checks it, and caches it:

```sh
fluvie render demo --out demo.mp4
# FFmpeg not found. Downloading FFmpeg 8.1 GPL (BtbN 2026-05-31, ...)
# Wrote demo.mp4
```

The build lands in a per-user cache and every later render reuses it. Nothing to
install, nothing on your PATH.

## Install it ahead of time

To fetch FFmpeg before your first render (for example in a setup script), run:

```sh
fluvie ffmpeg install
```

It downloads the build, verifies its SHA-256 checksum, unpacks it into the
cache, and confirms it runs. Run it again to do nothing; pass `--force` to
re-download.

## See what Fluvie will use

```sh
fluvie ffmpeg status   # the pinned build, the cache path, and whether it is installed
fluvie ffmpeg path     # just the managed binary path
fluvie ffmpeg uninstall # remove the managed build
```

The cache lives under `~/.cache/fluvie/ffmpeg/` on Linux and macOS, and
`%LOCALAPPDATA%\fluvie\ffmpeg\` on Windows.

## Use your own FFmpeg instead

Fluvie resolves FFmpeg in this order, and stops at the first one that works:

1. `--ffmpeg <path>` on the render command.
2. The `FLUVIE_FFMPEG` environment variable.
3. The managed cache build (from `fluvie ffmpeg install`).
4. `ffmpeg` on your PATH.

So to use a specific binary, point at it:

```sh
fluvie render demo --out demo.mp4 --ffmpeg /opt/ffmpeg/bin/ffmpeg
# or
export FLUVIE_FFMPEG=/opt/ffmpeg/bin/ffmpeg
```

Your own binary must be FFmpeg 6.0 or newer.

## Turn off the download

To never download (for example on an offline or locked-down machine), pass
`--no-download`. Fluvie then uses only an explicit binary, `FLUVIE_FFMPEG`, the
cache, or PATH, and fails with a clear message if none is found:

```sh
fluvie render demo --out demo.mp4 --no-download
```

## Reproducible across machines

Fluvie pins one exact FFmpeg build, by URL and checksum. Because every machine
that auto-provisions gets the same build, the encoded file is byte-identical
across machines, not just on one. The Docker render image provisions the same
pinned build at build time, so server renders match your local ones. See
[Determinism and caching](../advanced/determinism-and-caching.md).

## A note on licensing

The pinned build is a GPL FFmpeg (it includes the libx264 H.264 encoder). Fluvie
downloads it at runtime; it is not shipped inside the Fluvie package, and Fluvie
itself stays MIT. If your project must avoid GPL binaries, install an
FFmpeg you trust and point `FLUVIE_FFMPEG` at it, with `--no-download` on.

## Where to next

- [Exporting your video](exporting-your-video.md): formats, quality, and posters.
- [Rendering on a server](rendering-on-a-server.md): the HTTP API and Docker image.
