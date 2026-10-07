#!/usr/bin/env bash
# Repeatable real-embedder measurement: debug, profile, or release.
# Requires Flutter, Linux and FFmpeg. Release runs without a VM service.
set -euo pipefail
PERF_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PERF_MODE="${1:-debug}"
case "$PERF_MODE" in debug|profile|release) ;; *) echo "Expected debug, profile, or release" >&2; exit 2 ;; esac
PERF_OUT="${FLUVIE_PERF_OUT:-$PERF_REPO/build/editor-implementation/performance/$PERF_MODE}"
mkdir -p "$PERF_OUT"
PERF_OUT="$(cd "$PERF_OUT" && pwd)"
if [ ! -s "$PERF_OUT/source-4k.mp4" ]; then
  ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc2=size=3840x2160:rate=24 \
    -t 6 -c:v libx264 -preset ultrafast -crf 28 -threads 2 -pix_fmt yuv420p \
    "$PERF_OUT/source-4k.mp4"
fi
cd "$PERF_REPO/apps/slides"
PERF_DEFINES=(
  "--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false"
  "--dart-define=FLUVIE_PERF_CLIP=$PERF_OUT/source-4k.mp4"
  "--dart-define=FLUVIE_PERF_REPORT=$PERF_OUT/report.json"
)
rm -f "$PERF_OUT/report.json"
case "$PERF_MODE" in
  debug)
    flutter test integration_test/editor_e2e_test.dart -d linux \
      --plain-name 'measure three-minute 4K editor workload and proxy scrubbing' \
      "${PERF_DEFINES[@]}"
    ;;
  profile)
    flutter drive --profile -d linux --driver=tool/editor_performance_driver.dart \
      --target=tool/editor_performance.dart "${PERF_DEFINES[@]}"
    ;;
  release)
    flutter build linux --release --target=tool/editor_performance.dart "${PERF_DEFINES[@]}"
    # Tests execute inside this AOT build and exit with their actual verdict.
    timeout 300s build/linux/x64/release/bundle/slides
    ;;
esac
test -s "$PERF_OUT/report.json"
dart "$PERF_REPO/tool/check_editor_performance.dart" "$PERF_MODE" "$PERF_OUT/report.json"
