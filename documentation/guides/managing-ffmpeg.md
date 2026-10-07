# Managing FFmpeg

Fluvie encodes video with FFmpeg. You do not have to install it. The first time
you render, Fluvie downloads a pinned FFmpeg/ffprobe pair, verifies both tools, and caches them:

```sh
fluvie render ./lib/my_video.dart
# FFmpeg not found. Downloading FFmpeg 8.1 GPL (BtbN 2026-05-31, ...)
# Wrote build/fluvie/my_video.mp4
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

Concurrent renders share an installation lock. A second process waits up to
30 seconds and reports its waiting progress instead of downloading another copy.
If the first installation takes longer, `toolchain_busy` identifies the lock and
keeps the existing installation intact. Wait for that process to finish and
retry, or use `--toolchain system` with FFmpeg and ffprobe already on PATH.
Applications using `FfmpegProvisioner` directly can set `lockTimeout`; normal
commands use the bounded default.

## See what Fluvie will use

```sh
fluvie ffmpeg status   # the pinned build, the cache path, and whether it is installed
fluvie ffmpeg path     # just the managed binary path
fluvie ffmpeg uninstall # remove the managed build
```

The cache lives under `~/.cache/fluvie/toolchains/<build>/<architecture>/bin/`
on Linux and macOS (`XDG_CACHE_HOME` overrides the cache root), and
`%LOCALAPPDATA%\fluvie\toolchains\` on Windows. Both executables share the
same build and architecture directory. No administrator access or consumer
project dependency is required.

## Use your own FFmpeg instead

The default `--toolchain managed` uses the pinned pair. To opt into binaries on
PATH, use `--toolchain system`. To select a pair explicitly, pass both paths:

```sh
fluvie render ./lib/my_video.dart --ffmpeg /opt/ffmpeg/bin/ffmpeg --ffprobe /opt/ffmpeg/bin/ffprobe
fluvie render ./lib/my_video.dart --toolchain system
```

`FLUVIE_FFMPEG` and `FLUVIE_FFPROBE` provide the same overrides. A named
executable must work; Fluvie reports its failure instead of silently replacing
it. With only `--ffmpeg`, the CLI looks for its companion `ffprobe` beside it.
Your own tools must be FFmpeg 6.0 or newer.

## Turn off the download

On an offline machine, warm the managed cache once, then use `--no-download`:

```sh
fluvie ffmpeg install
fluvie render ./lib/my_video.dart --no-download
fluvie doctor --json
```

The managed mode does not fall back to an unrelated PATH binary. `doctor` only
inspects setup; it never installs tools. A missing managed pair is reported
with the automatic installation path and a command to warm the cache.

## Reproducible across machines

Fluvie pins each supported platform and architecture's FFmpeg/ffprobe downloads
by URL, size, and checksum. Machines with the same target receive the same
archives. The Docker render image provisions its matching pinned pair at build
time. The build identity and exact version banners are available in diagnostics
and render receipts. Matching tools and authored timing make renders replayable;
raster output can still differ across Flutter platforms.

## A note on licensing

The pinned build is a GPL FFmpeg (it includes the libx264 H.264 encoder). Fluvie
downloads it at runtime; it is not shipped inside the Fluvie package, and Fluvie
itself stays MIT. If your project must avoid GPL binaries, install an
FFmpeg you trust and point `FLUVIE_FFMPEG` and `FLUVIE_FFPROBE` at its pair, with `--no-download` on.

## Where to next

- [Exporting your video](exporting-your-video.md): formats, quality, and posters.
- [Rendering on a server](rendering-on-a-server.md): the HTTP API and Docker image.
