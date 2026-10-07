#!/usr/bin/env bash
#
# verify_fresh_clone.sh - the 1.0.0 release acceptance check.
#
# Clones the current repository into a throwaway working tree and runs the whole
# quality bar against it, exactly as a fresh contributor would: bootstrap, the
# gate, goldens, coverage, the doc checks, dartdoc, pana, and a render of every
# lesson with an ffprobe frame-count assertion, then proves determinism by
# regenerating the demo gif and diffing it.
#
# Heavy and manual: it is NOT part of `melos run gate`. Run it before tagging a
# release. Any failing step exits non-zero.
#
# It works on a clone in a directory on the largest filesystem and points TMPDIR
# there too, because Fluvie's frame cache and the test sandboxes are large and a
# small /tmp (often a tmpfs) will fill and hang the run.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SRC

# A work area on a roomy filesystem, OUTSIDE any Fluvie checkout. It must be
# outside the repo: a Fluvie test creates a `Directory.systemTemp` dir and
# asserts no Fluvie capture harness sits above it (so `resolveProjectDir` throws),
# and TMPDIR points `systemTemp` here. Nesting this inside the repo would let
# that walk find the real harness and the test would wrongly fail. Override the
# base with FLUVIE_VERIFY_TMP if $HOME is small or itself inside a Fluvie repo.
WORK="$(mktemp -d "${FLUVIE_VERIFY_TMP:-$HOME}/.fluvie_verify.XXXXXX")"
export TMPDIR="${WORK}/tmp"
mkdir -p "${TMPDIR}"

HTTP_PID=""
cleanup() {
  if [ -n "${HTTP_PID}" ]; then
    kill "${HTTP_PID}" 2>/dev/null || true
    wait "${HTTP_PID}" 2>/dev/null || true
  fi
  rm -rf "${WORK}"
}
trap cleanup EXIT

step() { printf '\n=== %s ===\n' "$1"; }
fail() { printf '\nFAILED: %s\n' "$1" >&2; exit 1; }

CLONE="${WORK}/fluvie"

step "clone (file:// so it mirrors a real checkout)"
if [ "${FLUVIE_VERIFY_WORKTREE:-0}" = "1" ]; then
  # An alternate index snapshots the files being verified without staging or
  # committing anything in the contributor's index or moving their branch.
  GIT_INDEX_FILE="${WORK}/snapshot.index" git -C "$SRC" read-tree HEAD
  GIT_INDEX_FILE="${WORK}/snapshot.index" git -C "$SRC" add -A -- .
  SNAPSHOT_TREE="$(GIT_INDEX_FILE="${WORK}/snapshot.index" git -C "$SRC" write-tree)"
  SNAPSHOT_COMMIT="$(git -C "$SRC" commit-tree "$SNAPSHOT_TREE" -p HEAD -m 'Verification snapshot of current working tree')"
  # Shared local objects make the unreferenced verification commit available.
  git clone --quiet --shared "$SRC" "$CLONE"
  git -C "$CLONE" checkout --quiet --detach "$SNAPSHOT_COMMIT"
  printf 'Verifying working-tree snapshot %s (tree %s)\n' "$SNAPSHOT_COMMIT" "$SNAPSHOT_TREE"
else
  git clone --quiet "file://${SRC}" "${CLONE}"
fi
cd "${CLONE}"

step "bootstrap"
dart pub get
dart run melos bootstrap

step "gate (format, analyze, lint, test, coverage >= 97%)"
CI=true dart run melos run gate || fail "gate"

step "goldens (Alchemist, Linux baseline)"
CI=true dart run melos run test:goldens --no-select || fail "goldens"

step "doc checks (naked-fence lint + snippet drift + dartdoc 0 warnings)"
dart run melos run docs:lint || fail "docs:lint"
dart run melos run docs:snippets:check || fail "docs:snippets:check"
dart run melos run docs:dartdoc || fail "dartdoc"

step "pana (publishability)"
bash tool/verify_packages.sh \
  "${FLUTTER_ROOT:-$(cd "$(dirname "$(command -v flutter)")/.." && pwd)}" \
  "${WORK}/pana" || fail "package publishability"

