#!/usr/bin/env bash
# Vendor the ffmpeg.wasm files this app serves from web/ffmpeg/.
#
# The wasm core is tens of megabytes, so it is fetched here instead of being
# committed. Run this once before `flutter run -d chrome` or `flutter build web`.
# Needs npm on PATH.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$here/web/ffmpeg"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Pin the same versions the web encoder's end-to-end test verifies.
( cd "$work" && npm install --silent --no-save \
    @ffmpeg/core@^0.12.10 @ffmpeg/ffmpeg@^0.12.15 @ffmpeg/util@^0.12.2 )

mods="$work/node_modules/@ffmpeg"
mkdir -p "$dest/core" "$dest/ffmpeg" "$dest/util"
cp "$mods/core/dist/umd/ffmpeg-core.js" "$mods/core/dist/umd/ffmpeg-core.wasm" "$dest/core/"
cp "$mods/ffmpeg/dist/esm/"* "$dest/ffmpeg/"
cp "$mods/util/dist/esm/"* "$dest/util/"

echo "Vendored ffmpeg.wasm into $dest"
