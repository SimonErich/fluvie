#!/usr/bin/env bash
# Regenerate the landing-page example gallery clips.
#
# Two phases, run for every lesson key:
#   1. Render  build/<key>.mp4 with the Fluvie CLI, capturing with Impeller
#      (flutter test --enable-impeller). Falls back to the default tester
#      backend per key if the Impeller pass fails (e.g. a headless box with no
#      GPU). Skip this phase with --encode-only.
#   2. Encode  web/landing/media/<key>.{mp4,webm,poster.webp,gif} for the
#      gallery: a muted looping MP4 (primary <video>), a smaller VP9 WebM, a
#      first-frame poster, and a two-pass-palette GIF fallback.
#
# Re-run any time. The MP4/WebM are the page's <video> sources; the GIF is the
# no-JS / reduced-motion fallback. After regenerating, run the `sync-website`
# skill (or hand-edit web/landing/index.html) to add or refresh the tiles, then
# commit the media with the HTML. See web/landing/MAINTAINING.md.
#
# Needs ffmpeg on PATH (always) and a Flutter SDK (unless --encode-only).
# Determinism note: Fluvie frames are byte-identical, but ffmpeg builds differ
# across machines, so regenerate every asset on one machine in one pass and
# commit them together.
# If a render stalls at 0% CPU, the frame cache may have filled /tmp; clear
# /tmp/fluvie_* and re-run.
#
# Usage:
#   tool/web/regenerate_gallery.sh                # render (Impeller) + encode all
#   tool/web/regenerate_gallery.sh --encode-only  # re-encode existing build/*.mp4
#   tool/web/regenerate_gallery.sh --no-impeller  # render with the default backend
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

SRC_DIR="build"
OUT_DIR="web/landing/media"
CLI="packages/fluvie_cli/bin/fluvie.dart"

WIDTH=480
VIDEO_FPS=24
GIF_FPS=15

# The numbered lessons shown in the gallery. The internal `demo`/`multi_scene`
# smoke keys are intentionally excluded. Keep this in sync with the
# `render:examples` key list in pubspec.yaml when a lesson is added.
KEYS=(
  01_hello_video
  02_text_and_motion
  03_timing_and_triggers
  04_scenes_and_transitions
  05_images_and_clips
  06_collage
  07_charts
  08_code_doc_intro
  09_diagrams_and_webviews
  10_audio_and_captions
  11_templates_and_aspects
  12_the_kitchen_sink
)

encode_only=0
use_impeller=1
for arg in "$@"; do
  case "$arg" in
    --encode-only) encode_only=1 ;;
    --no-impeller) use_impeller=0 ;;
    -h|--help) sed -n '2,40p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown argument: $arg (try --help)" >&2; exit 2 ;;
  esac
done

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is not on PATH" >&2; exit 1; }
if [ "$encode_only" -eq 0 ]; then
  command -v dart >/dev/null 2>&1 || { echo "dart is not on PATH (or pass --encode-only)" >&2; exit 1; }
  mkdir -p "$SRC_DIR"
fi
mkdir -p "$OUT_DIR"

render_key() {
  local key="$1" out="$SRC_DIR/$1.mp4"
  if [ "$use_impeller" -eq 1 ]; then
    echo "Rendering $key (Impeller)…"
    if dart run "$CLI" render "$key" --out "$out" --enable-impeller; then
      return 0
    fi
    echo "  Impeller render failed for $key; retrying with the default backend…" >&2
  fi
  echo "Rendering $key…"
  dart run "$CLI" render "$key" --out "$out"
}

encode_key() {
  local key="$1" src="$SRC_DIR/$1.mp4"
  if [ ! -f "$src" ]; then
    echo "missing $src — run without --encode-only first to render it" >&2
    exit 1
  fi
  local scale="scale=${WIDTH}:-2:flags=lanczos"
  echo "Encoding gallery assets for $key…"

  # 1) MP4 (H.264, web-streamable, muted) — the primary <video> source.
  ffmpeg -y -i "$src" -an -movflags +faststart \
    -vf "fps=${VIDEO_FPS},${scale}" \
    -c:v libx264 -profile:v main -pix_fmt yuv420p -crf 26 -preset slow \
    "$OUT_DIR/$key.mp4"

  # 2) WebM (VP9, muted) — a smaller extra <source>.
  ffmpeg -y -i "$src" -an \
    -vf "fps=${VIDEO_FPS},${scale}" \
    -c:v libvpx-vp9 -b:v 0 -crf 34 -row-mt 1 \
    "$OUT_DIR/$key.webm"

  # 3) Poster (first frame) for the <video> placeholder and reduced-motion.
  ffmpeg -y -i "$src" -vf "$scale" -frames:v 1 "$OUT_DIR/$key.poster.webp"

  # 4) GIF fallback — two-pass palettegen/paletteuse for a clean loop.
  local palette
  palette="$(mktemp --suffix=.png)"
  ffmpeg -y -i "$src" -vf "fps=${GIF_FPS},${scale},palettegen=stats_mode=diff" "$palette"
  ffmpeg -y -i "$src" -i "$palette" \
    -lavfi "fps=${GIF_FPS},${scale}[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" \
    -loop 0 "$OUT_DIR/$key.gif"
  rm -f "$palette"
}

for key in "${KEYS[@]}"; do
  [ "$encode_only" -eq 0 ] && render_key "$key"
  encode_key "$key"
done

echo
echo "Wrote ${#KEYS[@]} gallery clips to $OUT_DIR/"
echo "Next: run the sync-website skill (or edit web/landing/index.html) to refresh the tiles."
