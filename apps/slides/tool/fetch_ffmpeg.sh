#!/usr/bin/env bash
# Vendor the ffmpeg.wasm files the web build serves from web/ffmpeg/.
#
# The wasm core is tens of megabytes, so it is fetched here instead of being
# committed. Run this once before `flutter run -d chrome` (or a web deploy)
# to enable in-browser video export. Needs npm on PATH.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$here/web/ffmpeg"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Pin the same versions fluvie_web_encoder's end-to-end test verifies.
( cd "$work" && npm install --silent --no-save \
    @ffmpeg/core@^0.12.10 @ffmpeg/ffmpeg@^0.12.15 @ffmpeg/util@^0.12.2 mp4box@^0.5.2 )

mods="$work/node_modules/@ffmpeg"
mkdir -p "$dest/core" "$dest/ffmpeg" "$dest/util"
cp "$mods/core/dist/esm/ffmpeg-core.js" "$mods/core/dist/esm/ffmpeg-core.wasm" "$dest/core/"
cp "$mods/ffmpeg/dist/esm/"* "$dest/ffmpeg/"
cp "$mods/util/dist/esm/"* "$dest/util/"

mkdir -p "$here/web/vendor/mp4box"
cp "$work/node_modules/mp4box/dist/mp4box.all.min.js" "$here/web/vendor/mp4box/"
echo "Vendored ffmpeg.wasm and MP4 demuxer into $here/web"
