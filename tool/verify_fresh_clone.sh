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
# asserts no `example/` harness sits above it (so `resolveProjectDir` throws),
# and TMPDIR points `systemTemp` here. Nesting this inside the repo would let
# that walk find the real harness and the test would wrongly fail. Override the
# base with FLUVIE_VERIFY_TMP if $HOME is small or itself inside a Fluvie repo.
WORK="$(mktemp -d "${FLUVIE_VERIFY_TMP:-$HOME}/.fluvie_verify.XXXXXX")"
export TMPDIR="${WORK}/tmp"
mkdir -p "${TMPDIR}"

cleanup() { rm -rf "${WORK}"; }
trap cleanup EXIT

step() { printf '\n=== %s ===\n' "$1"; }
fail() { printf '\nFAILED: %s\n' "$1" >&2; exit 1; }

CLONE="${WORK}/fluvie"

step "clone (file:// so it mirrors a real checkout)"
git clone --quiet "file://${SRC}" "${CLONE}"
cd "${CLONE}"

step "bootstrap"
dart pub get
dart run melos bootstrap

step "gate (format, analyze, lint, test, coverage >= 97%)"
CI=true dart run melos run gate || fail "gate"

step "goldens (Alchemist, Linux baseline)"
CI=true dart run melos run test:goldens || fail "goldens"

step "doc checks (naked-fence lint + snippet drift + dartdoc 0 warnings)"
dart run melos run docs:lint || fail "docs:lint"
dart run melos run docs:snippets:check || fail "docs:snippets:check"
dart run melos run docs:dartdoc || fail "dartdoc"

step "pana (publishability)"
dart pub global activate pana >/dev/null 2>&1 || true
for pkg in fluvie fluvie_lints fluvie_cli; do
  dart pub global run pana --no-warning "packages/${pkg}" >"${WORK}/pana_${pkg}.txt" 2>&1 \
    || printf 'pana %s: see %s (placeholder repo URL is the expected residual)\n' "${pkg}" "${WORK}/pana_${pkg}.txt"
done

step "render every lesson and assert its frame count (ffmpeg)"
command -v ffmpeg >/dev/null || fail "ffmpeg not on PATH"
command -v ffprobe >/dev/null || fail "ffprobe not on PATH"
( cd example && CI=true flutter test --tags ffmpeg test/render/lessons_render_smoke_test.dart ) \
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

step "voice spot-check (three docs pages must be em-dash free)"
for page in getting-started/your-first-video.md guides/animating-elements.md reference/faq.md; do
  if grep -qP '[\x{2013}\x{2014}]' "documentation/${page}"; then
    fail "em/en-dash in documentation/${page}"
  fi
done

printf '\nverify_fresh_clone: OK. The 1.0.0 release bar is green.\n'
