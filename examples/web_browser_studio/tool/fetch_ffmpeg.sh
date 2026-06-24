#!/usr/bin/env bash
# Vendor the web runtime files this app serves: ffmpeg.wasm (web/ffmpeg/, the
# encoder behind FluvieFfmpeg) and mp4box.js (web/vendor/mp4box/, the demuxer
# behind the FluvieClipDecoder bridge that decodes Clip.asset in the browser).
#
# These are tens of megabytes, so they are fetched here instead of committed.
# Run this once before `flutter run -d chrome` or `flutter build web`. Needs npm.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$here/web/ffmpeg"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Pin the same versions the web encoder's end-to-end test verifies.
( cd "$work" && npm install --silent --no-save \
    @ffmpeg/core@^0.12.10 @ffmpeg/ffmpeg@^0.12.15 @ffmpeg/util@^0.12.2 mp4box@^0.5.2 )

mods="$work/node_modules/@ffmpeg"
mkdir -p "$dest/core" "$dest/ffmpeg" "$dest/util"
# The ESM core: @ffmpeg/ffmpeg runs its worker as type: "module", which cannot
# importScripts the UMD core, so it dynamic-imports this one (it has a default
# export). Vendoring the UMD core fails the import at load with no signal.
cp "$mods/core/dist/esm/ffmpeg-core.js" "$mods/core/dist/esm/ffmpeg-core.wasm" "$dest/core/"
cp "$mods/ffmpeg/dist/esm/"* "$dest/ffmpeg/"
cp "$mods/util/dist/esm/"* "$dest/util/"

# mp4box.js: the UMD bundle the FluvieClipDecoder bridge loads lazily.
mkdir -p "$here/web/vendor/mp4box"
cp "$work/node_modules/mp4box/dist/mp4box.all.min.js" "$here/web/vendor/mp4box/"

echo "Vendored ffmpeg.wasm into $dest and mp4box.js into $here/web/vendor/mp4box"
