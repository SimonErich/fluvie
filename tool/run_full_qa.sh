#!/usr/bin/env bash
#
# run_full_qa.sh - exhaustive QA: the standard gate plus every suite it skips,
# then the from-scratch release-acceptance script. Continues on failure and
# records every phase so one run surfaces ALL problems, not just the first.
#
# Heavy: hours. Points the frame-cache TMPDIR at disk-backed space (a big /tmp
# tmpfs fills and hangs Fluvie renders) and NEVER deletes flutter's own temp
# while tests run.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
export CI=true

QA_TMP="$HOME/.fluvie_qa_tmp"
REPORT="$REPO/tool/qa_report.txt"
mkdir -p "$QA_TMP"
: > "$REPORT"

pass=0; fail=0
FAILED_PHASES=""

log()  { printf '%s\n' "$*" | tee -a "$REPORT"; }
phase() {
  local name="$1"; shift
  log ""
  log "======================================================================"
  log "PHASE: $name   [$(date +%H:%M:%S)]   free: $(df -h "$HOME" | awk 'NR==2{print $4}')"
  log "======================================================================"
  # Run the phase in a subshell (isolates cwd drift and temp env). Frame
  # cache to disk-backed tmp.
  if ( cd "$REPO"; TMPDIR="$QA_TMP" FLUVIE_TMPDIR="$QA_TMP" "$@" ) >>"$REPORT" 2>&1; then
    log ">>> PASS: $name"
    pass=$((pass+1))
  else
    local code=$?
    log ">>> FAIL ($code): $name"
    fail=$((fail+1))
    FAILED_PHASES="$FAILED_PHASES\n  - $name"
  fi
  # Reclaim render/frame caches between heavy phases (safe: our own QA tmp).
  rm -rf "$QA_TMP"/fluvie_* 2>/dev/null || true
}

# --- PHASE 1: the standard gate (format, analyze, lint, unit tests, coverage>=97) ---
gate() { CI=true melos run gate; }
phase "standard gate" gate

# --- PHASE 2: goldens (Alchemist visual regression), incl. fluvie_editor explicitly ---
goldens_scoped() { CI=true melos run test:goldens --no-select; }
phase "goldens (scoped packages)" goldens_scoped
editor_goldens() { cd "$REPO/packages/fluvie_editor" && flutter test --tags golden; }
phase "goldens (fluvie_editor)" editor_goldens

# --- PHASE 3: ffmpeg-tagged integration (real encoding; ffmpeg on PATH) ---
ffmpeg_suite() { CI=true melos run test:ffmpeg --no-select; }
phase "ffmpeg integration (fluvie + fluvie_cli + slides audition)" ffmpeg_suite

# --- PHASE 4: wasm-tagged (browser harness; self-skips without a runtime) ---
wasm_suite() { cd "$REPO/packages/fluvie" && flutter test --tags wasm; }
phase "wasm harness" wasm_suite
browser_encoder() {
  bash "$REPO/apps/slides/tool/fetch_ffmpeg.sh" &&
    dart "$REPO/apps/slides/tool/verify_web_encoder.dart"
}
phase "real Chrome encoder, cancellation and clip pixels" browser_encoder
performance() { bash "$REPO/tool/verify_editor_performance.sh" profile; }
phase "4K editor performance (profile)" performance

# --- PHASE 5: render every registered composition to mp4 via the CLI (real ffmpeg) ---
render_examples() { CI=true melos run render:examples; }
phase "render:examples (15 compositions)" render_examples

# --- PHASE 6: docs (naked-fence lint, snippet drift, dartdoc 0 warnings) ---
docs_lint()   { melos run docs:lint; }
docs_snip()   { melos run docs:snippets:check; }
docs_dartdoc(){ melos run docs:dartdoc; }
phase "docs:lint" docs_lint
phase "docs:snippets:check" docs_snip
phase "docs:dartdoc" docs_dartdoc

# --- PHASE 7: web build (slides app compiles to web) ---
web_build() { cd "$REPO/apps/slides" && flutter build web --release; }
phase "slides web build" web_build
browser_matrix() {
  node --test "$REPO"/tool/test/browser*_test.mjs &&
    bash "$REPO/tool/verify_browser_matrix.sh"
}
phase "compiled editor and media in Chrome, Firefox and WebKit" browser_matrix

# --- PHASE 7b: end-to-end integration tests on the real Linux embedder ---
e2e_suite() { cd "$REPO/apps/slides" && flutter test integration_test -d linux; }
phase "e2e integration (slides, -d linux)" e2e_suite

# --- PHASE 8: the from-scratch release-acceptance superset (clone + all of the above + pana + determinism) ---
fresh_clone() { FLUVIE_VERIFY_WORKTREE=1 FLUVIE_VERIFY_TMP="$HOME" bash "$REPO/tool/verify_fresh_clone.sh"; }
phase "verify_fresh_clone (release acceptance)" fresh_clone

log ""
log "======================================================================"
log "FULL QA COMPLETE  [$(date +%H:%M:%S)]"
log "  phases passed: $pass"
log "  phases failed: $fail"
if [ "$fail" -gt 0 ]; then
  log "  FAILED:$FAILED_PHASES"
  log "QA-RESULT: FAIL"
else
  log "QA-RESULT: PASS"
fi
log "======================================================================"
exit "$fail"
