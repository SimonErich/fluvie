#!/usr/bin/env bash
# Dartdoc zero-warning gate: run `dart doc` on the documented packages with
# link validation and fail on any warning or error. Used by CI and the
# fresh-clone script, not the fast pre-commit gate (dartdoc is slow).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKAGES=(packages/fluvie packages/fluvie_presenter)
OUT_DIR="$(mktemp -d)"
LOG="$(mktemp)"

trap 'rm -rf "$OUT_DIR" "$LOG"' EXIT

# `dart doc` exits non-zero on errors but not always on warnings, so parse the
# summary line ("Found N warnings and M errors.") and gate on it.
for pkg in "${PACKAGES[@]}"; do
  if ! (cd "$REPO_ROOT/$pkg" && dart doc --validate-links --output "$OUT_DIR/${pkg##*/}") >"$LOG" 2>&1; then
    cat "$LOG"
    echo "✗ docs:dartdoc — dart doc failed in $pkg."
    exit 1
  fi

  summary="$(grep -E 'Found [0-9]+ warnings? and [0-9]+ errors?\.' "$LOG" || true)"
  counts="$(printf '%s\n' "$summary" | grep -oE '[0-9]+' || true)"
  warnings="$(printf '%s\n' "$counts" | sed -n '1p')"
  errors="$(printf '%s\n' "$counts" | sed -n '2p')"

  if [ "${warnings:-0}" != "0" ] || [ "${errors:-0}" != "0" ]; then
    cat "$LOG"
    echo "✗ docs:dartdoc — $pkg: ${warnings:-?} warning(s), ${errors:-?} error(s). Fix the dartdoc references."
    exit 1
  fi

  echo "✓ docs:dartdoc — $pkg passed (0 warnings, 0 errors)."
done