step "real encoding and native audition (ffmpeg + ffplay)"
command -v ffmpeg >/dev/null || fail "ffmpeg not on PATH"
command -v ffprobe >/dev/null || fail "ffprobe not on PATH"
command -v ffplay >/dev/null || fail "ffplay not on PATH"
CI=true dart run melos run test:ffmpeg --no-select || fail "ffmpeg integration and audition"

step "render every lesson and assert its frame count (ffmpeg)"
( cd examples/gallery && CI=true flutter test --tags ffmpeg test/render/lessons_render_smoke_test.dart ) \
  || fail "lesson render-smoke"

step "gif export + determinism (two CLI renders must be byte-identical)"
# Size and fps come from the Video, so the render command takes neither flag.
# Render the same lesson to gif twice and byte-compare: frames are deterministic
# and the encode is bitexact, so the two gifs must be identical on one machine.
for n in a b; do
  dart run packages/fluvie_cli/bin/fluvie.dart render 01_hello_video \
    --format gif --out "${WORK}/demo_${n}.gif" || fail "gif export (${n})"
  [ -s "${WORK}/demo_${n}.gif" ] || fail "gif export produced no file (${n})"
done
cmp -s "${WORK}/demo_a.gif" "${WORK}/demo_b.gif" \
  || fail "two gif renders are not byte-identical (determinism regression)"

step "editor smoke (Edit mode boots headless in the slides app)"
( cd apps/slides && CI=true flutter test test/editor_mode_test.dart ) \
  || fail "editor smoke"

step "browser acceptance helper regression tests"
node --test tool/test/browser*_test.mjs || fail "browser acceptance helper tests"

step "slides app web build + headless boot smoke (main and speaker routes)"
( cd apps/slides && flutter build web --release ) || fail "slides web build"
CHROME="$(command -v google-chrome || command -v chromium || command -v chromium-browser || true)"
if [ -n "${CHROME}" ]; then
  # Bind first, then publish the OS-assigned port. This process owns the socket;
  # an unrelated server can never satisfy the smoke check on a stale fixed port.
  python3 - "${CLONE}/apps/slides/build/web" "${WORK}/http.url" >"${WORK}/http.log" 2>&1 <<'PY' &
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys

with ThreadingHTTPServer(('127.0.0.1', 0), partial(SimpleHTTPRequestHandler, directory=sys.argv[1])) as server:
    ready = Path(sys.argv[2])
    pending = ready.with_suffix('.pending')
    pending.write_text(f'http://127.0.0.1:{server.server_port}/')
    pending.replace(ready)
    server.serve_forever()
PY
  HTTP_PID=$!
  for attempt in {1..100}; do
    kill -0 "${HTTP_PID}" 2>/dev/null \
      || { cat "${WORK}/http.log" >&2; fail "slides smoke HTTP server failed to start"; }
    [ -s "${WORK}/http.url" ] && break
    sleep 0.1
  done
  [ -s "${WORK}/http.url" ] || fail "slides smoke HTTP server did not become ready"
  WEB_SMOKE_URL="$(cat "${WORK}/http.url")"
  for route in "" "#/speaker"; do
    "${CHROME}" --headless=new --disable-gpu --no-sandbox --virtual-time-budget=20000 \
      --user-data-dir="${WORK}/chrome-profile" \
      --dump-dom "${WEB_SMOKE_URL}${route}" >"${WORK}/dom.html" 2>"${WORK}/chrome.log" \
      || { cat "${WORK}/chrome.log" >&2; fail "Chrome failed at /${route}"; }
    grep -q "flutter-view\|flt-" "${WORK}/dom.html" \
      || fail "slides app did not boot at /${route}"
  done
  kill "${HTTP_PID}" 2>/dev/null || true
  wait "${HTTP_PID}" 2>/dev/null || true
  HTTP_PID=""
else
  printf 'no Chrome found; skipping the headless boot smoke (build still verified)\n'
fi

step "voice spot-check (three docs pages must be em-dash free)"
for page in getting-started/your-first-video.md guides/animating-elements.md reference/faq.md; do
  if grep -qP '[\x{2013}\x{2014}]' "documentation/${page}"; then
    fail "em/en-dash in documentation/${page}"
  fi
done

printf '\nverify_fresh_clone: OK. The 1.0.0 release bar is green.\n'
